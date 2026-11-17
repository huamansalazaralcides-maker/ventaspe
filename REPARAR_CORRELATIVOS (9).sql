-- Ejecutar solo si ya existe public.doc_counters y public.app_records.
-- Corrige el cálculo de correlativos para que use únicamente los dígitos
-- posteriores al último guion (evita contar el prefijo F001/B001).
create or replace function public.reserve_doc_number(p_type text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  n bigint;
  prefix text;
  width integer;
begin
  if auth.uid() is null then raise exception 'Sesión requerida'; end if;
  if p_type not in ('cotizacion','factura','boleta') then raise exception 'Tipo inválido'; end if;
  update public.doc_counters
     set last_value = greatest(
       last_value,
       coalesce((
         select max((regexp_match(coalesce(data->>'num',''), '-([0-9]+)$'))[1]::bigint)
           from public.app_records
          where collection='docs'
            and data->>'type'=p_type
            and coalesce(data->>'num','') ~ '-[0-9]+$'
       ),0)
     ) + 1
   where doc_type=p_type
   returning last_value into n;
  if p_type='cotizacion' then prefix:='COT-'; width:=6;
  elsif p_type='factura' then prefix:='F001-'; width:=8;
  else prefix:='B001-'; width:=8; end if;
  return prefix||lpad(n::text,width,'0');
end;
$$;
grant execute on function public.reserve_doc_number(text) to authenticated;
