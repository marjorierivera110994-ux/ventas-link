/* Ventas Link — registro de actividad y errores para el panel de la dueña.
   - Guarda de qué enlace llegó la persona (primer toque: ?src=, ?utm_source= o invitación).
   - Avisa a la base de pocos momentos clave (no de cada toque) y de los errores que ve la vendedora.
   - No guarda nombres, correos ni teléfonos: solo un número al azar por celular (para contar personas, no identificarlas).
   Si algo falla aquí, la app sigue igual: nunca interrumpe a la usuaria. */
(function () {
  'use strict';
  var C = window.VL_CONFIG || {};
  var activo = !!(C.url && C.llave) && location.protocol !== 'file:';

  function nuevoId() { return window.crypto && crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) { var r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16); }); }
  function anonId() {
    try { var a = localStorage.getItem('vl-anon'); if (!a || !/^[a-z0-9-]{8,40}$/.test(a)) { a = nuevoId().toLowerCase(); localStorage.setItem('vl-anon', a); } return a; } catch (e) { return null; }
  }
  /* Origen de la persona: el primero gana (si después entra por otro enlace, no se sobrescribe). */
  function capturarFuente() {
    try {
      var p = new URLSearchParams(location.search), s = p.get('src') || p.get('utm_source') || '';
      if (!s && (p.get('ref') || /[#&]ref=/.test(location.hash))) s = 'invitacion';
      s = String(s).toLowerCase().replace(/[^a-z0-9_:.-]/g, '').slice(0, 40);
      if (s && !localStorage.getItem('vl-fuente')) localStorage.setItem('vl-fuente', s);
    } catch (e) { /* sin almacenamiento */ }
  }
  function fuente() { try { var f = localStorage.getItem('vl-fuente'); return f && /^[a-z0-9_:.-]{1,40}$/.test(f) ? f : 'directo'; } catch (e) { return 'directo'; } }
  /* Sesión de la vendedora (si entró): así el evento cuenta para ella. */
  function sesion() { try { var s = JSON.parse(localStorage.getItem('vl-sesion') || 'null'); if (s && s.access_token && s.user && (!s.expires_at || s.expires_at * 1000 > Date.now())) return s; } catch (e) { /* ok */ } return null; }
  function rpc(fn, args) {
    if (!activo) return;
    var h = { apikey: C.llave, 'Content-Type': 'application/json' }, s = sesion(); if (s) h.Authorization = 'Bearer ' + s.access_token;
    try { fetch(C.url + '/rest/v1/rpc/' + fn, { method: 'POST', keepalive: true, headers: h, body: JSON.stringify(args) }).catch(function () { /* no importa */ }); } catch (e) { /* no importa */ }
  }
  function evento(tipo, props) { rpc('registrar_evento', { p_tipo: tipo, p_anon: anonId(), p_props: props || {} }); }
  function unaVezPorVisita(tipo, props) { try { if (sessionStorage.getItem('vl-ev-' + tipo)) return; sessionStorage.setItem('vl-ev-' + tipo, '1'); } catch (e) { /* ok */ } evento(tipo, props); }
  function hoy() { var d = new Date(); return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate(); }
  /* Un "día activo" por vendedora (para saber quién vuelve al día 1, 7 y 30). */
  function sesionDiaria() {
    var s = sesion(); if (!s) return;
    var k = 'vl-dia-' + s.user.id; try { if (localStorage.getItem(k) === hoy()) return; localStorage.setItem(k, hoy()); } catch (e) { /* ok */ }
    evento('sesion_iniciada', {});
  }
  var enviados = 0;
  function error(msg, pagina) {
    if (!activo || enviados >= 5) return; var m = String(msg || '').replace(/\s+/g, ' ').trim(); if (!m) return; enviados++;
    rpc('registrar_error', { p_mensaje: m.slice(0, 300), p_pagina: String(pagina || location.pathname.split('/').pop() || 'inicio').slice(0, 80), p_anon: anonId() });
  }
  window.addEventListener('error', function (e) {
    if (!e || !e.message || /^Script error/i.test(e.message)) return;          /* errores de otros sitios: no se pueden leer */
    error(e.message + (e.filename ? ' (' + e.filename.split('/').pop() + ':' + e.lineno + ')' : ''));
  });
  window.addEventListener('unhandledrejection', function (e) { var r = e && e.reason; if (r && /AbortError|Load failed|Failed to fetch|NetworkError/i.test(String(r.name || '') + String(r.message || ''))) return; error('Promesa sin respuesta: ' + (r && r.message ? r.message : String(r)).slice(0, 240)); });

  capturarFuente();
  window.VL_REG = { evento: evento, unaVezPorVisita: unaVezPorVisita, sesionDiaria: sesionDiaria, error: error, fuente: fuente, anonId: anonId };
})();
