// Pruebas del envío de notificaciones (sin internet): node herramientas/prueba-webpush.mjs
// 1) cifrado idéntico al ejemplo oficial del RFC 8291 · 2) firma VAPID válida · 3) un "servicio de avisos" falso
//    recibe el envío, verifica la firma y descifra el mensaje con la llave del celular.
import http from 'node:http';
import { cifrar, generarVapid, cabeceraVapid, enviarPush, b64u, desB64u } from '../supabase/functions/enviar-avisos/webpush.ts';

const te = new TextEncoder(), td = new TextDecoder();
let fallas = 0;
const ok = (nombre, cond, extra = '') => { console.log((cond ? '✔ ' : '✘ ') + nombre + (extra ? ' — ' + extra : '')); if (!cond) fallas++; };
const igual = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);
const unir = (...p) => { const o = new Uint8Array(p.reduce((n, x) => n + x.length, 0)); let i = 0; for (const x of p) { o.set(x, i); i += x.length; } return o; };
async function hmac(k, d) { const key = await crypto.subtle.importKey('raw', k, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']); return new Uint8Array(await crypto.subtle.sign('HMAC', key, d)); }

// ---------- 1. Vector oficial RFC 8291, Apéndice A ----------
const asPub = desB64u('BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8');
const asPrivD = 'yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw';
const uaPub = 'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4';
const sal = desB64u('DGv6ra1nlYgDCS1FRnbzlw');
const authSecret = 'BTBZMqHH6r4Tts7J_aSIgg';
const texto = desB64u('V2hlbiBJIGdyb3cgdXAsIEkgd2FudCB0byBiZSBhIHdhdGVybWVsb24');
const esperado = unir(
  desB64u('DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8'),
  desB64u('8pfeW0KbunFT06SuDKoJH9Ql87S1QUrdirN6GcG7sFz1y1sqLgVi1VhjVkHsUoEsbI_0LpXMuGvnzQ'));
const jwk = { kty: 'EC', crv: 'P-256', d: asPrivD, x: b64u(asPub.slice(1, 33)), y: b64u(asPub.slice(33, 65)), ext: true };
const llavesServidor = {
  privateKey: await crypto.subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']),
  publicKey: await crypto.subtle.importKey('raw', asPub, { name: 'ECDH', namedCurve: 'P-256' }, true, []),
};
const salida = await cifrar(texto, uaPub, authSecret, { sal, llavesServidor });
ok('Cifrado igual al ejemplo oficial (RFC 8291)', igual(salida, esperado), salida.length + ' bytes');
ok('El texto del ejemplo es el esperado', td.decode(texto) === 'When I grow up, I want to be a watermelon');

// ---------- 2. Firma VAPID ----------
const v = await generarVapid();
ok('Llave pública VAPID de 65 bytes', desB64u(v.publica).length === 65 && v.publica.length === 87);
const cab = await cabeceraVapid('https://fcm.googleapis.com/fcm/send/abc123', v, 'https://grand-halva-1b3001.netlify.app');
const m = cab.match(/^vapid t=([^.]+)\.([^.]+)\.([^,]+), k=(.+)$/);
ok('Encabezado con formato "vapid t=…, k=…"', !!m && m[4] === v.publica);
const claims = JSON.parse(td.decode(desB64u(m[2])));
ok('aud = servicio del celular', claims.aud === 'https://fcm.googleapis.com');
ok('exp entre 1 y 24 horas', claims.exp - Date.now() / 1000 > 3600 && claims.exp - Date.now() / 1000 <= 86400);
const verif = await crypto.subtle.importKey('raw', desB64u(v.publica), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
ok('Firma verificable con la llave pública', await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, verif, desB64u(m[3]), te.encode(m[1] + '.' + m[2])));

// ---------- 3. Envío completo a un servicio de avisos falso ----------
const ua = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
const uaRaw = new Uint8Array(await crypto.subtle.exportKey('raw', ua.publicKey));
const authUa = crypto.getRandomValues(new Uint8Array(16));
const recibido = await new Promise((resolver) => {
  const srv = http.createServer((req, res) => {
    const partes = [];
    req.on('data', (c) => partes.push(c));
    req.on('end', async () => {
      res.writeHead(201); res.end(); srv.close();
      resolver({ headers: req.headers, cuerpo: new Uint8Array(Buffer.concat(partes)) });
    });
  });
  srv.listen(0, '127.0.0.1', async () => {
    const puerto = srv.address().port;
    const estado = await enviarPush({ endpoint: `http://127.0.0.1:${puerto}/push/abc`, p256dh: b64u(uaRaw), auth: b64u(authUa) },
      { t: '🛍️ Nuevo pedido #12', b: 'Blusa de seda ×2 · $28,00', u: 'app-vendedor.html#pedidos' }, v, 'https://grand-halva-1b3001.netlify.app', 600, 'high');
    ok('El servicio respondió 201', estado === 201);
  });
});
ok('Encabezados correctos', recibido.headers['content-encoding'] === 'aes128gcm' && recibido.headers.ttl === '600' && recibido.headers.urgency === 'high');
// El "celular" descifra con SU llave privada (lado receptor del RFC).
const c = recibido.cuerpo, salR = c.slice(0, 16), rs = new DataView(c.buffer, c.byteOffset + 16, 4).getUint32(0), idlen = c[20], asPubR = c.slice(21, 21 + idlen), datos = c.slice(21 + idlen);
const asKey = await crypto.subtle.importKey('raw', asPubR, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: asKey }, ua.privateKey, 256));
const ikm = await hmac(await hmac(authUa, ecdh), unir(te.encode('WebPush: info\0'), uaRaw, asPubR, new Uint8Array([1])));
const prk = await hmac(salR, ikm);
const cek = (await hmac(prk, unir(te.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16);
const nonce = (await hmac(prk, unir(te.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12);
const plano = new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: nonce }, await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['decrypt']), datos));
ok('Tamaño de registro 4096 y delimitador final', rs === 4096 && plano[plano.length - 1] === 2);
const msj = JSON.parse(td.decode(plano.slice(0, -1)));
ok('El celular descifra el aviso', msj.t === '🛍️ Nuevo pedido #12' && msj.u === 'app-vendedor.html#pedidos', msj.t);
const a = recibido.headers.authorization.match(/^vapid t=([^.]+)\.([^.]+)\.([^,]+), k=(.+)$/);
ok('El servicio puede verificar la firma', await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, verif, desB64u(a[3]), te.encode(a[1] + '.' + a[2])));

console.log(fallas ? `\n${fallas} prueba(s) fallaron` : '\nTodas las pruebas pasaron');
process.exit(fallas ? 1 : 0);
