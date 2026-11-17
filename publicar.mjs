// Arma la carpeta "dist" con SOLO lo que debe verse en internet (las pantallas, el logo y ia-cliente.js).
// Los documentos internos, el servidor y las notas del proyecto NO se publican.
import { cpSync, rmSync, mkdirSync, readdirSync } from 'node:fs';
rmSync('dist', { recursive: true, force: true });
mkdirSync('dist');
for (const f of readdirSync('.')) if (f.endsWith('.html') || f === 'ia-cliente.js') cpSync(f, 'dist/' + f);
cpSync('logo', 'dist/logo', { recursive: true });
console.log('dist listo');
