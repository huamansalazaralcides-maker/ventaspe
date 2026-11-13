# VentaPE — validación antes de producción

## Validaciones locales realizadas en esta entrega
- [x] Se revisó la estructura del frontend y la configuración de Supabase.
- [x] Se verificó sintaxis JavaScript del script principal con Node.js `--check`.
- [x] La emisión detiene el proceso si falla la reserva de correlativo en Supabase.
- [x] La administración de usuarios exige sesión autenticada y rol admin en Edge Function.
- [x] La Edge Function protege al último administrador y evita borrar usuarios con documentos.
- [x] Se quitó la configuración engañosa de API DNI/RUC no migrada a GitHub Pages.
- [x] Se preparó una migración para impedir que vendedores alteren ficha/precio o aumenten stock.

## Requiere ejecutarse en el proyecto Supabase real
- [ ] Crear backup y ejecutar `MIGRACION_SEGURIDAD_Y_CORRELATIVOS.sql`.
- [ ] Revisar resultados de las consultas de verificación.
- [ ] Desplegar `admin-users` y configurar `SUPABASE_SERVICE_ROLE_KEY` como secreto.
- [ ] Confirmar/promover el primer administrador.
- [ ] Probar Auth, RLS, permisos y persistencia con dos cuentas.
- [ ] Probar correlativos concurrentes desde dos sesiones.
- [ ] Probar descuento de stock y catálogo público.
- [ ] Probar PDF, Excel, imágenes, WhatsApp y acceso desde distintos equipos.

## Limitaciones técnicas conocidas
- La emisión del documento y la actualización de stock aún no forman una única transacción de base de datos.
- Consulta automática DNI/RUC no habilitada en GitHub Pages.
- Los PDF no son comprobantes electrónicos autorizados por SUNAT; requieren PSE/OSE.

**No declarar producción hasta completar todas las pruebas remotas.**
