/* Ventas Link — notificaciones push en el celular del vendedor.
   Pide permiso SOLO cuando el vendedor toca "Activar avisos" (nunca al entrar), suscribe este celular y lo guarda en su cuenta.
   iPhone/iPad: Apple solo permite avisos en apps agregadas a la pantalla de inicio (iOS 16.4 o más nuevo). */
(function () {
  'use strict';
  var SW = 'sw.js';

  function esIOS() { return /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1); }
  function instalada() { return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true; }
  function soporte() {
    var api = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window && window.isSecureContext;
    if (esIOS() && !instalada()) return { ok: false, motivo: 'ios_instalar' };
    if (!api) return { ok: false, motivo: esIOS() ? 'ios_viejo' : 'navegador' };
    return { ok: true };
  }
  function dispositivo() {
    var ua = navigator.userAgent, so = /android/i.test(ua) ? 'Android' : esIOS() ? 'iPhone' : /windows/i.test(ua) ? 'Windows' : /mac/i.test(ua) ? 'Mac' : 'Otro';
    var nav = /edg\//i.test(ua) ? 'Edge' : /samsungbrowser/i.test(ua) ? 'Samsung' : /firefox|fxios/i.test(ua) ? 'Firefox' : /crios|chrome/i.test(ua) ? 'Chrome' : /safari/i.test(ua) ? 'Safari' : '';
    return (so + (nav ? ' · ' + nav : '') + (instalada() ? ' · app' : '')).slice(0, 80);
  }
  function aBytes(b64) {
    var t = b64.replace(/-/g, '+').replace(/_/g, '/'); t += '='.repeat((4 - t.length % 4) % 4);
    var bin = atob(t), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }
  function registro() {
    return navigator.serviceWorker.getRegistration(SW).then(function (r) { return r || navigator.serviceWorker.register(SW); })
      .then(function () { return navigator.serviceWorker.ready; });
  }
  function rpc(n, a) { return window.VL.cliente().rpc(n, a || {}).then(function (r) { if (r.error) throw r.error; return r.data; }); }

  /* Estado en ESTE celular: 'activo' | 'inactivo' | 'bloqueado' | 'no_soportado' | 'ios_instalar' */
  function estado() {
    var s = soporte();
    if (!s.ok) return Promise.resolve(s.motivo === 'ios_instalar' ? 'ios_instalar' : 'no_soportado');
    if (Notification.permission === 'denied') return Promise.resolve('bloqueado');
    return navigator.serviceWorker.getRegistration(SW).then(function (r) {
      if (!r || Notification.permission !== 'granted') return 'inactivo';
      return r.pushManager.getSubscription().then(function (sub) { return sub ? 'activo' : 'inactivo'; });
    }).catch(function () { return 'inactivo'; });
  }

  function guardar(sub) {
    var j = sub.toJSON();
    return rpc('push_guardar', { p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth, p_dispositivo: dispositivo() });
  }

  /* Debe llamarse desde un toque del vendedor (los celulares solo muestran el permiso así). */
  function activar() {
    var s = soporte(); if (!s.ok) return Promise.reject({ codigo: s.motivo });
    var pedir = Notification.permission === 'granted' ? Promise.resolve('granted') : Notification.requestPermission();
    return Promise.resolve(pedir).then(function (p) {
      if (p !== 'granted') throw { codigo: p === 'denied' ? 'bloqueado' : 'sin_permiso' };
      return Promise.all([registro(), rpc('push_clave_publica')]);
    }).then(function (x) {
      var reg = x[0], clave = x[1];
      if (!clave) throw { codigo: 'servidor' };
      return reg.pushManager.getSubscription().then(function (vieja) {
        // Si la suscripción se hizo con otra llave, se cambia por una nueva.
        if (vieja && vieja.options && vieja.options.applicationServerKey) {
          var a = new Uint8Array(vieja.options.applicationServerKey), b = aBytes(clave);
          var igual = a.length === b.length && a.every(function (v, i) { return v === b[i]; });
          if (igual) return vieja;
          return vieja.unsubscribe().then(function () { return null; });
        }
        return vieja;
      }).then(function (sub) { return sub || reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: aBytes(clave) }); });
    }).then(guardar);
  }

  function desactivar() {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    return navigator.serviceWorker.getRegistration(SW).then(function (r) { return r && r.pushManager.getSubscription(); }).then(function (sub) {
      if (!sub) return;
      var ep = sub.endpoint;
      return sub.unsubscribe().then(function () { return rpc('push_borrar', { p_endpoint: ep }); });
    });
  }

  /* Al abrir la app: si este celular ya tiene permiso, se vuelve a guardar la suscripción (por si el navegador la renovó). */
  function sincronizar() {
    if (!soporte().ok || Notification.permission !== 'granted' || !window.VL || !window.VL.listo) return Promise.resolve(false);
    return navigator.serviceWorker.getRegistration(SW).then(function (r) {
      if (!r) return false;
      return r.pushManager.getSubscription().then(function (sub) { return sub ? guardar(sub).then(function () { return true; }) : false; });
    }).catch(function () { return false; });
  }

  window.VLAvisos = { soporte: soporte, estado: estado, activar: activar, desactivar: desactivar, sincronizar: sincronizar, esIOS: esIOS, instalada: instalada };
})();
