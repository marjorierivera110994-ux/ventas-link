// Servidor de Ventas Link: sirve la app y la ruta segura /api/ia. Uso local: npm start  (luego abre http://localhost:3000)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MODELO, validar, crearCliente, generar } from './ia.js';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const RAIZ = path.resolve(AQUI, '..');
const PUERTO = Number(process.env.PORT) || 3000;
const LIMITE_HORA = { gratis: 5, emprendedor: 30, pro: 100 }; // pedidos por hora y por visitante (HIPÓTESIS: ajustar con costo real)
const LIMITE_DIA_GLOBAL = Number(process.env.IA_MAX_DIARIO) || 200; // freno de emergencia de costo: pedidos de IA por día entre todos
const TIPOS_ARCHIVO = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.json': 'application/json' };

const porVisitante = new Map();
let dia = new Date().toISOString().slice(0, 10), usadosHoy = 0;
let cliente = null;
const hayLlave = () => Boolean(process.env.ANTHROPIC_API_KEY);

function responder(res, estado, cuerpo) {
  res.writeHead(estado, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  res.end(JSON.stringify(cuerpo));
}
function leerCuerpo(req, max = 8192) {
  return new Promise((ok, mal) => {
    let n = 0; const trozos = [];
    let corto = false;
    req.on('data', t => { n += t.length; if (n > max) { if (!corto) { corto = true; mal(new Error('grande')); } } else trozos.push(t); });
    req.on('end', () => { if (corto) return; try { ok(JSON.parse(Buffer.concat(trozos).toString('utf8'))); } catch { mal(new Error('json')); } });
    req.on('error', mal);
  });
}
function dentroDelLimite(ip, plan) {
  const hoy = new Date().toISOString().slice(0, 10);
  if (hoy !== dia) { dia = hoy; usadosHoy = 0; }
  if (usadosHoy >= LIMITE_DIA_GLOBAL) return 'limite-diario';
  const ahora = Date.now(), marcas = (porVisitante.get(ip) || []).filter(t => ahora - t < 3600000);
  if (marcas.length >= LIMITE_HORA[plan]) { porVisitante.set(ip, marcas); return 'limite-hora'; }
  marcas.push(ahora); porVisitante.set(ip, marcas); usadosHoy++;
  return null;
}
const MENSAJES = {
  'sin-llave': 'La IA aún no está conectada. Falta la llave del servidor.',
  'llave-invalida': 'La llave de la IA no es válida. Revisa la configuración del servidor.',
  'limite-hora': 'Llegaste al límite de pedidos de IA por esta hora. Intenta más tarde o sube de plan.',
  'limite-diario': 'La IA descansa hoy para cuidar el servicio. Vuelve mañana.',
  'ocupado': 'La IA está muy ocupada. Intenta de nuevo en un momento.',
  'rechazado': 'No pude escribir ese texto. Prueba con otras palabras.',
  'servicio': 'No pudimos hablar con la IA ahora. Intenta de nuevo.',
  'pedido-rechazado': 'No pudimos procesar ese pedido.', 'vacio': 'La IA no devolvió texto. Intenta de nuevo.',
  'pedido-invalido': 'Faltan datos para escribir el texto.', 'tipo-invalido': 'Ese tipo de texto no existe.', 'falta-producto': 'Escribe el nombre del producto.', 'falta-pregunta': 'Escribe la pregunta del cliente.'
};

async function api(req, res) {
  const url = new URL(req.url, 'http://x');
  if (req.method === 'GET' && url.pathname === '/api/estado') return responder(res, 200, { ia: hayLlave(), modelo: hayLlave() ? MODELO : null });
  if (req.method === 'POST' && url.pathname === '/api/ia') {
    const origen = req.headers.origin; // solo desde la misma página
    if (origen && new URL(origen).host !== req.headers.host) return responder(res, 403, { error: 'origen', mensaje: 'Pedido no permitido.' });
    let cuerpo;
    try { cuerpo = await leerCuerpo(req); } catch (e) { if (e.message === 'grande') return responder(res, 413, { error: 'pedido-grande', mensaje: 'El pedido es demasiado grande.' }); return responder(res, 400, { error: 'pedido-invalido', mensaje: MENSAJES['pedido-invalido'] }); }
    const v = validar(cuerpo);
    if (!v.ok) return responder(res, 400, { error: v.error, mensaje: MENSAJES[v.error] || MENSAJES['pedido-invalido'] });
    if (!hayLlave()) return responder(res, 503, { error: 'sin-llave', mensaje: MENSAJES['sin-llave'] });
    const lim = dentroDelLimite(req.socket.remoteAddress || 'x', v.plan);
    if (lim) return responder(res, 429, { error: lim, mensaje: MENSAJES[lim] });
    try {
      cliente ??= crearCliente();
      const r = await generar(cliente, v.tipo, v.datos);
      console.log(`[ia] ${v.tipo} ok · entrada ${r.tokens.entrada} · salida ${r.tokens.salida}`); // solo cifras: nunca el texto del cliente ni la llave
      return responder(res, 200, { texto: r.texto });
    } catch (e) {
      const c = e && e.codigo ? e.codigo : 'servicio';
      console.log(`[ia] ${v.tipo} falló: ${c}`);
      return responder(res, c === 'llave-invalida' ? 503 : c === 'ocupado' ? 429 : c === 'rechazado' ? 422 : 502, { error: c, mensaje: MENSAJES[c] || MENSAJES.servicio });
    }
  }
  return responder(res, 404, { error: 'no-existe' });
}

function estatico(req, res) {
  let ruta = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (ruta === '/') ruta = '/vista-pagina-ventas.html';
  const archivo = path.normalize(path.join(RAIZ, ruta));
  const rel = path.relative(RAIZ, archivo);
  const ext = path.extname(archivo).toLowerCase();
  if (rel.startsWith('..') || path.isAbsolute(rel) || rel.split(path.sep).some(p => p.startsWith('.') || p === 'servidor' || p === 'node_modules') || !TIPOS_ARCHIVO[ext]) { res.writeHead(404); return res.end('No encontrado'); }
  fs.readFile(archivo, (err, datos) => {
    if (err) { res.writeHead(404); return res.end('No encontrado'); }
    res.writeHead(200, { 'Content-Type': TIPOS_ARCHIVO[ext], 'X-Content-Type-Options': 'nosniff' });
    res.end(datos);
  });
}

http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) api(req, res).catch(() => responder(res, 500, { error: 'servicio', mensaje: MENSAJES.servicio }));
  else estatico(req, res);
}).listen(PUERTO, () => {
  console.log(`Ventas Link en http://localhost:${PUERTO}`);
  console.log(hayLlave() ? `IA conectada (modelo ${MODELO}).` : 'IA SIN llave: copia .env.example a .env y pega tu llave (solo en tu computadora).');
});
