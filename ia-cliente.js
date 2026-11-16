/* Cliente de la IA de Ventas Link (navegador). Habla SOLO con /api/ia del servidor propio.
   Aquí nunca hay llaves: la llave vive en el servidor (servidor/.env). */
(function () {
  'use strict';
  var DEMO = 'La IA se activa cuando la app está publicada con tu llave. En esta demostración todavía no está conectada.';
  function pedir(tipo, datos, plan) {
    if (location.protocol === 'file:') return Promise.resolve({ ok: false, motivo: 'demo', mensaje: DEMO });
    var ctl = new AbortController(), t = setTimeout(function () { ctl.abort(); }, 45000);
    return fetch('/api/ia', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ tipo: tipo, datos: datos, plan: plan || 'gratis' }), signal: ctl.signal })
      .then(function (r) { return r.json().then(function (j) { return { r: r, j: j }; }); })
      .then(function (x) {
        if (x.r.ok && x.j.texto) return { ok: true, texto: x.j.texto };
        return { ok: false, motivo: x.j.error || 'servicio', mensaje: x.j.mensaje || 'No pudimos escribir el texto. Intenta de nuevo.' };
      })
      .catch(function () { return { ok: false, motivo: 'red', mensaje: 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.' }; })
      .then(function (res) { clearTimeout(t); return res; });
  }
  /* Los botones de IA están ocultos y solo aparecen si el servidor tiene una llave conectada. */
  function mostrarSiHayIA() {
    if (location.protocol === 'file:') return;
    fetch('/api/estado').then(function (r) { return r.json(); }).then(function (j) {
      if (j && j.ia) [].slice.call(document.querySelectorAll('.ia-fila')).forEach(function (e) { e.classList.add('on'); }); [].slice.call(document.querySelectorAll('.sug-fila')).forEach(function (e) { e.classList.add('oculto'); });
    }).catch(function () { /* sin servidor: los botones siguen ocultos */ });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mostrarSiHayIA); else mostrarSiHayIA();
  window.VL_IA = { pedir: pedir };
})();
