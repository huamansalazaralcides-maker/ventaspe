-- Ejecutar únicamente después de crear el primer usuario en Supabase Auth.
-- Primero identificar y confirmar la cuenta correcta:
select id, username, name, role, created_at
from public.profiles
order by created_at;

-- Reemplazar el valor por el username exacto ya verificado.
-- No ejecutar si no se ha confirmado la identidad de la cuenta.
-- update public.profiles set role = 'admin' where username = 'USUARIO_CONFIRMADO';
