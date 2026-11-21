// Lleva la paleta del logo (morado, magenta, naranja, ámbar) a las pantallas. Se corre UNA vez (20-nov-2026).
// Mantiene los nombres de las variables (--pistacho, --lima…) para no romper el código; cambia sus valores.
import { readFileSync, writeFileSync } from 'node:fs';
const ARCHIVOS = process.argv.slice(2);
const CAMBIOS = [
  // variables de color
  ['--pistacho: #a5dc5b', '--pistacho: #c9a7ff'],          // lila (tarjetas importantes, brillos de fondo)
  ['--lima: #e6ee4a', '--lima: #ffc83d'],                  // ámbar del logo (avance, logros)
  ['--tinta: #131313', '--tinta: #22104f'],                // tinta morada profunda (texto)
  ['--verde-texto: #2f6a10', '--verde-texto: #6a1fd0'],    // morado del logo (palabras resaltadas)
  ['--texto-2: #5a5648', '--texto-2: #5c5470'],            // gris con tinte morado
  // baldosas 3D de la barra
  ['.t3d.verde { --a: #b8ee62; --b: #4fae12; --sh: #2f7d0f; }', '.t3d.verde { --a: #b98cff; --b: #6a1fd0; --sh: #45109a; }'],
  ['.t3d.lima { --a: #f7fa86; --b: #d6de1c; --sh: #8a9100; color: #131313; }', '.t3d.lima { --a: #ffe08a; --b: #ffb81a; --sh: #b97800; color: #22104f; }'],
  // barras de avance: el degradé de la píldora del logo
  ['linear-gradient(90deg, var(--pistacho), var(--lima))', 'linear-gradient(90deg, #7a2ff2, #e0179f, #ff8a1a)'],
  // página de ventas, estilo A (el que se ve por defecto)
  ['--bg: #f7f3ea; --surface: #fffdf8; --text-1: #1f2a24; --text-2: #5b675e; --accent: #0e6b4f;', '--bg: #f6f1ea; --surface: #fffdfa; --text-1: #22104f; --text-2: #5c5470; --accent: #6a1fd0;'],
  ['--shadow-tinta: 20 60 45; --on-accent: #f7f3ea;', '--shadow-tinta: 50 20 90; --on-accent: #ffffff;'],
];
const HEX = [ // colores sueltos
  [/#a5dc5b/gi, '#c9a7ff'], [/#e6ee4a/gi, '#ffc83d'], [/#2f6a10/gi, '#6a1fd0'], [/#131313/gi, '#22104f'],
  [/#b8ee62|#b6ec5c|#9ee046|#8fd63a/gi, '#b98cff'], [/#4fae12|#62c01e|#3d9a0b/gi, '#6a1fd0'], [/#2f7d0f/gi, '#45109a'],
  [/#f4f87a|#f7fa86/gi, '#ffe08a'], [/#d4dc1c|#d6de1c/gi, '#ffb81a'],
  [/rgb\(19 19 19 \//g, 'rgb(34 16 79 /'], [/rgb\(40 70 20 \//g, 'rgb(60 30 100 /'], [/rgb\(20 40 10 \//g, 'rgb(40 16 80 /'],
  [/rgb\(30 60 20 \//g, 'rgb(50 24 90 /'], [/rgb\(20 50 10 \//g, 'rgb(40 16 80 /'], [/rgb\(27 77 8 \//g, 'rgb(60 20 110 /'],
];
for (const f of ARCHIVOS) {
  let t = readFileSync(f, 'utf8'); const antes = t; let n = 0;
  for (const [a, b] of CAMBIOS) { const k = t.split(a).length - 1; if (k) { n += k; t = t.split(a).join(b); } }
  for (const [re, b] of HEX) { const m = t.match(re); if (m) { n += m.length; t = t.replace(re, b); } }
  if (t !== antes) writeFileSync(f, t);
  console.log(f.padEnd(26), n, 'cambios');
}
