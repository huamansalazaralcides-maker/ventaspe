
/* Configuración pública de Supabase */
window.VPE_CONFIG = {
  url: 'https://ylaxubowqyaabsycwyhe.supabase.co',
  anonKey: 'sb_publishable_Wi_mJfTi25qruJRzoexjLQ_gUqn1cOw',
  emailForUser: (username) => username === 'admin'
    ? 'huamansalazaralcides@gmail.com'
    : `${username}@users.ventape.local`
};

if (!window.supabase) {
  throw new Error('No se pudo cargar Supabase JS. Verifique su conexión a Internet.');
}

window.vpeSupabase = window.supabase.createClient(
  window.VPE_CONFIG.url,
  window.VPE_CONFIG.anonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);
