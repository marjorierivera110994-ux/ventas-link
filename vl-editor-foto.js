/* Ventas Link — Editor de fotos del producto (plan Profesional). Todo se hace EN EL CELULAR: la foto no viaja a ningún servicio.
   VLEditor.abrir(fuente) → Promise<{ blob, ext, tipo, url } | null>   fuente: Blob/File o URL de una foto ya guardada.
   Herramientas: mejora inteligente (1 toque), luz y color, fondo blanco u otro fondo (recorta el producto), recorte y formato. */
(function () {
  'use strict';
  var PREV = 640, FULL = 1280;   // tamaño de trabajo: vista rápida y foto final

  /* ---------- Fondos (todos claros para que el producto resalte) ---------- */
  function fEstudio(c1, c2, piso) { return function (x, W, H) { var g = x.createRadialGradient(W / 2, H * .34, W * .05, W / 2, H * .4, Math.max(W, H) * .78); g.addColorStop(0, c1); g.addColorStop(1, c2); x.fillStyle = g; x.fillRect(0, 0, W, H); var y = Math.round(H * .66), s = x.createLinearGradient(0, y, 0, H); s.addColorStop(0, piso); s.addColorStop(1, c1); x.fillStyle = s; x.fillRect(0, y, W, H - y); var l = x.createLinearGradient(0, y - 26, 0, y + 26); l.addColorStop(0, 'rgba(0,0,0,0)'); l.addColorStop(.5, 'rgba(0,0,0,.07)'); l.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = l; x.fillRect(0, y - 26, W, 52); }; }
  function fDegrade(a, b, c) { return function (x, W, H) { var g = x.createLinearGradient(0, 0, W * .4, H); g.addColorStop(0, a); g.addColorStop(.55, b); g.addColorStop(1, c); x.fillStyle = g; x.fillRect(0, 0, W, H); var o = x.createRadialGradient(W * .78, H * .16, 0, W * .78, H * .16, W * .6); o.addColorStop(0, 'rgba(255,255,255,.55)'); o.addColorStop(1, 'rgba(255,255,255,0)'); x.fillStyle = o; x.fillRect(0, 0, W, H); }; }
  function fMarmol(x, W, H) { x.fillStyle = '#f7f6f3'; x.fillRect(0, 0, W, H); var s = 7; function r() { s = (s * 16807) % 2147483647; return s / 2147483647; } x.lineCap = 'round'; for (var i = 0; i < 16; i++) { var px = r() * W, py = r() * H; x.strokeStyle = 'rgba(120,125,135,' + (.05 + r() * .12) + ')'; x.lineWidth = (1 + r() * 5) * W / 1080; x.beginPath(); x.moveTo(px, py); for (var k = 0; k < 6; k++) { px += (r() - .3) * W * .22; py += (r() - .4) * H * .2; x.lineTo(px, py); } x.stroke(); } }
  function fMadera(x, W, H) { var y = Math.round(H * .62); var p = x.createLinearGradient(0, 0, 0, y); p.addColorStop(0, '#fbf6ee'); p.addColorStop(1, '#f0e6d6'); x.fillStyle = p; x.fillRect(0, 0, W, y); var alto = Math.ceil((H - y) / 5); for (var i = 0; i < 5; i++) { x.fillStyle = ['#ecd6b3', '#e6cda6', '#efdbbb', '#e3c99f', '#ead2ad'][i]; x.fillRect(0, y + i * alto, W, alto); } var l = x.createLinearGradient(0, y - 30, 0, y + 30); l.addColorStop(0, 'rgba(0,0,0,0)'); l.addColorStop(.5, 'rgba(60,40,10,.12)'); l.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = l; x.fillRect(0, y - 30, W, 60); }
  var FONDOS = [['original', 'Original', null, '#d9d2e6'], ['blanco', 'Blanco', '#ffffff', '#ffffff'], ['crema', 'Crema', '#f4ecdb', '#f4ecdb'], ['lila', 'Lila', '#efe6ff', '#efe6ff'],
    ['estudio', 'Estudio', fEstudio('#ffffff', '#e4e6ea', '#eceef1'), '#e9ebee'], ['rosa', 'Rosa', fEstudio('#fff5f8', '#ffd3e1', '#ffe3ec'), '#ffdbe7'], ['celeste', 'Celeste', fEstudio('#f3fbff', '#bfe6ff', '#d9f1ff'), '#cfeeff'],
    ['menta', 'Menta', fEstudio('#f4fff9', '#bdf0d9', '#d8f8ea'), '#cdf3e1'], ['atardecer', 'Atardecer', fDegrade('#fff0d9', '#ffd3b0', '#ffc0b8'), '#ffd3b6'], ['aurora', 'Aurora', fDegrade('#e6fbff', '#d9e4ff', '#f3dcff'), '#e2e4ff'],
    ['marmol', 'Mármol', fMarmol, '#efefec'], ['madera', 'Madera', fMadera, '#e8cfa8']];
  var FORMATOS = [['1:1', 'Cuadrada'], ['4:5', 'Vertical'], ['orig', 'Original']];

  /* ---------- Luz y color ---------- */
  function mejorar(src, o) {
    var d = new ImageData(new Uint8ClampedArray(src.data), src.width, src.height), p = d.data, lo = 0, hi = 255, gamma = 1;
    if (o.auto) {
      var hist = new Uint32Array(256), suma = 0, cnt = 0; for (var i = 0; i < p.length; i += 16) { var l = (p[i] * 299 + p[i + 1] * 587 + p[i + 2] * 114) / 1000 | 0; hist[l]++; suma += l; cnt++; }
      var acc = 0, a1 = cnt * 0.01, a99 = cnt * 0.99; for (var v = 0; v < 256; v++) { acc += hist[v]; if (!lo && acc >= a1) lo = v; if (acc >= a99) { hi = v; break; } }
      if (hi - lo < 60) { lo = 0; hi = 255; }
      var media = (suma / cnt - lo) / Math.max(1, hi - lo); media = Math.min(.9, Math.max(.05, media)); gamma = Math.min(1.5, Math.max(.7, Math.log(.5) / Math.log(media)));
    }
    var br = o.brillo * 1.4, ct = 1 + o.contraste / 100, sat = o.color / 100, rango = Math.max(1, hi - lo);
    for (var j = 0; j < p.length; j += 4) {
      var r = p[j], g = p[j + 1], b = p[j + 2];
      if (o.auto) { r = 255 * Math.pow(Math.min(1, Math.max(0, (r - lo) / rango)), gamma); g = 255 * Math.pow(Math.min(1, Math.max(0, (g - lo) / rango)), gamma); b = 255 * Math.pow(Math.min(1, Math.max(0, (b - lo) / rango)), gamma); }
      r += br; g += br; b += br; r = (r - 128) * ct + 128; g = (g - 128) * ct + 128; b = (b - 128) * ct + 128;
      var y = .299 * r + .587 * g + .114 * b; p[j] = y + (r - y) * sat; p[j + 1] = y + (g - y) * sat; p[j + 2] = y + (b - y) * sat;
    }
    return d;
  }

  /* ---------- Recorte del producto: quita el color liso que toca los bordes ---------- */
  function distancia(p, i, c) { var a = p[i] - c[0], b = p[i + 1] - c[1], d = p[i + 2] - c[2]; return Math.sqrt(a * a + b * b + d * d); }
  function desenfocar(a, W, H, r) {
    var t = new Float32Array(a.length), o = new Float32Array(a.length), d = r * 2 + 1;
    for (var y = 0; y < H; y++) { var s = 0, row = y * W; for (var x = -r; x <= r; x++) s += a[row + Math.min(W - 1, Math.max(0, x))]; for (var x2 = 0; x2 < W; x2++) { t[row + x2] = s / d; s += a[row + Math.min(W - 1, x2 + r + 1)] - a[row + Math.max(0, x2 - r)]; } }
    for (var x3 = 0; x3 < W; x3++) { var s2 = 0; for (var y3 = -r; y3 <= r; y3++) s2 += t[Math.min(H - 1, Math.max(0, y3)) * W + x3]; for (var y4 = 0; y4 < H; y4++) { o[y4 * W + x3] = s2 / d; s2 += t[Math.min(H - 1, y4 + r + 1) * W + x3] - t[Math.max(0, y4 - r) * W + x3]; } }
    return o;
  }
  function mascara(src, tol) {
    var W = src.width, H = src.height, p = src.data, N = W * H, anillo = Math.max(2, Math.round(Math.min(W, H) * 0.03)), sr = 0, sg = 0, sb = 0, sn = 0;
    for (var y = 0; y < H; y++) for (var x = 0; x < W; x++) { if (x < anillo || y < anillo || x >= W - anillo || y >= H - anillo) { var i = (y * W + x) * 4; sr += p[i]; sg += p[i + 1]; sb += p[i + 2]; sn++; } }
    var c = [sr / sn, sg / sn, sb / sn], bg = new Uint8Array(N), cola = new Int32Array(N), ini = 0, fin = 0;
    function intentar(idx, padre) {
      if (bg[idx]) return; var i = idx * 4, dc = distancia(p, i, c), ok = dc < tol;
      if (!ok && padre >= 0) { var j = padre * 4, dx = p[i] - p[j], dy = p[i + 1] - p[j + 1], dz = p[i + 2] - p[j + 2]; ok = Math.sqrt(dx * dx + dy * dy + dz * dz) < tol * 0.22 && dc < tol * 2.2; }
      if (ok) { bg[idx] = 1; cola[fin++] = idx; }
    }
    for (var x2 = 0; x2 < W; x2++) { intentar(x2, -1); intentar((H - 1) * W + x2, -1); }
    for (var y2 = 0; y2 < H; y2++) { intentar(y2 * W, -1); intentar(y2 * W + W - 1, -1); }
    while (ini < fin) { var k = cola[ini++], kx = k % W; if (kx > 0) intentar(k - 1, k); if (kx < W - 1) intentar(k + 1, k); if (k >= W) intentar(k - W, k); if (k < N - W) intentar(k + W, k); }
    var a = new Float32Array(N), cuenta = 0; for (var q = 0; q < N; q++) { a[q] = bg[q] ? 0 : 255; if (!bg[q]) cuenta++; }
    var b2 = desenfocar(a, W, H, Math.max(1, Math.round(W / 640))), alfa = new Uint8ClampedArray(N);
    for (var m = 0; m < N; m++) { var t = (b2[m] - 90) / 85; t = t < 0 ? 0 : t > 1 ? 1 : t; alfa[m] = t * t * (3 - 2 * t) * 255; }
    return { alfa: alfa, fraccion: cuenta / N };
  }
  function sujeto(mej, mk) {
    var W = mej.width, H = mej.height, c = document.createElement('canvas'); c.width = W; c.height = H; var x = c.getContext('2d');
    if (!mk) { x.putImageData(mej, 0, 0); return { canvas: c, bbox: { x: 0, y: 0, w: W, h: H }, recortado: false }; }
    var d = new ImageData(new Uint8ClampedArray(mej.data), W, H), p = d.data, x0 = W, y0 = H, x1 = 0, y1 = 0;
    for (var yy = 0; yy < H; yy++) for (var xx = 0; xx < W; xx++) { var i = yy * W + xx; p[i * 4 + 3] = mk.alfa[i]; if (mk.alfa[i] > 128) { if (xx < x0) x0 = xx; if (xx > x1) x1 = xx; if (yy < y0) y0 = yy; if (yy > y1) y1 = yy; } }
    x.putImageData(d, 0, 0);
    if (x1 < x0) return { canvas: c, bbox: { x: 0, y: 0, w: W, h: H }, recortado: true };
    return { canvas: c, bbox: { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }, recortado: true };
  }

  /* ---------- Componer la foto final (vista previa o foto final, con la misma lógica) ---------- */
  function medidas(e, W0, H0, lado) {
    if (e.formato === '1:1') return [lado, lado];
    if (e.formato === '4:5') return [Math.round(lado * .8), lado];
    var k = lado / Math.max(W0, H0); return [Math.round(W0 * k), Math.round(H0 * k)];
  }
  function componer(e, src, lado, cache) {
    var dim = medidas(e, src.width, src.height, lado), W = dim[0], H = dim[1];
    var out = document.createElement('canvas'); out.width = W; out.height = H; var x = out.getContext('2d');
    var base = cache.base && cache.claveBase === claveLuz(e) ? cache.base : (cache.base = mejorar(src, e), cache.claveBase = claveLuz(e), cache.base);
    var conFondo = e.fondo !== 'original';
    var mk = null;
    if (conFondo) { if (!cache.mask || cache.tol !== e.tol) { cache.mask = mascara(src, e.tol); cache.tol = e.tol; cache.suj = null; } mk = cache.mask; }
    if (!cache.suj || cache.sujBase !== cache.base || cache.sujMask !== mk) { cache.suj = sujeto(base, mk); cache.sujBase = cache.base; cache.sujMask = mk; }
    var s = cache.suj;
    if (conFondo) {
      var f = FONDOS.filter(function (z) { return z[0] === e.fondo; })[0];
      if (typeof f[2] === 'function') f[2](x, W, H); else { x.fillStyle = f[2]; x.fillRect(0, 0, W, H); }
      var area = Math.min(W, H) * .82, esc = Math.min(area / s.bbox.w, (H * .82) / s.bbox.h) * e.zoom;
      var w = s.bbox.w * esc, h = s.bbox.h * esc, px = (W - w) / 2 + e.dx * W, py = (H - h) / 2 + e.dy * H;
      x.save(); if (e.sombra) { x.shadowColor = 'rgba(0,0,0,.26)'; x.shadowBlur = W * .035; x.shadowOffsetY = W * .016; }
      x.drawImage(s.canvas, s.bbox.x, s.bbox.y, s.bbox.w, s.bbox.h, px, py, w, h); x.restore();
    } else {
      x.fillStyle = '#fff'; x.fillRect(0, 0, W, H);
      var c = Math.max(W / s.canvas.width, H / s.canvas.height) * e.zoom, cw = s.canvas.width * c, ch = s.canvas.height * c;
      var mx = Math.max(0, (cw - W) / 2), my = Math.max(0, (ch - H) / 2);
      var ox = Math.max(-mx, Math.min(mx, e.dx * W)), oy = Math.max(-my, Math.min(my, e.dy * H));
      x.drawImage(s.canvas, (W - cw) / 2 + ox, (H - ch) / 2 + oy, cw, ch);
    }
    return out;
  }
  function claveLuz(e) { return [e.auto, e.brillo, e.contraste, e.color].join('|'); }

  /* ---------- Interfaz ---------- */
  var CSS = '.vle{position:fixed;inset:0;z-index:300;background:#f4ecdb;color:#22104f;display:flex;flex-direction:column;font-family:"Instrument Sans",system-ui,sans-serif}'
    + '.vle *{box-sizing:border-box}.vle button{font:inherit;color:inherit;cursor:pointer;border:0;background:none}'
    + '.vle-cab{display:grid;grid-template-columns:44px 1fr auto;gap:10px;align-items:center;padding:calc(10px + env(safe-area-inset-top)) 14px 8px}'
    + '.vle-cab h2{font-family:"Bricolage Grotesque",sans-serif;font-size:20px;margin:0}'
    + '.vle-x{width:44px;height:44px;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:inset 0 3px 0 #fff,0 4px 0 rgb(60 30 100 / .14)}'
    + '.vle-x svg{width:18px;height:18px}'
    + '.vle-ad{display:flex;gap:4px;background:#fff;border-radius:999px;padding:4px;box-shadow:0 3px 0 rgb(60 30 100 / .1)}'
    + '.vle-ad button{min-height:36px;padding:0 12px;border-radius:999px;font-size:13px;font-weight:700}'
    + '.vle-ad button[aria-pressed=true]{background:linear-gradient(160deg,#d6f1ff,#94d5fa);color:#0b2a40}'
    + '.vle-lienzo{flex:1 1 0;min-height:140px;display:flex;align-items:center;justify-content:center;padding:6px 16px;overflow:hidden;touch-action:none}'
    + '.vle-lienzo canvas{max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain;border-radius:18px;box-shadow:0 18px 30px -16px rgb(50 24 90 / .5);background:#fff;cursor:grab}'
    + '.vle-panel{flex:0 0 auto;background:#fffdf8;border-radius:26px 26px 0 0;padding:12px 16px calc(14px + env(safe-area-inset-bottom));box-shadow:0 -10px 30px -16px rgb(50 24 90 / .35);max-height:56vh;overflow:auto}'
    + '.vle-magia{width:100%;min-height:52px;border-radius:999px;font-weight:800;font-size:16px;color:#fff !important;display:flex;align-items:center;justify-content:center;gap:8px;'
    + 'background:linear-gradient(90deg,#7a2ff2,#e0179f 60%,#ff8a1a) !important;box-shadow:inset 0 3px 0 rgb(255 255 255 / .3),0 6px 0 #45109a}'
    + '.vle-magia:active{transform:translateY(4px);box-shadow:0 2px 0 #45109a}.vle-magia svg{width:20px;height:20px}'
    + '.vle-tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:12px;background:#f1eaf8;border-radius:16px;padding:4px}'
    + '.vle-tabs button{min-height:40px;border-radius:12px;font-weight:800;font-size:14px}'
    + '.vle-tabs button[aria-selected=true]{background:#fff;box-shadow:0 3px 0 rgb(60 30 100 / .12)}'
    + '.vle-sec{margin-top:12px;display:grid;gap:10px}'
    + '.vle-rango{display:grid;grid-template-columns:96px 1fr 44px;gap:10px;align-items:center;font-size:14px;font-weight:700}'
    + '.vle-rango input{width:100%;accent-color:#6a1fd0;min-height:32px}.vle-rango output{text-align:right;font-variant-numeric:tabular-nums;color:#5c5470}'
    + '.vle-chips{display:flex;gap:8px;overflow-x:auto;padding:2px 2px 8px;scrollbar-width:none}.vle-chips::-webkit-scrollbar{display:none}'
    + '.vle-fondo{flex:0 0 auto;display:grid;justify-items:center;gap:4px;font-size:12px;font-weight:700;min-width:58px}'
    + '.vle-fondo i{width:46px;height:46px;border-radius:14px;display:block;box-shadow:inset 0 0 0 1px rgb(34 16 79 / .12),0 3px 0 rgb(60 30 100 / .12)}'
    + '.vle-fondo[aria-pressed=true] i{box-shadow:0 0 0 3px #fff,0 0 0 6px #e0179f}'
    + '.vle-fmt{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}'
    + '.vle-fmt button,.vle-mini{min-height:44px;border-radius:14px;background:#fff;font-weight:700;font-size:14px;box-shadow:inset 0 3px 0 #fff,0 4px 0 rgb(60 30 100 / .12)}'
    + '.vle-fmt button[aria-pressed=true]{background:linear-gradient(160deg,#d6f1ff,#94d5fa);color:#0b2a40;box-shadow:0 4px 0 #4b9fd4}'
    + '.vle-sw{display:flex;align-items:center;justify-content:space-between;gap:10px;font-size:14px;font-weight:700;min-height:44px}'
    + '.vle-sw input{width:22px;height:22px;accent-color:#6a1fd0}'
    + '.vle-nota{font-size:13px;color:#5c5470;margin:0}.vle-nota.aviso{color:#9a3412;font-weight:700}'
    + '.vle-pie{display:grid;grid-template-columns:auto 1fr;gap:10px;margin-top:14px}'
    + '.vle-usar{min-height:54px;border-radius:999px;font-weight:800;font-size:17px;background:linear-gradient(160deg,#d6f1ff,#94d5fa) !important;color:#0b2a40 !important;box-shadow:inset 0 3px 0 rgb(255 255 255 / .5),0 6px 0 #4b9fd4}'
    + '.vle-usar:active{transform:translateY(4px);box-shadow:0 2px 0 #4b9fd4}.vle-usar[disabled]{opacity:.6}'
    + '.vle-reset{min-height:54px;padding:0 16px;border-radius:999px;font-weight:700;font-size:14px;background:#fff !important;box-shadow:0 4px 0 rgb(60 30 100 / .12)}'
    + '.vle-cargando{position:absolute;inset:0;display:grid;place-items:center;background:rgb(244 236 219 / .75);font-weight:800}';
  function ponerCss() { if (document.getElementById('vle-css')) return; var s = document.createElement('style'); s.id = 'vle-css'; s.textContent = CSS; document.head.appendChild(s); }
  function el(tag, a, hijos) { var e = document.createElement(tag); Object.keys(a || {}).forEach(function (k) { if (k === 'class') e.className = a[k]; else if (k === 'text') e.textContent = a[k]; else if (k === 'html') e.innerHTML = a[k]; else if (k.slice(0, 2) === 'on') e.addEventListener(k.slice(2), a[k]); else e.setAttribute(k, a[k]); }); (hijos || []).forEach(function (h) { if (h) e.appendChild(typeof h === 'string' ? document.createTextNode(h) : h); }); return e; }
  var IC_MAGIA = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8zM19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/></svg>';

  function cargarImagen(fuente) {
    return new Promise(function (ok, no) {
      var im = new Image(), url = typeof fuente === 'string' ? fuente : URL.createObjectURL(fuente);
      if (typeof fuente === 'string') im.crossOrigin = 'anonymous';
      im.onload = function () { if (typeof fuente !== 'string') URL.revokeObjectURL(url); ok(im); };
      im.onerror = function () { if (typeof fuente !== 'string') URL.revokeObjectURL(url); no(new Error('No pudimos abrir la foto para editarla.')); };
      im.src = url;
    });
  }
  function datosDe(im, lado) {
    var k = Math.min(1, lado / Math.max(im.naturalWidth, im.naturalHeight)), W = Math.max(1, Math.round(im.naturalWidth * k)), H = Math.max(1, Math.round(im.naturalHeight * k));
    var c = document.createElement('canvas'); c.width = W; c.height = H; var x = c.getContext('2d', { willReadFrequently: true });
    x.fillStyle = '#fff'; x.fillRect(0, 0, W, H); x.drawImage(im, 0, 0, W, H); return x.getImageData(0, 0, W, H);
  }

  function abrir(fuente) {
    ponerCss();
    return cargarImagen(fuente).then(function (im) {
      var srcPrev = datosDe(im, PREV), srcFull = null, cachePrev = {}, INICIAL = { auto: false, brillo: 0, contraste: 0, color: 100, fondo: 'original', tol: 45, sombra: true, formato: '1:1', zoom: 1, dx: 0, dy: 0 };
      var e = Object.assign({}, INICIAL), verAntes = false, tab = 'mejorar', foco = document.activeElement;
      var raiz = el('div', { class: 'vle', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': 'vle-t' });
      var lienzo = el('div', { class: 'vle-lienzo' }), cv = document.createElement('canvas'); lienzo.appendChild(cv);
      var ad = el('div', { class: 'vle-ad', role: 'group', 'aria-label': 'Comparar' });
      var bAntes = el('button', { type: 'button', 'aria-pressed': 'false', text: 'Antes' }), bDesp = el('button', { type: 'button', 'aria-pressed': 'true', text: 'Después' });
      ad.appendChild(bAntes); ad.appendChild(bDesp);
      var cerrarX = el('button', { type: 'button', class: 'vle-x', 'aria-label': 'Cancelar y cerrar', html: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>' });
      raiz.appendChild(el('div', { class: 'vle-cab' }, [cerrarX, el('h2', { id: 'vle-t', text: 'Editar foto', tabindex: '-1' }), ad]));
      raiz.appendChild(lienzo);
      var panel = el('div', { class: 'vle-panel' }), nota = el('p', { class: 'vle-nota', 'aria-live': 'polite' });
      var magia = el('button', { type: 'button', class: 'vle-magia', html: IC_MAGIA + 'Mejora inteligente (1 toque)' });
      var tabs = el('div', { class: 'vle-tabs', role: 'tablist' }), cont = el('div', { class: 'vle-sec' });
      [['mejorar', 'Luz y color'], ['fondo', 'Fondo'], ['recortar', 'Recortar']].forEach(function (t) {
        tabs.appendChild(el('button', { type: 'button', role: 'tab', 'aria-selected': String(t[0] === tab), 'data-t': t[0], text: t[1], onclick: function () { tab = t[0]; pintarPanel(); } }));
      });
      var usar = el('button', { type: 'button', class: 'vle-usar', text: 'Usar esta foto' }), reset = el('button', { type: 'button', class: 'vle-reset', text: 'Deshacer todo' });
      panel.appendChild(magia); panel.appendChild(tabs); panel.appendChild(cont); panel.appendChild(nota); panel.appendChild(el('div', { class: 'vle-pie' }, [reset, usar]));
      raiz.appendChild(panel); document.body.appendChild(raiz); document.documentElement.style.overflow = 'hidden';
      setTimeout(function () { raiz.querySelector('#vle-t').focus(); }, 50);

      var pendiente = false;
      function pintar() {
        if (pendiente) return; pendiente = true;
        requestAnimationFrame(function () {
          pendiente = false;
          var o = verAntes ? Object.assign({}, INICIAL, { formato: e.formato, zoom: e.zoom, dx: e.dx, dy: e.dy }) : e;
          var c = componer(o, srcPrev, PREV, verAntes ? {} : cachePrev);
          cv.width = c.width; cv.height = c.height; cv.getContext('2d').drawImage(c, 0, 0);
          if (!verAntes && e.fondo !== 'original' && cachePrev.mask) {
            var fr = cachePrev.mask.fraccion;
            nota.className = 'vle-nota' + (fr < .04 || fr > .95 ? ' aviso' : '');
            nota.textContent = fr < .04 || fr > .95 ? 'No encontramos bien el producto. Sube o baja "Ajuste del recorte", o toma la foto sobre una pared o mesa lisa.' : 'Funciona mejor con fondo liso. Si se corta el producto, mueve "Ajuste del recorte".';
          } else if (!verAntes) { nota.className = 'vle-nota'; nota.textContent = ''; }
        });
      }
      function rango(id, txt, min, max, paso, clave, suf) {
        var inp = el('input', { type: 'range', id: id, min: String(min), max: String(max), step: String(paso), value: String(e[clave]) }), out = el('output', { for: id, text: String(e[clave]) + (suf || '') });
        inp.addEventListener('input', function () { e[clave] = +inp.value; out.textContent = inp.value + (suf || ''); pintar(); });
        return el('label', { class: 'vle-rango', for: id }, [el('span', { text: txt }), inp, out]);
      }
      function pintarPanel() {
        [].slice.call(tabs.children).forEach(function (b) { b.setAttribute('aria-selected', String(b.dataset.t === tab)); });
        cont.textContent = '';
        if (tab === 'mejorar') {
          var auto = el('input', { type: 'checkbox' }); auto.checked = e.auto; auto.addEventListener('change', function () { e.auto = auto.checked; pintar(); });
          cont.appendChild(el('label', { class: 'vle-sw' }, ['Luz automática', auto]));
          cont.appendChild(rango('vle-br', 'Brillo', -50, 50, 1, 'brillo'));
          cont.appendChild(rango('vle-ct', 'Contraste', -30, 50, 1, 'contraste'));
          cont.appendChild(rango('vle-co', 'Color', 50, 160, 1, 'color', '%'));
        } else if (tab === 'fondo') {
          var ch = el('div', { class: 'vle-chips', role: 'group', 'aria-label': 'Fondo' });
          FONDOS.forEach(function (f) {
            ch.appendChild(el('button', { type: 'button', class: 'vle-fondo', 'aria-pressed': String(e.fondo === f[0]), onclick: function () { e.fondo = f[0]; if (f[0] !== 'original') { e.zoom = 1; e.dx = 0; e.dy = 0; } pintarPanel(); pintar(); } },
              [el('i', { style: 'background:' + (f[0] === 'original' ? 'repeating-linear-gradient(45deg,#e9e3f3 0 6px,#fff 6px 12px)' : f[3]) }), f[1]]));
          });
          cont.appendChild(ch);
          if (e.fondo !== 'original') {
            cont.appendChild(rango('vle-tol', 'Ajuste del recorte', 15, 120, 1, 'tol'));
            var so = el('input', { type: 'checkbox' }); so.checked = e.sombra; so.addEventListener('change', function () { e.sombra = so.checked; pintar(); });
            cont.appendChild(el('label', { class: 'vle-sw' }, ['Sombra suave debajo del producto', so]));
          } else cont.appendChild(el('p', { class: 'vle-nota', text: 'Elige Blanco u otro fondo: recortamos tu producto y lo ponemos encima.' }));
        } else {
          var fm = el('div', { class: 'vle-fmt', role: 'group', 'aria-label': 'Formato' });
          FORMATOS.forEach(function (f) { fm.appendChild(el('button', { type: 'button', 'aria-pressed': String(e.formato === f[0]), text: f[1], onclick: function () { e.formato = f[0]; e.dx = 0; e.dy = 0; pintarPanel(); pintar(); } })); });
          cont.appendChild(fm);
          cont.appendChild(rango('vle-zoom', 'Acercar', 1, 3, 0.05, 'zoom', '×'));
          cont.appendChild(el('button', { type: 'button', class: 'vle-mini', text: 'Centrar', onclick: function () { e.dx = 0; e.dy = 0; pintar(); } }));
          cont.appendChild(el('p', { class: 'vle-nota', text: 'Arrastra la foto con el dedo para elegir qué parte se ve.' }));
        }
      }
      /* Mejora inteligente: luz automática + busca el mejor recorte para fondo blanco + foto cuadrada centrada */
      magia.addEventListener('click', function () {
        e = Object.assign({}, INICIAL, { auto: true, contraste: 6, color: 108, formato: '1:1' });
        var mejor = null; [30, 45, 65, 90].forEach(function (t) { var m = mascara(srcPrev, t); if (m.fraccion >= .06 && m.fraccion <= .9) { var d = Math.abs(m.fraccion - .3); if (!mejor || d < mejor.d) mejor = { t: t, d: d, m: m }; } });
        if (mejor) { e.fondo = 'blanco'; e.tol = mejor.t; cachePrev.mask = mejor.m; cachePrev.tol = mejor.t; cachePrev.suj = null; }
        tab = mejor ? 'fondo' : 'mejorar'; pintarPanel(); pintar();
        setTimeout(function () { nota.className = 'vle-nota'; nota.textContent = mejor ? 'Listo: más luz y fondo blanco. Puedes cambiar el fondo o ajustar el recorte.' : 'Mejoramos la luz. No encontramos un fondo liso: prueba con una pared o mesa lisa para el fondo blanco.'; }, 60);
      });
      bAntes.addEventListener('click', function () { verAntes = true; bAntes.setAttribute('aria-pressed', 'true'); bDesp.setAttribute('aria-pressed', 'false'); pintar(); });
      bDesp.addEventListener('click', function () { verAntes = false; bAntes.setAttribute('aria-pressed', 'false'); bDesp.setAttribute('aria-pressed', 'true'); pintar(); });
      reset.addEventListener('click', function () { e = Object.assign({}, INICIAL); tab = 'mejorar'; pintarPanel(); pintar(); });

      /* Mover la foto con el dedo (recortar / ubicar el producto) */
      var arrastre = null;
      cv.addEventListener('pointerdown', function (ev) { arrastre = { x: ev.clientX, y: ev.clientY, dx: e.dx, dy: e.dy }; cv.setPointerCapture(ev.pointerId); });
      cv.addEventListener('pointermove', function (ev) { if (!arrastre) return; var r = cv.getBoundingClientRect(); e.dx = arrastre.dx + (ev.clientX - arrastre.x) / r.width; e.dy = arrastre.dy + (ev.clientY - arrastre.y) / r.height; e.dx = Math.max(-1, Math.min(1, e.dx)); e.dy = Math.max(-1, Math.min(1, e.dy)); pintar(); });
      cv.addEventListener('pointerup', function () { arrastre = null; }); cv.addEventListener('pointercancel', function () { arrastre = null; });

      pintarPanel(); pintar();
      return new Promise(function (resolver) {
        function cerrar(valor) { document.removeEventListener('keydown', tecla); raiz.remove(); document.documentElement.style.overflow = ''; if (foco && foco.focus) try { foco.focus(); } catch (x) { /* ok */ } resolver(valor); }
        function tecla(ev) { if (ev.key === 'Escape') cerrar(null); }
        document.addEventListener('keydown', tecla);
        cerrarX.addEventListener('click', function () { cerrar(null); });
        usar.addEventListener('click', function () {
          usar.disabled = true; usar.textContent = 'Preparando…';
          setTimeout(function () {
            try {
              srcFull = srcFull || datosDe(im, FULL);
              var cacheFull = {};
              var final = componer(e, srcFull, FULL, cacheFull);
              final.toBlob(function (b) {
                if (b && b.type === 'image/webp') { cerrar({ blob: b, ext: 'webp', tipo: 'image/webp', url: URL.createObjectURL(b) }); return; }
                final.toBlob(function (j) { if (j) cerrar({ blob: j, ext: 'jpg', tipo: 'image/jpeg', url: URL.createObjectURL(j) }); else { usar.disabled = false; usar.textContent = 'Usar esta foto'; nota.textContent = 'No pudimos preparar la foto. Intenta de nuevo.'; } }, 'image/jpeg', 0.88);
              }, 'image/webp', 0.86);
            } catch (x) { usar.disabled = false; usar.textContent = 'Usar esta foto'; nota.className = 'vle-nota aviso'; nota.textContent = 'No pudimos preparar la foto. Intenta de nuevo.'; }
          }, 30);
        });
      });
    });
  }

  window.VLEditor = { abrir: abrir, _componer: componer, _mascara: mascara };
})();
