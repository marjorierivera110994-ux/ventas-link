/* Ventas Link — datos legales en UN solo lugar (los usan las páginas legales, el recorrido de inicio y la app).
   Si cambias algo importante en Términos o Privacidad: sube "version" (fecha del cambio) y avisa por correo.
   Medición opcional: quien la apaga aquí deja de enviar eventos de uso desde ese navegador (derecho de oposición). */
(function () {
  'use strict';
  var L = window.VL_LEGAL = {
    version: '2026-11-20',                 // versión vigente de Términos + Privacidad (la que se acepta al crear la tienda)
    fecha: '20 de noviembre de 2026',
    marca: 'Ventas Link',
    responsable: '',                       // nombre completo como en la cédula (persona natural) — PENDIENTE
    ciudad: '',                            // ciudad de domicilio — PENDIENTE
    pais: 'Ecuador',
    correo: ''                             // correo para temas legales y de datos — PENDIENTE
  };
  L.completo = function () { return !!(L.responsable && L.correo && L.ciudad); };

  /* Medición de uso (eventos con un número al azar). Lo necesario para que la app funcione no se apaga. */
  L.medicionApagada = function () { try { return localStorage.getItem('vl-no-medir') === '1'; } catch (e) { return false; } };
  L.apagarMedicion = function (si) {
    try {
      if (si) { localStorage.setItem('vl-no-medir', '1'); localStorage.removeItem('vl-anon'); localStorage.removeItem('vl-fuente'); }
      else localStorage.removeItem('vl-no-medir');
    } catch (e) { /* sin almacenamiento: no se guarda nada */ }
  };

  /* Pinta nombre, ciudad y correo donde la página tenga data-legal="…". Si falta un dato, queda el texto "pendiente". */
  function pintar() {
    [].slice.call(document.querySelectorAll('[data-legal]')).forEach(function (el) {
      var k = el.getAttribute('data-legal'), v = L[k];
      if (!v) return;
      el.textContent = v; el.classList.remove('falta');
      if (k === 'correo' && el.tagName === 'A') el.href = 'mailto:' + v;
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', pintar); else pintar();
})();
