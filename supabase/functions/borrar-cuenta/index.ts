// Ventas Link · borrar-cuenta — la vendedora elimina SU cuenta y todos sus datos (derecho de eliminación, LOPDP).
// Solo actúa sobre la cuenta de quien llama (se identifica con su sesión, nunca con datos del navegador).
// Orden: 1) quién es  2) fotos del almacén  3) cuenta → en cascada: tienda, productos, secciones, pedidos,
//        visitas, plan, consentimientos. El enlace /t/... queda retirado para que nadie más lo use.
// La cuenta de la dueña del panel NO se borra desde aquí (evita quedarse sin panel por un toque).
import { createClient } from 'npm:@supabase/supabase-js@2.119.0';

const ORIGENES = ['https://grand-halva-1b3001.netlify.app', 'http://localhost:3000'];

Deno.serve(async (req: Request) => {
  const origen = req.headers.get('origin') ?? '';
  const permitido = ORIGENES.includes(origen) ? origen : ORIGENES[0];
  const cors = {
    'Access-Control-Allow-Origin': permitido,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
  const responder = (estado: number, cuerpo: Record<string, unknown>) =>
    new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return responder(405, { error: 'metodo_no_permitido' });

  const url = Deno.env.get('SUPABASE_URL');
  const secreta = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !secreta) return responder(500, { error: 'configuracion' });

  // Confirmación escrita (la pantalla pide escribir ELIMINAR): evita borrados por un toque accidental.
  let cuerpo: { confirmo?: string };
  try { cuerpo = await req.json(); } catch { return responder(400, { error: 'pedido_invalido' }); }
  if (String(cuerpo?.confirmo ?? '').trim().toUpperCase() !== 'ELIMINAR') return responder(400, { error: 'sin_confirmacion' });

  const admin = createClient(url, secreta, { auth: { persistSession: false, autoRefreshToken: false } });

  // 1) ¿Quién llama? (la sesión se valida en el servidor de cuentas)
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return responder(401, { error: 'NO_AUTENTICADO' });
  const { data: quien, error: errQuien } = await admin.auth.getUser(token);
  const uid = quien?.user?.id;
  if (errQuien || !uid) return responder(401, { error: 'NO_AUTENTICADO' });

  const { data: info, error: errInfo } = await admin.rpc('cuenta_para_borrar', { p_uid: uid });
  if (errInfo || !info) return responder(500, { error: 'no_se_pudo_leer' });
  if (info.es_duena === true) return responder(409, { error: 'ES_DUENA' });

  // 2) Fotos (de a 100). Si alguna falla, se corta: mejor reintentar que dejar fotos huérfanas.
  const archivos: string[] = Array.isArray(info.archivos) ? info.archivos.filter((n: unknown) => typeof n === 'string') : [];
  for (let i = 0; i < archivos.length; i += 100) {
    const { error } = await admin.storage.from('media').remove(archivos.slice(i, i + 100));
    if (error) return responder(500, { error: 'no_se_pudieron_borrar_fotos' });
  }

  // 3) La cuenta (todo lo demás cae en cascada en la base)
  const { error: errBorrar } = await admin.auth.admin.deleteUser(uid);
  if (errBorrar) return responder(500, { error: 'no_se_pudo_borrar' });

  return responder(200, { ok: true, fotos: archivos.length });
});
