/* Configuración pública de Supabase. La clave publishable/anon es apta para frontend;
   la seguridad depende de las políticas RLS. Nunca colocar aquí service_role. */
window.VPE_CONFIG = {
  url: 'https://ylaxubowqyaabsvcwyhe.supabase.co',
  anonKey: 'sb_publishable_Wi_mJfTi25qruJRzoexjLQ_gUqn1cOw',
  emailForUser: (username) => `${username}@users.ventape.local`
};
if (!window.supabase) throw new Error('No se pudo cargar Supabase JS. Verifique su conexión a Internet.');
window.vpeSupabase = window.supabase.createClient(window.VPE_CONFIG.url, window.VPE_CONFIG.anonKey, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
});
