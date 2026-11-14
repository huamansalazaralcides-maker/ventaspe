// Gestión segura de cuentas. La service-role key vive SOLO como secreto de Edge Function.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const json = (body: unknown, status=200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type':'application/json' } });
  try {
    const url = Deno.env.get('SUPABASE_URL')!, anon = Deno.env.get('SUPABASE_ANON_KEY')!, service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const auth = req.headers.get('Authorization') || '';
    const caller = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error: ue } = await caller.auth.getUser();
    if (ue || !user) return json({error:'No autenticado'},401);
    const admin = createClient(url, service);
    const { data: profile } = await admin.from('profiles').select('role').eq('id',user.id).single();
    if (profile?.role !== 'admin') return json({error:'Solo administrador'},403);
    const b = await req.json();
    if (b.action === 'create') {
      const username=String(b.user||'').trim().toLowerCase(), name=String(b.name||'').trim(), pass=String(b.pass||'');
      if (!/^[a-z0-9._-]{3,32}$/.test(username) || !name || pass.length<8) return json({error:'Usuario inválido, nombre obligatorio y contraseña mínima de 8 caracteres'},400);
      const email=`${username}@users.ventape.local`;
      const {data,error}=await admin.auth.admin.createUser({email,password:pass,email_confirm:true,user_metadata:{name,username}});
      if(error) return json({error:error.message},400);
      const {error:pe}=await admin.from('profiles').upsert({id:data.user.id,name,username,phone:String(b.phone||'').trim(),role:b.role==='admin'?'admin':'vendedor'});
      if(pe){await admin.auth.admin.deleteUser(data.user.id);return json({error:pe.message},400)}
      return json({ok:true});
    }
    const id=String(b.userId||'');
    if (!id) return json({error:'Falta usuario'},400);
    if (b.action==='delete') {
      if(id===user.id) return json({error:'No puede eliminar su propia cuenta'},400);
      const {data:target}=await admin.from('profiles').select('role').eq('id',id).single();
      if(!target) return json({error:'Usuario no encontrado'},404);
      if(target.role==='admin'){const {count}=await admin.from('profiles').select('*',{count:'exact',head:true}).eq('role','admin');if((count||0)<=1)return json({error:'Debe quedar al menos un administrador'},400)}
      const {count:docsCount,error:docsErr}=await admin.from('app_records').select('id',{count:'exact',head:true}).eq('collection','docs').eq('owner_id',id);
      if(docsErr) return json({error:'No se pudo verificar el historial del usuario: '+docsErr.message},500);
      if((docsCount||0)>0) return json({error:'No se puede eliminar este usuario porque tiene documentos asociados. Cámbiele la contraseña o consérvelo como inactivo para proteger el historial de ventas.'},400);
      const {error}=await admin.auth.admin.deleteUser(id);if(error)return json({error:error.message},400);return json({ok:true});
    }
    if(b.action==='password') { const pass=String(b.pass||'');if(pass.length<8)return json({error:'La contraseña debe tener al menos 8 caracteres'},400);const {error}=await admin.auth.admin.updateUserById(id,{password:pass});if(error)return json({error:error.message},400);return json({ok:true}); }
    if(b.action==='update') { if(id===user.id && b.role) return json({error:'No puede cambiar su propio rol'},400);const patch:any={};if(b.role)patch.role=b.role==='admin'?'admin':'vendedor';if(b.name)patch.name=String(b.name);if(b.phone!==undefined)patch.phone=String(b.phone||'').trim();if(patch.role==='vendedor'){const {data:target}=await admin.from('profiles').select('role').eq('id',id).single();if(target?.role==='admin'){const {count}=await admin.from('profiles').select('*',{count:'exact',head:true}).eq('role','admin');if((count||0)<=1)return json({error:'Debe quedar al menos un administrador'},400)}}const {error}=await admin.from('profiles').update(patch).eq('id',id);if(error)return json({error:error.message},400);return json({ok:true}); }
    return json({error:'Acción no válida'},400);
  } catch(e) { return json({error:String(e?.message||e)},500); }
});
