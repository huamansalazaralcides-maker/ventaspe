-- VentaPE | Migración controlada para el esquema existente
-- Proyecto: ylaxubowqyaabsvcwyhe
-- Ejecutar SOLO después de crear un backup y confirmar las tablas/funciones.
-- No crea, elimina ni recrea tablas de negocio.

begin;

-- Asegurar los tres contadores sin reiniciar valores existentes.
insert into public.doc_counters (doc_type, last_value)
values ('cotizacion', 0), ('factura', 0), ('boleta', 0)
on conflict (doc_type) do nothing;

-- Los contadores solo se modifican mediante reserve_doc_number().
alter table public.doc_counters enable row level security;
revoke all on table public.doc_counters from anon, authenticated;

-- El vendedor no puede cambiar identidad/propietario ni ficha del producto.
-- Solo puede reducir stock; nunca dejarlo negativo ni aumentarlo.
create or replace function public.guard_product_update()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  old_stock numeric;
  new_stock numeric;
begin
  if not public.is_admin() then
    if old.collection is distinct from new.collection
       or old.id is distinct from new.id
       or old.owner_id is distinct from new.owner_id then
      raise exception 'No está permitido cambiar la identidad o propietario del registro';
    end if;

    if old.collection = 'products' then
      if (old.data - 'stock') is distinct from (new.data - 'stock') then
        raise exception 'El vendedor solo puede modificar el stock del producto';
      end if;

      begin
        old_stock := coalesce(nullif(old.data->>'stock','')::numeric, 0);
        new_stock := coalesce(nullif(new.data->>'stock','')::numeric, 0);
      exception when invalid_text_representation then
        raise exception 'El stock debe ser un número válido';
      end;

      if new_stock < 0 then
        raise exception 'El stock no puede ser negativo';
      end if;
      if new_stock > old_stock then
        raise exception 'El vendedor no puede aumentar el stock';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_product_update on public.app_records;
create trigger trg_guard_product_update
before update on public.app_records
for each row execute function public.guard_product_update();

-- Permisos de actualización por colección.
drop policy if exists records_update on public.app_records;
create policy records_update
on public.app_records
for update to authenticated
using (
  (collection = 'products')
  or (collection = 'clients')
  or (collection = 'docs' and (owner_id = (select auth.uid()) or public.is_admin()))
  or (collection = 'config' and public.is_admin())
)
with check (
  (collection = 'products')
  or (collection = 'clients')
  or (collection = 'docs' and (owner_id = (select auth.uid()) or public.is_admin()))
  or (collection = 'config' and public.is_admin())
);

-- Reserva atómica de correlativos: el UPDATE bloquea la fila del tipo.
create or replace function public.reserve_doc_number(p_type text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  n bigint;
  prefix text;
  width integer;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida';
  end if;
  if p_type not in ('cotizacion', 'factura', 'boleta') then
    raise exception 'Tipo de documento inválido';
  end if;

  update public.doc_counters c
     set last_value = greatest(
       c.last_value,
       coalesce((
         select max((regexp_match(coalesce(r.data->>'num', ''), '-([0-9]+)$'))[1]::bigint)
           from public.app_records r
          where r.collection = 'docs'
            and r.data->>'type' = p_type
            and coalesce(r.data->>'num', '') ~ '-[0-9]+$'
       ), 0)
     ) + 1
   where c.doc_type = p_type
   returning c.last_value into n;

  if n is null then
    raise exception 'No existe el contador para el tipo %', p_type;
  end if;

  if p_type = 'cotizacion' then
    prefix := 'COT-'; width := 6;
  elsif p_type = 'factura' then
    prefix := 'F001-'; width := 8;
  else
    prefix := 'B001-'; width := 8;
  end if;
  return prefix || lpad(n::text, width, '0');
end;
$$;

revoke all on function public.reserve_doc_number(text) from public, anon;
grant execute on function public.reserve_doc_number(text) to authenticated;

commit;

-- VERIFICACIÓN POSTERIOR (ejecutar en una consulta aparte):
-- select doc_type, last_value from public.doc_counters order by doc_type;
-- select policyname, cmd from pg_policies
--  where schemaname='public' and tablename='app_records' order by policyname;
-- select tgname, tgenabled from pg_trigger
--  where tgrelid='public.app_records'::regclass and not tgisinternal;
-- select proname, prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace
--  where n.nspname='public' and proname in ('reserve_doc_number','is_admin','current_role');
