VENTAPE — PAQUETE GITHUB PAGES + SUPABASE
========================================

ESTADO DE LA ENTREGA
--------------------
Paquete preparado para publicar el frontend estático en GitHub Pages y usar
Supabase como backend. Incluye el código de la aplicación, catálogo público,
configuración pública de Supabase, migración de seguridad/correlativos y Edge
Function para administrar usuarios.

IMPORTANTE: el código se validó localmente, pero esta sesión no tiene acceso
administrativo al proyecto Supabase para desplegar la Edge Function ni ejecutar
pruebas remotas. Por eso no se debe considerar validado para producción hasta
completar los pasos de configuración y las pruebas descritas al final.

ARCHIVOS PRINCIPALES
--------------------
- index.html: aplicación de ventas.
- catalogo.html: catálogo público para clientes.
- art.js: recursos gráficos locales.
- supabase-config.js: URL y clave PUBLICABLE del proyecto Supabase.
- supabase/MIGRACION_SEGURIDAD_Y_CORRELATIVOS.sql: actualiza las reglas de stock,
  permisos de actualización y reserva atómica de correlativos.
- supabase/functions/admin-users/index.ts: administración segura de usuarios.
- GUIA_APLICAR_MIGRACION.txt: instrucciones paso a paso.
- PRUEBAS_PENDIENTES.md: lista de validación previa a producción.

PUBLICAR EN GITHUB PAGES
------------------------
1. Cree un repositorio nuevo en GitHub.
2. Descomprima el ZIP.
3. Abra la carpeta VentaPE_GitHub_Supabase_BETA.
4. Suba TODO su contenido a la raíz del repositorio (no suba la carpeta externa
   como una subcarpeta adicional).
5. En GitHub: Settings > Pages.
6. En Build and deployment seleccione Deploy from a branch.
7. Seleccione la rama main y la carpeta /(root), y guarde.
8. Espere a que GitHub Pages publique el sitio.

CONFIGURAR SUPABASE
-------------------
El proyecto de Supabase configurado en este paquete es el proyecto existente
ylaxubowqyaabsvcwyhe. No cree otro proyecto ni ejecute supabase/schema.sql sobre
la base que ya contiene datos.

1. Antes de modificar la base, cree un backup.
2. Verifique que existan public.app_records, public.doc_counters,
   public.profiles, public.is_admin() y public.current_role().
3. Abra SQL Editor y ejecute el archivo
   supabase/MIGRACION_SEGURIDAD_Y_CORRELATIVOS.sql completo.
4. Ejecute por separado las consultas de verificación indicadas al final del SQL.
5. Despliegue la Edge Function admin-users siguiendo la guía.
6. Confirme que exista al menos un usuario administrador antes de operar.

DESPLEGAR EDGE FUNCTION admin-users
-----------------------------------
Requiere Supabase CLI instalado en la PC.

1. Abra una terminal en la carpeta raíz del proyecto.
2. Inicie sesión: supabase login
3. Vincule el proyecto: supabase link --project-ref ylaxubowqyaabsvcwyhe
4. Configure la clave privada como secreto (obtenga la clave service_role/secret
   desde Supabase > Project Settings > API; no la escriba en archivos):
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=PEGAR_SECRETO_AQUI
5. Despliegue: supabase functions deploy admin-users
6. Verifique en Supabase > Edge Functions que admin-users figure desplegada.

PRIMER ADMINISTRADOR
-------------------
1. Cree el primer usuario desde Supabase > Authentication > Users.
2. Confirme su identidad y que corresponde al administrador de VentaPE.
3. En SQL Editor consulte:
   select id, username, name, role from public.profiles order by created_at;
4. Solo después de confirmar el username correcto, ejecute sustituyendo el
   texto de ejemplo:
   update public.profiles set role='admin' where username='USUARIO_CONFIRMADO';
5. Inicie sesión en VentaPE y cree los demás usuarios desde Configuración.

SEGURIDAD
---------
- La clave del frontend es publicable; nunca coloque service_role en el frontend.
- La service_role se configura exclusivamente como secreto de Edge Function.
- Las contraseñas nuevas deben tener al menos 8 caracteres.
- La función admin-users valida que quien la invoque sea administrador.
- El vendedor no puede modificar precios/ficha de productos ni aumentar stock.
- Los correlativos se reservan en Supabase; si falla la RPC, la aplicación no
  emite el documento con un número local alternativo.
- El usuario con documentos asociados no se puede eliminar para preservar el
  historial comercial.

LIMITACIONES QUE DEBEN CONSIDERARSE
----------------------------------
- La consulta automática de DNI/RUC no está habilitada en GitHub Pages; complete
  los datos del cliente manualmente.
- Los PDF son documentos comerciales internos, no comprobantes electrónicos
  autorizados por SUNAT. Para ello se requiere integración PSE/OSE.
- La emisión de documentos y el descuento de stock todavía se guardan como
  operaciones separadas. No ejecutar ventas concurrentes de alto volumen hasta
  implementar y probar una operación transaccional de venta/stock.
- Las pruebas de inicio de sesión, RLS, persistencia, Realtime, correlativos,
  administración de usuarios y catálogo público deben completarse en el
  proyecto real antes de usarlo en producción.
