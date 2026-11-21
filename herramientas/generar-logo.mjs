// Genera TODAS las versiones del logo de Ventas Link desde un solo dibujo (mismas piezas en todas).
// Uso: node herramientas/generar-logo.mjs   → escribe los SVG en logo/
// Referencia del dibujo: docs/referencias/logo-ventas-link-referencia.jpg (coordenadas 1280x853).
import { readFileSync, writeFileSync } from 'node:fs';

const LETRAS = JSON.parse(readFileSync(new URL('./letras-logo.json', import.meta.url), 'utf8'));
const TINTA = '#25105c';

const DEFS = `
<linearGradient id="vlPant" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e80fa8"/><stop offset=".5" stop-color="#9a16d6"/><stop offset="1" stop-color="#4a10aa"/></linearGradient>
<linearGradient id="vlPantIn" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff0fb2"/><stop offset=".55" stop-color="#a814dc"/><stop offset="1" stop-color="#5a12c8"/></linearGradient>
<linearGradient id="vlMarco" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5a16d0"/><stop offset="1" stop-color="#2f0a80"/></linearGradient>
<filter id="vlSombraCur" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="2" dy="4" stdDeviation="3" flood-color="#3a0e96" flood-opacity=".45"/></filter>
<radialGradient id="vlRueda" cx=".38" cy=".32" r=".78"><stop offset="0" stop-color="#d94ff0"/><stop offset=".5" stop-color="#8a1cd8"/><stop offset="1" stop-color="#40109a"/></radialGradient>
<linearGradient id="vlOrbita" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#ffd21a"/><stop offset=".5" stop-color="#ffb01a"/><stop offset="1" stop-color="#ff861a"/></linearGradient>
<linearGradient id="vlL1" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff4fb3"/><stop offset="1" stop-color="#9a2ee8"/></linearGradient>
<linearGradient id="vlL2" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffd21a"/><stop offset="1" stop-color="#ff8a1a"/></linearGradient>
<linearGradient id="vlL3" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffb21a"/><stop offset="1" stop-color="#ff7a1a"/></linearGradient>
<linearGradient id="vlPill" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#5a22e8"/><stop offset=".33" stop-color="#a91fdb"/><stop offset=".68" stop-color="#ff2f86"/><stop offset="1" stop-color="#ff8a2a"/></linearGradient>
<linearGradient id="vlSubr" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff8a1a"/><stop offset="1" stop-color="#ffc21a"/></linearGradient>`;

// ---------- Piezas (en coordenadas de la referencia 1280x853) ----------
const ORBITA_ATRAS = `<path d="M318 198C380 140 500 100 572 124C622 142 616 230 572 332C590 250 586 180 548 162C480 132 392 160 318 198Z" fill="url(#vlOrbita)"/>`;
const ORBITA_FRENTE = `<path d="M196 412C146 470 146 566 238 592C324 614 444 542 524 476C440 526 330 570 262 558C204 548 184 480 196 412Z" fill="url(#vlOrbita)"/>`;
const LINEAS = `<g stroke-linecap="round" fill="none">
<path d="M92 274L218 262" stroke="url(#vlL1)" stroke-width="26"/>
<path d="M44 338L230 316" stroke="url(#vlL2)" stroke-width="28"/>
<path d="M104 388L240 366" stroke="url(#vlL3)" stroke-width="26"/></g>`;
const CARRO = `<g>
<path d="M285 228Q268 230 272 246L306 420Q310 436 326 434L480 414Q496 412 499 396L534 222Q538 198 516 200Z" fill="url(#vlPant)"/>
<path d="M300 248L504 222Q518 221 515 234L488 372Q486 384 474 385L336 402Q324 403 322 392L292 262Q290 250 300 248Z" fill="url(#vlPantIn)"/>
<path d="M158 207L236 207L302 432L486 410" fill="none" stroke="url(#vlMarco)" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="346" cy="472" r="33" fill="url(#vlRueda)"/><circle cx="452" cy="458" r="33" fill="url(#vlRueda)"/>
<circle cx="337" cy="460" r="7" fill="#fff" opacity=".35"/><circle cx="441" cy="446" r="7" fill="#fff" opacity=".35"/></g>`;
const RAYOS_CLICK = `<g class="vl-rayos" stroke="#fff" stroke-width="8" stroke-linecap="round" fill="none"><path d="M384 252L388 274"/><path d="M350 278L368 291"/><path d="M338 314L360 312"/></g>`;
const CURSOR = `<g class="vl-cursor"><path transform="translate(397 296) scale(1.12) translate(-397 -296)" d="M397 296L397 386L421 364L438 403L456 395L439 357L470 355Z" fill="#fff" stroke="#fff" stroke-width="5" stroke-linejoin="round" filter="url(#vlSombraCur)"/></g>`;
const ONDA = `<circle class="vl-onda" cx="397" cy="296" r="10" fill="none" stroke="#fff" stroke-width="5" opacity="0"/>`;

