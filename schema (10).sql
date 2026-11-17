-- VentaPE en Línea / Supabase
-- Ejecutar completo en Supabase > SQL Editor.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  username text not null unique,
  role text not null default 'vendedor' check (role in ('admin','vendedor')),
  created_at timestamptz not null default now()
);

create table if not exists public.app_records (
  collection text not null check (collection in ('products','clients','docs','config')),
  id text not null,
  owner_id uuid references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (collection,id)
);
create index if not exists app_records_owner_idx on public.app_records(owner_id);
create index if not exists app_records_collection_idx on public.app_records(collection);

create or replace function public.current_role()
returns text language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=(select auth.uid()) $$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.current_role()='admin',false) $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.profiles(id,name,username,role)
  values(new.id,coalesce(new.raw_user_meta_data->>'name',''),
         coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1)),'vendedor');
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Reserva atómica de numeración para que dos vendedores no repitan correlativos.
create table if not exists public.doc_counters (
  doc_type text primary key check(doc_type in ('cotizacion','factura','boleta')),
  last_value bigint not null default 0
);
insert into public.doc_counters(doc_type,last_value) values
 ('cotizacion',0),('factura',0),('boleta',0) on conflict(doc_type) do nothing;
create or replace function public.reserve_doc_number(p_type text)
returns text language plpgsql security definer set search_path=public
as $$
declare n bigint; prefix text; width integer;
begin
 if auth.uid() is null then raise exception 'Sesión requerida'; end if;
 if p_type not in ('cotizacion','factura','boleta') then raise exception 'Tipo inválido'; end if;
 update public.doc_counters set last_value=greatest(last_value, coalesce((select max((regexp_match(coalesce(data->>'num',''), '-([0-9]+)$'))[1]::bigint) from public.app_records where collection='docs' and data->>'type'=p_type and coalesce(data->>'num','') ~ '-[0-9]+$'),0))+1 where doc_type=p_type returning last_value into n;
 if p_type='cotizacion' then prefix:='COT-'; width:=6;
 elsif p_type='factura' then prefix:='F001-'; width:=8;
 else prefix:='B001-'; width:=8; end if;
 return prefix||lpad(n::text,width,'0');
end $$;
grant execute on function public.reserve_doc_number(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.app_records enable row level security;
alter table public.doc_counters enable row level security;

-- Profiles: un usuario ve su perfil; administradores ven todos.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
using (id=(select auth.uid()) or public.is_admin());
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles for update to authenticated
using(public.is_admin()) with check(public.is_admin());

-- App records. Vendedores pueden leer catálogo y cartera; solo sus documentos.
drop policy if exists records_read on public.app_records;
create policy records_read on public.app_records for select to authenticated using (
 collection in ('products','clients')
 or (collection='docs' and (owner_id=(select auth.uid()) or public.is_admin()))
 or collection='config'
);
drop policy if exists records_insert on public.app_records;
create policy records_insert on public.app_records for insert to authenticated with check (
 (collection='products' and public.is_admin())
 or collection='clients'
 or (collection='docs' and owner_id=(select auth.uid()) and coalesce(data->>'by','')=(select auth.uid())::text)
 or (collection='config' and public.is_admin())
);
drop policy if exists records_update on public.app_records;
create policy records_update on public.app_records for update to authenticated
using (
 (collection='products')
 or collection='clients'
 or (collection='docs' and (owner_id=(select auth.uid()) or public.is_admin()))
 or (collection='config' and public.is_admin())
)
with check (
 (collection='products')
 or collection='clients'
 or (collection='docs' and (owner_id=(select auth.uid()) or public.is_admin()))
 or (collection='config' and public.is_admin())
);
drop policy if exists records_delete on public.app_records;
create policy records_delete on public.app_records for delete to authenticated
using (public.is_admin());

-- Contadores: acceso únicamente a la función SECURITY INVOKER autenticada.
revoke all on public.doc_counters from anon, authenticated;

-- Los vendedores pueden descontar stock, pero no alterar precios ni fichas.
create or replace function public.guard_product_update()
returns trigger language plpgsql security invoker set search_path=public
as $$ begin
 if old.collection='products' and not public.is_admin() and
    (old.data - 'stock') is distinct from (new.data - 'stock') then
   raise exception 'El vendedor solo puede modificar el stock';
 end if;
 return new;
end $$;
drop trigger if exists trg_guard_product_update on public.app_records;
create trigger trg_guard_product_update before update on public.app_records
for each row execute function public.guard_product_update();

-- Catálogo público: entrega solo los campos comerciales necesarios; nunca expone
-- costos internos, documentos, clientes ni el stock exacto.
create or replace function public.get_public_catalog()
returns jsonb language sql stable security definer set search_path=public
as $$
 select jsonb_build_object(
  'cfg', coalesce((select jsonb_build_object(
    'name',data->'name','slogan',data->'slogan','logo',data->'logo',
    'wa',data->'wa','prices',coalesce(data->'pubPrice','true'::jsonb)
  ) from public.app_records where collection='config' and id='main'),'{}'::jsonb),
  'products', coalesce((select jsonb_agg(jsonb_build_object(
    'id',id,'code',data->'code','desc',data->'desc','brand',data->'brand',
    'cat',data->'cat','kind',data->'kind','unit',data->'unit','cur',data->'cur',
    'price',data->'price','specs',data->'specs','imgs',data->'imgs','img',data->'img',
    'avail',case when data->>'kind'='servicio' then true else case when coalesce(data->>'stock','') ~ '^-?[0-9]+([.][0-9]+)?$' then (data->>'stock')::numeric>0 else false end end
  )) from public.app_records where collection='products'),'[]'::jsonb)
 );
$$;
grant execute on function public.get_public_catalog() to anon, authenticated;

-- Realtime
alter table public.app_records replica identity full;
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='app_records') then
  alter publication supabase_realtime add table public.app_records;
 end if;
end $$;
