// Arma la carpeta "dist" con SOLO lo que debe verse en internet (las pantallas, el logo y ia-cliente.js).
// Los documentos internos, el servidor y las notas del proyecto NO se publican.
import { cpSync, rmSync, mkdirSync, readdirSync } from 'node:fs';
rmSync('dist', { recursive: true, force: true });
mkdirSync('dist');
for (const f of readdirSync('.')) if (f.endsWith('.html') || ['ia-cliente.js', 'frases-arte.js', 'vl-config.js', 'vl-datos.js'].includes(f)) cpSync(f, 'dist/' + f);
cpSync('logo', 'dist/logo', { recursive: true });
cpSync('vendor', 'dist/vendor', { recursive: true });
console.log('dist listo');