function marca(animado) { return ORBITA_ATRAS + LINEAS + CARRO + ONDA + RAYOS_CLICK + CURSOR + ORBITA_FRENTE; }

// Letras: "Ventas" y "Link" (trazos de una letra gruesa inclinada, ya convertidos a figuras)
// Caja original de "Ventas": x 55.2-294.4, base 452 · de "Link": x 313.5-464.5, base 452
const VENTAS = (x, base, s, color, sy = s) => `<path transform="translate(${x} ${base}) scale(${s} ${sy}) translate(-55.2 -452)" d="${LETRAS.ventas}" fill="${color}"/>`;
const LINK = (x, base, s, color, sy = s) => `<path transform="translate(${x} ${base}) scale(${s} ${sy}) translate(-313.5 -452)" d="${LETRAS.link}" fill="${color}"/>`;

const TEXTO_COMPLETO = `
${VENTAS(620, 328, 2.34, TINTA, 2.85)}
<path d="M600 350L1085 347Q1122 347 1120 384L1112 500Q1108 532 1076 535L562 572Q520 575 522 535L548 392Q556 352 600 350Z" fill="url(#vlPill)"/>
${LINK(616, 520, 3.05, '#fff', 3.3)}
<path d="M612 574C780 558 930 548 1050 550Q1064 559 1052 568C930 566 780 568 612 574Z" fill="url(#vlSubr)"/>
<g stroke="#ff8a1a" stroke-width="17" stroke-linecap="round" fill="none"><path d="M1142 430L1194 388"/><path d="M1152 456L1224 446"/><path d="M1146 490L1194 524"/></g>`;
const LEMA = `<text x="648" y="650" text-anchor="middle" font-family="Montserrat, Poppins, 'Segoe UI', Roboto, Arial, sans-serif" font-weight="600" font-style="italic" font-size="50" letter-spacing="9.5" fill="${TINTA}">Compra <tspan fill="#ff9a1a">•</tspan> Vende <tspan fill="#ff9a1a">•</tspan> Crece</text>`;

const CSS_ANIM = `<style>
.vl-cursor{transform-box:view-box;transform-origin:397px 296px;animation:vlCur 2.6s cubic-bezier(.45,0,.2,1) infinite}
.vl-rayos{transform-box:view-box;transform-origin:397px 296px;opacity:0;animation:vlRay 2.6s ease-out infinite}
.vl-onda{transform-box:view-box;transform-origin:397px 296px;animation:vlOnda 2.6s ease-out infinite}
@keyframes vlCur{0%{transform:translate(16px,18px)}38%{transform:translate(0,0)}46%{transform:translate(0,0) scale(.84)}56%{transform:translate(0,0) scale(1)}78%{transform:translate(0,0)}100%{transform:translate(16px,18px)}}
@keyframes vlRay{0%,42%{opacity:0;transform:scale(.6)}50%{opacity:1;transform:scale(1.08)}70%{opacity:1;transform:scale(1)}86%,100%{opacity:0;transform:scale(1)}}
@keyframes vlOnda{0%,44%{opacity:0;r:8px}50%{opacity:.85;r:12px}76%{opacity:0;r:40px}100%{opacity:0;r:40px}}
@media (prefers-reduced-motion: reduce){.vl-cursor,.vl-rayos,.vl-onda{animation:none}.vl-rayos{opacity:1}}
</style>`;

