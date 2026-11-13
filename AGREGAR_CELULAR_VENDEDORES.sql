-- Agrega un celular de contacto por usuario/vendedor. No modifica ventas ni documentos.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
