/* Ventas Link — Diseño de la tienda (plantillas, colores, decoración, logo y portada).
   VLD.estiloEfectivo(estilo, plan) → lo que el plan SÍ permite (la tienda pública lo aplica siempre).
   VLD.css(estilo, plan) → texto CSS que pinta la tienda con ese diseño (colores, fuentes, fondo, botones, logo).
   Los datos de plantillas y paletas son los mismos que usa personalizar-demo.html (pantalla del vendedor). */
(function () {
  'use strict';
  var PALETAS = [
    { id: 'pistacho', n: 'Pistacho', brand: '#a5dc5b', bg: '#f4ecdb' },
    { id: 'naranja', n: 'Naranja', brand: '#ff7a1a', bg: '#fff3e6' },
    { id: 'oceano', n: 'Océano', brand: '#3aa6c8', bg: '#eaf6fb' },
    { id: 'ciruela', n: 'Ciruela', brand: '#9b6bdc', bg: '#f4eefb' },
    { id: 'rosa', n: 'Rosa', brand: '#f06292', bg: '#fff0f5' }
  ];
  var DISENOS = [
    { n: 'Mercado', fd: "'Bricolage Grotesque'", fb: "'Instrument Sans'", r: 22, deco: 'puntos' },
    { n: 'Boutique', fd: "'Fraunces'", fb: "'Instrument Sans'", r: 8, deco: 'ninguna' },
    { n: 'Fresco', fd: "'Nunito'", fb: "'Nunito'", r: 28, deco: 'burbujas' },
    { n: 'Moderno', fd: "'Figtree'", fb: "'Figtree'", r: 14, deco: 'rayas' },
    { n: 'Artesanal', fd: "'Fraunces'", fb: "'Nunito'", r: 12, deco: 'ondas' },
    { n: 'Minimal', fd: "'Instrument Sans'", fb: "'Instrument Sans'", r: 4, deco: 'ninguna' },
    { n: 'Alegre', fd: "'Nunito'", fb: "'Nunito'", r: 30, deco: 'confeti' },
    { n: 'Elegante', fd: "'Fraunces'", fb: "'Figtree'", r: 2, deco: 'ninguna', oscuro: true },
    { n: 'Nocturna', fd: "'Figtree'", fb: "'Figtree'", r: 18, deco: 'puntos', oscuro: true },
    { n: 'Vitrina', fd: "'Bricolage Grotesque'", fb: "'Instrument Sans'", r: 0, deco: 'rayas' }
  ];
  var DECOS_EMP = ['ninguna', 'puntos', 'rayas'];
  var COLORES_BASICOS = ['#a5dc5b', '#ff7a1a', '#3aa6c8', '#9b6bdc', '#f06292', '#e6ee4a', '#f2b705', '#2f9e6b'];
  var METALES = {
    oro: { n: 'Oro', stops: ['#f3dc87', '#d4af37', '#b8912a'], on: '#131313', base: '#d4af37' },
    plata: { n: 'Plata', stops: ['#f2f3f5', '#c5c9d0', '#9aa0aa'], on: '#131313', base: '#c5c9d0' },
    ororosa: { n: 'Oro rosa', stops: ['#f3c9bb', '#d99a85', '#b87a68'], on: '#131313', base: '#d99a85' },
    champan: { n: 'Champán', stops: ['#f7edd9', '#e0c9a0', '#c4a572'], on: '#131313', base: '#e0c9a0' },
    bronce: { n: 'Bronce', stops: ['#e9b97b', '#d58b3f', '#b8702a'], on: '#131313', base: '#d58b3f' },
    grafito: { n: 'Grafito', stops: ['#6b7078', '#3a3d44', '#1f2125'], on: '#ffffff', base: '#3a3d44' }
  };
  var COMBOS = [
    { id: 'oro-negro', brand: 'metal:oro', bg: '#121212', sur: '#1e1e1e', txt: '#f5efe0', mut: '#b8ad94' },
    { id: 'plata-grafito', brand: 'metal:plata', bg: '#1f2125', sur: '#2a2d33', txt: '#f2f3f5', mut: '#a9afb9' },
    { id: 'vino-champan', brand: '#7a1f3d', bg: '#f7efe2', sur: '#ffffff', txt: '#2a0f18', mut: '#6b5560' },
    { id: 'esmeralda-oro', brand: '#0f5c4a', bg: '#f5f1e6', sur: '#ffffff', txt: '#0d1f1a', mut: '#52645d' },
    { id: 'noche-plata', brand: '#1b2a49', bg: '#eef0f4', sur: '#ffffff', txt: '#0e1424', mut: '#515a6e' },
    { id: 'rosa-oro', brand: 'metal:ororosa', bg: '#fbf1ee', sur: '#ffffff', txt: '#2d1a17', mut: '#715852' },
    { id: 'terracota-arena', brand: '#c98d77', bg: '#f6ece0', sur: '#ffffff', txt: '#2b1a12', mut: '#6c5848' },
    { id: 'salvia-crema', brand: '#9cb59a', bg: '#f4f1e8', sur: '#ffffff', txt: '#1b2419', mut: '#5b6658' }
  ];
  var HEX = /^#[0-9a-f]{6}$/i;

  function plantillasDe(plan) {
    var r = [], d, p;
    if (plan === 'emprendedor') { for (d = 0; d < 10; d++) r.push({ d: d, p: d % 5 }); }
    else if (plan === 'pro') { for (p = 0; p < 5; p++) for (d = 0; d < 10; d++) r.push({ d: d, p: p }); }
    return r;
  }
  function lum(hex) { var c = [1, 3, 5].map(function (i) { return parseInt(hex.slice(i, i + 2), 16) / 255; }).map(function (v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; }
  function contraste(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  function sobre(hex) { return contraste('#131313', hex) >= contraste('#ffffff', hex) ? '#131313' : '#ffffff'; }
  function mezcla(a, b, t) { return '#' + [1, 3, 5].map(function (i) { var x = parseInt(a.slice(i, i + 2), 16), y = parseInt(b.slice(i, i + 2), 16); return ('0' + Math.round(x + (y - x) * t).toString(16)).slice(-2); }).join(''); }
  function relleno(hex) {
    var on = sobre(hex), h = hex, i = 0;
    while (contraste(on, h) < 4.5 && i < 30) { h = mezcla(h, on === '#131313' ? '#ffffff' : '#000000', 0.05); i++; }
    return h;
  }
  function resolverColor(sel) {
    if (sel && sel.indexOf('metal:') === 0) { var m = METALES[sel.slice(6)]; return { fill: m.base, on: m.on, grad: 'linear-gradient(135deg,' + m.stops.join(',') + ')' }; }
    var f = relleno(sel); return { fill: f, on: sobre(f), grad: null };
  }
  function entero(v, max) { var n = parseInt(v, 10); return isNaN(n) ? 0 : Math.max(0, Math.min(max, n)); }

  /* Lo que el plan permite. Gratis = estilo base; Emprendedor = 10 plantillas, 8 colores y 3 decoraciones; Profesional = todo. */
  function estiloEfectivo(estilo, plan) {
    var base = { plantilla: { d: 0, p: 0 }, color: null, deco: null, combo: null };
    var pl = plan === 'profesional' ? 'pro' : plan;
    if (pl !== 'emprendedor' && pl !== 'pro') return base;
    var e = (estilo && typeof estilo === 'object') ? estilo : {};
    var t = e.plantilla || {}, d = entero(t.d, 9), p = entero(t.p, 4);
    if (pl === 'emprendedor') p = d % 5;
    var out = { plantilla: { d: d, p: p }, color: null, deco: null, combo: null };
    if (pl === 'pro' && e.combo && COMBOS.some(function (c) { return c.id === e.combo; })) out.combo = e.combo;
    if (typeof e.color === 'string') {
      if (pl === 'emprendedor' && COLORES_BASICOS.indexOf(e.color) >= 0) out.color = e.color;
      if (pl === 'pro' && (HEX.test(e.color) || (e.color.indexOf('metal:') === 0 && METALES[e.color.slice(6)]))) out.color = e.color;
    }
    if (typeof e.deco === 'string') {
      var decos = pl === 'emprendedor' ? DECOS_EMP : ['ninguna', 'puntos', 'rayas', 'ondas', 'confeti', 'burbujas'];
      if (decos.indexOf(e.deco) >= 0) out.deco = e.deco;
    }
    return out;
  }

  function svgUri(svg) { return 'url("data:image/svg+xml,' + encodeURIComponent(svg) + '")'; }
  function decoCss(tipo, claro) {
    var c = claro ? 'rgba(255,255,255,.28)' : 'rgba(0,0,0,.13)'; var s = claro ? '#ffffff' : '#000000'; var o = claro ? '.26' : '.14';
    if (tipo === 'puntos') return { img: 'radial-gradient(circle, ' + c + ' 2.2px, transparent 2.7px)', size: '16px 16px' };
    if (tipo === 'rayas') return { img: 'repeating-linear-gradient(45deg, ' + c + ' 0 7px, transparent 7px 16px)', size: 'auto' };
    if (tipo === 'ondas') return { img: svgUri('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="20" viewBox="0 0 48 20"><path d="M0 10 Q12 0 24 10 T48 10" fill="none" stroke="' + s + '" stroke-opacity="' + o + '" stroke-width="3"/></svg>'), size: '48px 20px' };
    if (tipo === 'confeti') return { img: svgUri('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80"><g fill="' + s + '" fill-opacity="' + o + '"><circle cx="10" cy="12" r="4"/><rect x="40" y="8" width="9" height="9" rx="2" transform="rotate(25 44 12)"/><circle cx="66" cy="30" r="3"/><rect x="14" y="48" width="9" height="9" rx="2" transform="rotate(-20 18 52)"/><circle cx="48" cy="60" r="4"/><rect x="66" y="64" width="8" height="8" rx="2"/></g></svg>'), size: '80px 80px' };
    if (tipo === 'burbujas') return { img: svgUri('<svg xmlns="http://www.w3.org/2000/svg" width="90" height="70" viewBox="0 0 90 70"><g fill="none" stroke="' + s + '" stroke-opacity="' + o + '" stroke-width="3"><circle cx="16" cy="20" r="10"/><circle cx="60" cy="14" r="6"/><circle cx="72" cy="48" r="12"/><circle cx="30" cy="56" r="5"/></g></svg>'), size: '90px 70px' };
    return { img: 'none', size: 'auto' };
  }

  /* CSS de la tienda pública con el diseño elegido (ya filtrado por plan). Sin diseño = la tienda base. */
  function css(estilo, plan, conPortada) {
    var e = estiloEfectivo(estilo, plan);
    var d = DISENOS[e.plantilla.d], pal = PALETAS[e.plantilla.p];
    var cb = e.combo ? COMBOS.filter(function (c) { return c.id === e.combo; })[0] : null;
    var oscuro = !!d.oscuro;
    var n = cb ? { bg: cb.bg, sur: cb.sur, txt: cb.txt, mut: cb.mut } : { bg: oscuro ? '#131512' : pal.bg, sur: oscuro ? '#1f231e' : '#ffffff', txt: oscuro ? '#f3f1ea' : '#131313', mut: oscuro ? '#a9ad9f' : '#5a5648' };
    var sel = cb ? cb.brand : (e.color || pal.brand);
    var col = resolverColor(sel);
    var fondo = 'none';
    if (!conPortada && e.deco && e.deco !== 'ninguna') { var dc = decoCss(e.deco, col.on === '#ffffff'); if (dc.img !== 'none') fondo = dc.img; }
    var grad = col.grad || col.fill;
    return ':root{--beige:' + n.bg + ';--blanco:' + n.sur + ';--tinta:' + n.txt + ';--texto-2:' + n.mut + ';--pistacho:' + col.fill + ';--lima:' + col.fill + ';--naranja:' + col.fill + ';--verde-texto:' + col.fill + ';--f-d:' + d.fd + ', monospace;--f-b:' + d.fb + ', monospace;--vl-r:' + d.r + 'px}'
      + 'body{background:' + n.bg + ' ' + fondo + ' !important;background-size:' + decoCss(e.deco || 'ninguna', false).size + ' !important}'
      + '.logo{background:' + col.fill + ' !important;color:' + col.on + ' !important}'
      + '.btn{background:' + grad + ' !important;color:' + col.on + ' !important;box-shadow:0 6px 0 ' + mezcla(col.fill, '#000000', 0.28) + ' !important}'
      + '.portada{border-radius:var(--vl-r) !important}';
  }

  window.VLD = { estiloEfectivo: estiloEfectivo, css: css, plantillasDe: plantillasDe, DISENOS: DISENOS, PALETAS: PALETAS, COLORES_BASICOS: COLORES_BASICOS, METALES: METALES, COMBOS: COMBOS, DECOS_EMP: DECOS_EMP };
})();