function svg({ vb, w, h, cuerpo, animado, fondo = '', titulo = 'Ventas Link' }) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" width="${w}" height="${h}" role="img" aria-label="${titulo}"><title>${titulo}</title><defs>${DEFS}</defs>${animado ? CSS_ANIM : ''}${fondo}${cuerpo}</svg>\n`;
}

// Logo completo: carrito + Ventas Link + lema (ancho)
const COMPLETO_VB = '12 70 1256 620';
const completo = (animado) => svg({ vb: COMPLETO_VB, w: 1256, h: 620, animado, cuerpo: marca(animado) + TEXTO_COMPLETO + LEMA });

// Solo el carrito (ícono): recorte cuadrado alrededor de la marca
const MARCA_VB = (pad) => `${20 - pad} ${70 - pad} ${620 + pad * 2} ${620 + pad * 2}`;
function icono(animado) {
  const fondo = `<rect x="5" y="25" width="640" height="640" rx="148" fill="#fff"/>`;
  return svg({ vb: '5 25 640 640', w: 512, h: 512, animado, fondo, cuerpo: `<g transform="translate(325 345) scale(.96) translate(-325 -345)">${marca(animado)}</g>` });
}
function perfil() {
  const fondo = `<rect x="-25" y="-5" width="700" height="700" fill="#fff"/><circle cx="325" cy="345" r="346" fill="#fbf7ff"/>`;
  return svg({ vb: '-25 -5 700 700', w: 1024, h: 1024, animado: false, fondo, cuerpo: `<g transform="translate(325 345) scale(.84) translate(-325 -345)">${marca(false)}</g>` });
}

// Horizontal (encabezados): carrito pequeño + "Ventas" + píldora "Link" en una sola línea
function horizontal() {
  const m = `<g transform="translate(0 0) scale(.42)">${marca(false)}</g>`;
  const t = `${VENTAS(280, 192, 1.36, TINTA, 1.6)}
<path d="M650 110L866 108Q892 108 889 134L882 196Q879 220 854 221L638 226Q610 227 613 199L622 136Q626 111 650 110Z" fill="url(#vlPill)"/>
${LINK(634, 204, 1.62, '#fff', 1.78)}`;
  return svg({ vb: '8 30 892 228', w: 892, h: 228, animado: false, cuerpo: m + t });
}

// Ícono de pantalla completa (Android "maskable" y iPhone): fondo blanco hasta el borde y el carrito dentro de la zona segura.
function iconoCompleto() {
  const fondo = `<rect x="-55" y="-35" width="760" height="760" fill="#fff"/>`;
  return svg({ vb: '-55 -35 760 760', w: 512, h: 512, animado: false, fondo, cuerpo: `<g transform="translate(325 345) scale(.78) translate(-325 -345)">${marca(false)}</g>` });
}
// Insignia de la barra de notificaciones de Android: silueta blanca del carrito sobre fondo transparente.
function insignia() {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96"><g fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">
<path d="M8 20h12l10 40h40l8-30H26"/></g><path d="M50 34l0 14 5-4 3 7 3-1-3-7 6-1z" fill="#fff"/><circle cx="36" cy="76" r="7" fill="#fff"/><circle cx="64" cy="76" r="7" fill="#fff"/></svg>\n`;
}

const SALIDAS = {
  'logo/ventas-link-icono-completo.svg': iconoCompleto(),
  'logo/ventas-link-insignia.svg': insignia(),
  'logo/ventas-link-logo.svg': completo(true),
  'logo/ventas-link-logo-estatico.svg': completo(false),
  'logo/ventas-link-logo-sinfondo.svg': completo(false),
  'logo/ventas-link-icono.svg': icono(false),
  'logo/ventas-link-icono-animado.svg': icono(true),
  'logo/ventas-link-perfil.svg': perfil(),
  'logo/ventas-link-horizontal.svg': horizontal(),
};
const soloMostrar = process.argv[2] === '--prueba';
for (const [f, s] of Object.entries(SALIDAS)) {
  if (soloMostrar) continue;
  writeFileSync(new URL('../' + f, import.meta.url), s);
  console.log(f, s.length, 'caracteres');
}
export { completo, icono, horizontal, perfil };
