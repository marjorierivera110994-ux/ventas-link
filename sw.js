/* Ventas Link — service worker: recibe las notificaciones push aunque la app esté cerrada.
   No guarda páginas en caché (la app siempre se carga fresca); solo muestra avisos y abre la sección correcta al tocarlos. */
'use strict';
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (x) { d = { t: 'Ventas Link', b: e.data ? e.data.text() : '' }; }
  var url = typeof d.u === 'string' && /^[a-z0-9-]+\.html(#[a-z]+)?$/.test(d.u) ? d.u : 'app-vendedor.html';
  var opciones = {
    body: d.b || '',
    icon: 'logo/ventas-link-icono-192.png',
    badge: 'logo/ventas-link-insignia-96.png',
    tag: (d.g || 'aviso') + '-' + (d.id || Date.now()),
    data: { url: url },
    lang: 'es',
    timestamp: Date.now()
  };
  e.waitUntil(self.registration.showNotification(d.t || 'Ventas Link', opciones).then(function () {
    // Si la app está abierta, se le avisa para que actualice pedidos y puntos sin recargar.
    return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (lista) {
      lista.forEach(function (c) { c.postMessage({ tipo: 'vl-aviso', url: url }); });
    });
  }));
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var destino = new URL((e.notification.data && e.notification.data.url) || 'app-vendedor.html', self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (lista) {
    for (var i = 0; i < lista.length; i++) {
      var c = lista[i];
      if (c.url.indexOf('app-vendedor.html') !== -1 && 'focus' in c) { c.postMessage({ tipo: 'vl-ir', url: destino }); return c.focus(); }
    }
    return self.clients.openWindow(destino);
  }));
});
