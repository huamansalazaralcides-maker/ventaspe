-- VentaPE: reparación del catálogo público y bandera de precios
-- Ejecutar en Supabase > SQL Editor del proyecto VentasPE.
-- No modifica productos ni precios; solo actualiza la función pública.

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
        'imgs', data->'imgs',
        'img', data->'img',
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

-- Verificación: debe devolver prices=false cuando pubPrice sea false.
select id, data->>'pubPrice' as mostrar_precios
from public.app_records
where collection='config' and id='main';
