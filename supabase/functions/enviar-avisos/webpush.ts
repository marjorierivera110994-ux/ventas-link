// Web Push sin librerías externas (solo WebCrypto): cifrado RFC 8291 (aes128gcm) + firma VAPID RFC 8292 (ES256).
// Funciona igual en Deno (Supabase Edge Functions) y en Node 20+ (para las pruebas locales).
const te = new TextEncoder();

export function b64u(datos: ArrayBuffer | Uint8Array): string {
  const b = datos instanceof Uint8Array ? datos : new Uint8Array(datos);
  let s = '';
  for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function desB64u(s: string): Uint8Array {
  const t = s.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(t + '='.repeat((4 - (t.length % 4)) % 4));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function unir(...partes: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(partes.reduce((n, p) => n + p.length, 0));
  let i = 0;
  for (const p of partes) { out.set(p, i); i += p.length; }
  return out;
}

async function hmac(llave: Uint8Array, datos: Uint8Array): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey('raw', llave, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, datos));
}

export interface OpcionesCifrado { sal?: Uint8Array; llavesServidor?: CryptoKeyPair; }

/** Cifra el mensaje para UN celular (p256dh + auth de su suscripción). Devuelve el cuerpo listo para enviar. */
export async function cifrar(mensaje: Uint8Array, p256dh: string, auth: string, op: OpcionesCifrado = {}): Promise<Uint8Array> {
  const uaPublica = desB64u(p256dh);
  const secreto = desB64u(auth);
  if (uaPublica.length !== 65 || secreto.length !== 16) throw new Error('suscripcion_invalida');
  const sal = op.sal ?? crypto.getRandomValues(new Uint8Array(16));
  const as = op.llavesServidor ?? await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']) as CryptoKeyPair;
  const asPublica = new Uint8Array(await crypto.subtle.exportKey('raw', as.publicKey));
  const uaLlave = await crypto.subtle.importKey('raw', uaPublica, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaLlave }, as.privateKey, 256));
  const prkLlave = await hmac(secreto, ecdh);
  const info = unir(te.encode('WebPush: info\0'), uaPublica, asPublica);
  const ikm = await hmac(prkLlave, unir(info, new Uint8Array([1])));
  const prk = await hmac(sal, ikm);
  const cek = (await hmac(prk, unir(te.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, unir(te.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12);
  const llaveAes = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const cifrado = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, llaveAes, unir(mensaje, new Uint8Array([2]))));
  const rs = new Uint8Array(4); new DataView(rs.buffer).setUint32(0, 4096);
  return unir(sal, rs, new Uint8Array([asPublica.length]), asPublica, cifrado);
}

export interface LlavesVapid { publica: string; privada: JsonWebKey; }

/** Crea el par de llaves de firma (una sola vez en la vida del servidor). */
export async function generarVapid(): Promise<LlavesVapid> {
  const k = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']) as CryptoKeyPair;
  const publica = b64u(await crypto.subtle.exportKey('raw', k.publicKey));
  const j = await crypto.subtle.exportKey('jwk', k.privateKey) as JsonWebKey;
  return { publica, privada: { kty: j.kty, crv: j.crv, d: j.d, x: j.x, y: j.y } };
}

/** Encabezado Authorization firmado para el servicio de notificaciones de ese celular (Google, Apple, Mozilla o Microsoft). */
export async function cabeceraVapid(endpoint: string, v: LlavesVapid, contacto: string): Promise<string> {
  const aud = new URL(endpoint).origin;
  const cab = b64u(te.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const datos = b64u(te.encode(JSON.stringify({ aud, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: contacto })));
  const llave = await crypto.subtle.importKey('jwk', { ...v.privada, ext: true }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const firma = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, llave, te.encode(cab + '.' + datos));
  return `vapid t=${cab}.${datos}.${b64u(firma)}, k=${v.publica}`;
}

export interface Suscripcion { endpoint: string; p256dh: string; auth: string; }

/** Envía un aviso a un celular. Devuelve el código HTTP del servicio (201 = entregado al servicio; 404/410 = ese celular ya no existe). */
export async function enviarPush(s: Suscripcion, datos: unknown, v: LlavesVapid, contacto: string,
                                 ttl = 86400, urgencia: 'very-low' | 'low' | 'normal' | 'high' = 'normal'): Promise<number> {
  const cuerpo = await cifrar(te.encode(JSON.stringify(datos)), s.p256dh, s.auth);
  const r = await fetch(s.endpoint, {
    method: 'POST',
    headers: {
      'Content-Encoding': 'aes128gcm',
      'Content-Type': 'application/octet-stream',
      'TTL': String(ttl),
      'Urgency': urgencia,
      'Authorization': await cabeceraVapid(s.endpoint, v, contacto),
    },
    body: cuerpo,
  });
  try { await r.arrayBuffer(); } catch { /* cuerpo vacío */ }
  return r.status;
}
