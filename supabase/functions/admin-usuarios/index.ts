// Ventas Link · admin-usuarios — SOLO para la dueña (se comprueba aquí, en el servidor).
// Acciones:
//   { accion: 'crear',  correo, nombre } → crea la cuenta (ya confirmada) y devuelve un enlace de entrada de un solo uso.
//   { accion: 'enlace', correo }         → devuelve un enlace de entrada nuevo para una cuenta que ya existe.
// El enlace NO se envía por correo (el correo incluido de Supabase solo llega al equipo del proyecto):
// la dueña lo copia y lo manda por WhatsApp. La llave secreta vive solo aquí, nunca en el navegador.
import { createClient } from 'npm:@supabase/supabase-js@2.119.0';

const ORIGENES = ['https://grand-halva-1b3001.netlify.app', 'http://localhost:3000'];
const CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

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
  const publica = Deno.env.get('SUPABASE_ANON_KEY');
  const secreta = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !publica || !secreta) return responder(500, { error: 'configuracion' });

  // 1) ¿Quien llama es la dueña? Se pregunta a la base CON la sesión de quien llama (no se confía en nada del navegador).
  const comoQuienLlama = createClient(url, publica, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: esDuena, error: errAdmin } = await comoQuienLlama.rpc('soy_admin');
  if (errAdmin || esDuena !== true) return responder(403, { error: 'NO_AUTORIZADO' });

  // 2) Datos del pedido
  let cuerpo: { accion?: string; correo?: string; nombre?: string };
  try { cuerpo = await req.json(); } catch { return responder(400, { error: 'pedido_invalido' }); }
  const accion = String(cuerpo?.accion ?? '');
  const correo = String(cuerpo?.correo ?? '').trim().toLowerCase();
  const nombre = String(cuerpo?.nombre ?? '').replace(/\s+/g, ' ').trim().slice(0, 60);
  if (!['crear', 'enlace'].includes(accion)) return responder(400, { error: 'accion_invalida' });
  if (!CORREO.test(correo) || correo.length > 120) return responder(400, { error: 'correo_invalido' });
  if (accion === 'crear' && nombre.length < 2) return responder(400, { error: 'nombre_invalido' });

  const admin = createClient(url, secreta, { auth: { persistSession: false, autoRefreshToken: false } });
  const destino = permitido + '/entrar.html';

  // 3) Crear la cuenta (si ya existía, no es error: solo se genera el enlace)
  let existia = false;
  if (accion === 'crear') {
    const { error } = await admin.auth.admin.createUser({ email: correo, email_confirm: true, user_metadata: { nombre } });
    if (error) {
      if (/already|registered|exists/i.test(error.message)) existia = true;
      else return responder(400, { error: 'no_se_pudo_crear' });
    }
  }

  // 4) Enlace de entrada de un solo uso (no se envía ningún correo)
  const { data, error } = await admin.auth.admin.generateLink({ type: 'magiclink', email: correo, options: { redirectTo: destino } });
  if (error || !data?.properties?.action_link) {
    return responder(accion === 'enlace' ? 404 : 400, { error: accion === 'enlace' ? 'no_existe' : 'sin_enlace' });
  }

  await comoQuienLlama.rpc('admin_registrar', {
    p_accion: accion === 'crear' && !existia ? 'vendedora_creada' : 'enlace_acceso',
    p_detalle: { correo, nombre: nombre || null },
  });
  return responder(200, { ok: true, existia, enlace: data.properties.action_link });
});
