-- VentaPE: almacenamiento externo de fotografías del catálogo
-- Ejecutar una sola vez en Supabase > SQL Editor del proyecto VentaPE.
-- No elimina productos ni fotografías existentes.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'catalogo',
  'catalogo',
  true,
  8388608,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 8388608,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- Lectura pública: necesaria para mostrar el catálogo sin iniciar sesión.
drop policy if exists "Catalogo: lectura publica" on storage.objects;
create policy "Catalogo: lectura publica"
on storage.objects for select
to public
using (bucket_id = 'catalogo');

-- Solo administradores autenticados pueden cargar, reemplazar o borrar imágenes.
drop policy if exists "Catalogo: carga admin" on storage.objects;
create policy "Catalogo: carga admin"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'catalogo'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

drop policy if exists "Catalogo: actualizacion admin" on storage.objects;
create policy "Catalogo: actualizacion admin"
on storage.objects for update
to authenticated
using (
  bucket_id = 'catalogo'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
)
with check (
  bucket_id = 'catalogo'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

drop policy if exists "Catalogo: borrado admin" on storage.objects;
create policy "Catalogo: borrado admin"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'catalogo'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

-- Verificar que el bucket quedó público.
select id, name, public, file_size_limit
from storage.buckets
where id = 'catalogo';


-- Catálogo público: devolver URL de fotos (no cadenas Base64) y evitar
-- duplicar la foto de portada en los campos imgs e img.
create or replace function public.get_public_catalog()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'cfg',
    coalesce((
      select jsonb_build_object(
        'name', data->'name',
        'slogan', data->'slogan',
        'logo', data->'logo',
        'wa', data->'wa',
        'prices', case
          when lower(coalesce(data->>'pubPrice','true')) in ('false','0','no') then false
          else true
        end
      )
      from public.app_records
      where collection = 'config' and id = 'main'
      limit 1
    ), jsonb_build_object('prices', true)),
    'products',
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id,
        'code', data->'code',
        'desc', data->'desc',
        'brand', data->'brand',
        'cat', data->'cat',
        'kind', data->'kind',
        'unit', data->'unit',
        'cur', data->'cur',
        'price', data->'price',
        'specs', data->'specs',
        'imgs', coalesce(data->'imgs', case
          when data->'img' is not null then jsonb_build_array(data->'img')
          else '[]'::jsonb end),
        'avail', case
          when data->>'kind' = 'servicio' then true
          when coalesce(data->>'stock','') ~ '^-?[0-9]+([.][0-9]+)?$'
            then (data->>'stock')::numeric > 0
          else false
        end
      ))
      from public.app_records
      where collection = 'products'
    ), '[]'::jsonb)
  );
$$;

grant execute on function public.get_public_catalog() to anon, authenticated;
