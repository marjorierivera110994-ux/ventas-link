// Ventas Link — envía las notificaciones push que la base dejó en su bandeja (private.avisos).
// La despierta la propia base (al crear un aviso y cada minuto) con una contraseña interna que solo ella conoce.
// Las llaves de firma se crean aquí la primera vez y se guardan en la base: nunca pasan por el navegador ni por el chat.
import { createClient } from 'npm:@supabase/supabase-js@2.119.0';
import { enviarPush, generarVapid, type LlavesVapid } from './webpush.ts';

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });

interface Aviso { id: number; categoria: string; titulo: string; cuerpo: string; url: string; etiqueta: string;
                  subs: { endpoint: string; p256dh: string; auth: string }[] }

const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { 'Content-Type': 'application/json' } });

function iguales(a: string, b: string): boolean {
  if (a.length !== b.length || !a) return false;
  let x = 0;
  for (let i = 0; i < a.length; i++) x |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return x === 0;
}

async function rpc<T>(nombre: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await admin.rpc(nombre, args);
  if (error) throw new Error(nombre + ': ' + error.message);
  return data as T;
}

// Cuánto tiempo guarda el servicio de avisos un mensaje si el celular está apagado, y su prioridad.
const TTL: Record<string, number> = { pedidos: 86400, consultas: 3600, estados: 43200, felicitaciones: 86400, recordatorio: 14400, prueba: 600 };
const URGENCIA: Record<string, 'high' | 'normal' | 'low'> = { pedidos: 'high', consultas: 'high', prueba: 'high', estados: 'normal', felicitaciones: 'normal', recordatorio: 'low' };

async function procesar(a: Aviso, v: LlavesVapid, contacto: string) {
  if (!a.subs.length) { await rpc('avisos_resultado', { p_id: a.id, p_estado: 'sin_destino', p_detalle: 'sin celulares' }); return 'sin_destino'; }
  const datos = { t: a.titulo, b: a.cuerpo, u: a.url, g: a.etiqueta, id: a.id };
  const ok: string[] = [], borrar: string[] = [], fallo: string[] = []; const codigos: number[] = [];
  await Promise.all(a.subs.map(async (s) => {
    try {
      const st = await enviarPush(s, datos, v, contacto, TTL[a.categoria] ?? 86400, URGENCIA[a.categoria] ?? 'normal');
      codigos.push(st);
      if (st >= 200 && st < 300) ok.push(s.endpoint);
      else if (st === 404 || st === 410) borrar.push(s.endpoint);       // ese celular desinstaló o quitó el permiso
      else fallo.push(s.endpoint);
    } catch (_e) { codigos.push(0); fallo.push(s.endpoint); }
  }));
  const estado = ok.length ? 'enviado' : (borrar.length === a.subs.length ? 'sin_destino' : 'error');
  await rpc('avisos_resultado', { p_id: a.id, p_estado: estado, p_detalle: codigos.join(','), p_ok: ok, p_borrar: borrar, p_fallo: fallo });
  return estado;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'metodo' }, 405);
  let cfg: { publica: string | null; privada: JsonWebKey | null; token: string; contacto: string };
  try { cfg = await rpc('push_config_servidor'); } catch (_e) { return json({ error: 'config' }, 500); }
  if (!iguales(req.headers.get('x-vl-token') ?? '', cfg.token)) return json({ error: 'no_autorizado' }, 401);

  // Primera vez: crear las llaves de firma (si dos llamadas compiten, la base se queda con la primera).
  if (!cfg.publica || !cfg.privada) {
    const k = await generarVapid();
    await rpc('push_guardar_llaves', { p_publica: k.publica, p_privada: k.privada });
    cfg = await rpc('push_config_servidor');
  }
  const v: LlavesVapid = { publica: cfg.publica!, privada: cfg.privada! };
  const cuerpo = await req.json().catch(() => ({}));
  if (cuerpo?.accion === 'iniciar') return json({ ok: true, llave: true });

  const resumen: Record<string, number> = {};
  const inicio = Date.now();
  for (let vuelta = 0; vuelta < 5 && Date.now() - inicio < 20000; vuelta++) {
    const lote = await rpc<Aviso[]>('avisos_tomar', { p_limite: 50 });
    if (!lote.length) break;
    const res = await Promise.all(lote.map((a) => procesar(a, v, cfg.contacto).catch(() => 'error')));
    for (const e of res) resumen[e] = (resumen[e] ?? 0) + 1;
  }
  return json({ ok: true, ...resumen });
});
