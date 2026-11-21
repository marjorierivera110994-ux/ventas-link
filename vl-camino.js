/* Ventas Link — piezas compartidas de "Mi camino al éxito":
   VLC.celebrar(nuevos)  → felicitación en pantalla (venta, reto, meta, nivel o medalla) y los marca como vistos en el servidor.
   VLC.compartirTienda(t) → comparte el enlace real de la tienda y lo registra (cuenta para los retos de compartir).
   Los puntos NO se calculan aquí: todo lo decide el servidor con hechos comprobables. */
(function () {
  'use strict';
  var ICONOS = {
    venta: '<path d="M6 7h12l-1 13H7zM9 7a3 3 0 0 1 6 0"/><path d="M9.5 13.5l2 2 3.5-4"/>',
    reto: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.6 2.6L16 9.5"/>',
    meta: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/>',
    nivel: '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0zM7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3"/>',
    medalla: '<circle cx="12" cy="14" r="6"/><path d="M8.5 9L6 3h4l2 4 2-4h4l-2.5 6"/><path d="M12 11.5l.9 1.8 2 .3-1.45 1.4.35 2-1.8-.95-1.8.95.35-2-1.45-1.4 2-.3z"/>'
  };
  function icono(tipo, tam) { return '<svg viewBox="0 0 24 24" width="' + (tam || 24) + '" height="' + (tam || 24) + '" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (ICONOS[tipo] || ICONOS.reto) + '</svg>'; }

  var CSS = '.vlc-fondo{position:fixed;inset:0;z-index:200;display:grid;place-items:center;padding:16px;background:rgb(34 16 79 / .55);animation:vlcIn .25s ease both}'
    + '.vlc-tarj{position:relative;width:min(100%,400px);border-radius:28px;padding:28px 18px 18px;text-align:center;color:#22104f;overflow:hidden;'
    + 'background:radial-gradient(420px 220px at 50% -10%,#f3e8ff,transparent 70%),#fffdf8;box-shadow:0 10px 0 rgb(60 30 100 / .18),0 40px 60px -20px rgb(0 0 0 / .55);animation:vlcPop .5s cubic-bezier(.34,1.56,.64,1) both}'
    + '.vlc-medalla{width:96px;height:96px;margin:0 auto;border-radius:50%;display:grid;place-items:center;color:#fff;background:conic-gradient(from 210deg,#7a2ff2,#e0179f,#ff8a1a,#ffc83d,#7a2ff2);'
    + 'box-shadow:inset 0 0 0 7px rgb(255 255 255 / .85),inset 0 -6px 0 7px rgb(0 0 0 / .08),0 8px 0 #45109a,0 22px 26px -10px rgb(69 16 154 / .6);animation:vlcGira 1s cubic-bezier(.34,1.56,.64,1) .1s both}'
    + '.vlc-medalla svg{filter:drop-shadow(0 2px 0 rgb(0 0 0 / .25))}'
    + '.vlc-tarj h2{font-family:"Bricolage Grotesque",monospace;font-size:26px;line-height:1.1;margin-top:18px;letter-spacing:-.02em}'
    + '.vlc-tarj p{font-size:15px;color:#5c5470;margin-top:8px}'
    + '.vlc-pts{display:inline-flex;align-items:center;gap:6px;margin-top:14px;padding:8px 16px;border-radius:999px;font-family:"Bricolage Grotesque",monospace;font-weight:800;font-size:20px;color:#fff;background:linear-gradient(90deg,#7a2ff2,#e0179f 55%,#ff8a1a);box-shadow:0 5px 0 #45109a}'
    + '.vlc-lista{list-style:none;display:grid;gap:8px;margin-top:16px;text-align:left}'
    + '.vlc-lista li{display:grid;grid-template-columns:32px minmax(0,1fr) auto;gap:10px;align-items:center;background:#f6f1fb;border-radius:14px;padding:8px 10px;font-size:14px;font-weight:700}'
    + '.vlc-lista li span{width:32px;height:32px;border-radius:10px;display:grid;place-items:center;color:#fff;background:linear-gradient(160deg,#b98cff,#6a1fd0)}'
    + '.vlc-lista li em{font-style:normal;font-family:"Bricolage Grotesque",monospace;color:#6a1fd0}'
    + '.vlc-acc{display:grid;gap:10px;margin-top:18px}'
    + '.vlc-btn{min-height:54px;border-radius:999px;font-weight:800;font-size:17px;border:0;cursor:pointer;background:linear-gradient(160deg,#d6f1ff,#94d5fa);color:#0b2a40;box-shadow:inset 0 3px 0 rgb(255 255 255 / .5),0 6px 0 #4b9fd4}'
    + '.vlc-btn:active{transform:translateY(4px);box-shadow:0 2px 0 #4b9fd4}'
    + '.vlc-link{min-height:44px;font-weight:700;font-size:14px;text-decoration:underline;background:none;border:0;cursor:pointer;color:#22104f}'
    + '.vlc-confeti{position:absolute;inset:0;pointer-events:none;overflow:hidden}'
    + '.vlc-confeti i{position:absolute;top:-12px;width:9px;height:14px;border-radius:2px;opacity:0;animation:vlcCae 2.4s ease-in forwards}'
    + '@keyframes vlcIn{from{opacity:0}}@keyframes vlcPop{from{transform:scale(.8) translateY(20px);opacity:0}}'
    + '@keyframes vlcGira{from{transform:rotate(-200deg) scale(.4);opacity:0}}'
    + '@keyframes vlcCae{0%{opacity:1;transform:translateY(0) rotate(0)}100%{opacity:0;transform:translateY(520px) rotate(540deg)}}'
    + '@media (prefers-reduced-motion:reduce){.vlc-fondo,.vlc-tarj,.vlc-medalla,.vlc-confeti i{animation:none!important}.vlc-confeti{display:none}}';

  function ponerCss() { if (document.getElementById('vlc-css')) return; var s = document.createElement('style'); s.id = 'vlc-css'; s.textContent = CSS; document.head.appendChild(s); }
  function esc(t) { var d = document.createElement('div'); d.textContent = String(t == null ? '' : t); return d.innerHTML; }

  /* Elige el mensaje principal (lo más importante primero) con las frases pedidas. */
  function mensaje(nuevos) {
    var de = function (tipo, cod) { for (var i = 0; i < nuevos.length; i++) if (nuevos[i].tipo === tipo && (!cod || nuevos[i].codigo === cod)) return nuevos[i]; return null; };
    var primera = nuevos.some(function (x) { return x.codigo === 'primera_venta'; });
    var n;
    if (primera) return { tipo: 'venta', t: '¡Lo lograste!', p: 'Ya tienes tu primera venta. ¡Este es el comienzo de grandes cosas!' };
    if (de('venta', 'venta')) return { tipo: 'venta', t: '¡Felicidades!', p: 'Has realizado una nueva venta. Cada paso te acerca más a tus sueños. ¡Sigue creciendo con Ventas Link!' };
    if ((n = de('nivel'))) return { tipo: 'nivel', t: '¡Felicidades! Subiste de nivel', p: 'Ahora eres ' + n.titulo + '. Sigue construyendo tu camino al éxito.' };
    if (de('meta')) return { tipo: 'meta', t: '¡Meta cumplida!', p: 'Alcanzaste tu meta de ventas de la semana. ¡Excelente trabajo!' };
    if ((n = de('medalla'))) return { tipo: 'medalla', t: '¡Nueva medalla!', p: n.titulo + '. Cada logro cuenta en tu camino al éxito.' };
    n = de('reto');
    return { tipo: 'reto', t: '¡Excelente trabajo!', p: n ? 'Completaste: ' + n.titulo + '.' : 'Sigues avanzando en tu camino al éxito.' };
  }

  /* Muestra la felicitación. nuevos = [{id, tipo, codigo, titulo, puntos}] tal como los devuelve el servidor. */
  function celebrar(nuevos, op) {
    op = op || {};
    var lista = (nuevos || []).filter(function (x) { return x && x.codigo !== 'anulada'; });
    if (!lista.length) return Promise.resolve(false);
    ponerCss();
    var m = mensaje(lista), pts = lista.reduce(function (s, x) { return s + (x.puntos || 0); }, 0);
    var foco = document.activeElement;
    var fondo = document.createElement('div'); fondo.className = 'vlc-fondo';
    var colores = ['#7a2ff2', '#e0179f', '#ff8a1a', '#ffc83d', '#94d5fa'], conf = '';
    for (var i = 0; i < 26; i++) conf += '<i style="left:' + Math.round(Math.random() * 100) + '%;background:' + colores[i % 5] + ';animation-delay:' + (Math.random() * .6).toFixed(2) + 's"></i>';
    var items = lista.length > 1 ? '<ul class="vlc-lista">' + lista.slice(0, 5).map(function (x) {
      return '<li><span>' + icono(x.tipo, 18) + '</span>' + esc(x.titulo) + '<em>' + (x.puntos ? '+' + x.puntos : '') + '</em></li>';
    }).join('') + '</ul>' : '';
    fondo.innerHTML = '<div class="vlc-tarj" role="dialog" aria-modal="true" aria-labelledby="vlc-t"><div class="vlc-confeti">' + conf + '</div>'
      + '<div class="vlc-medalla">' + icono(m.tipo, 44) + '</div><h2 id="vlc-t" tabindex="-1">' + esc(m.t) + '</h2><p>' + esc(m.p) + '</p>'
      + (pts > 0 ? '<div class="vlc-pts">+' + pts + ' puntos</div>' : '') + items
      + '<div class="vlc-acc"><button type="button" class="vlc-btn" data-a="ok">¡Sigue así!</button>'
      + (op.verCamino ? '<button type="button" class="vlc-link" data-a="ver">Ver mi camino al éxito</button>' : '') + '</div></div>';
    document.body.appendChild(fondo);
    try { navigator.vibrate && navigator.vibrate([20, 40, 30]); } catch (e) { /* sin vibración */ }
    var t = fondo.querySelector('#vlc-t'); setTimeout(function () { t.focus(); }, 60);
    marcarVistos(lista);
    return new Promise(function (resolver) {
      function cerrar(accion) {
        document.removeEventListener('keydown', tecla);
        fondo.remove(); if (foco && foco.focus) try { foco.focus(); } catch (e) { /* ok */ }
        if (accion === 'ver' && typeof op.verCamino === 'function') op.verCamino();
        resolver(true);
      }
      function tecla(e) { if (e.key === 'Escape') cerrar('ok'); }
      document.addEventListener('keydown', tecla);
      fondo.addEventListener('click', function (e) { var b = e.target.closest('[data-a]'); if (b) cerrar(b.dataset.a); else if (e.target === fondo) cerrar('ok'); });
    });
  }

  function marcarVistos(lista) {
    var VL = window.VL; if (!VL || !VL.listo || !VL.cliente) return;
    var ids = lista.map(function (x) { return x.id; }).filter(Boolean);
    if (ids.length) VL.cliente().rpc('camino_visto', { p_ids: ids }).then(function () { /* listo */ }, function () { /* se reintentará al volver */ });
  }

  /* Comparte el enlace real de la tienda (o abre WhatsApp si el celular no tiene "compartir") y lo registra. */
  function compartirTienda(t) {
    var VL = window.VL; if (!t || !t.slug || !VL) return Promise.resolve('sin_tienda');
    var url = VL.enlaceTienda(t.slug), texto = '¡Hola! Mira mi tienda ' + (t.nombre || '') + ' y haz tu pedido aquí: ' + url;
    var hecho = function (como) {
      if (VL.listo && VL.cliente) VL.cliente().rpc('registrar_evento', { p_tipo: 'tienda_compartida', p_anon: null, p_props: { como: como } }).then(function () { /* ok */ }, function () { /* ok */ });
      return como;
    };
    if (navigator.share) {
      return navigator.share({ title: t.nombre || 'Mi tienda', text: texto, url: url }).then(function () { return hecho('compartido'); },
        function (e) { return e && e.name === 'AbortError' ? 'cancelado' : (window.open('https://wa.me/?text=' + encodeURIComponent(texto), '_blank', 'noopener'), hecho('whatsapp')); });
    }
    window.open('https://wa.me/?text=' + encodeURIComponent(texto), '_blank', 'noopener');
    return Promise.resolve(hecho('whatsapp'));
  }

  window.VLC = { celebrar: celebrar, compartirTienda: compartirTienda, icono: icono };
})();
