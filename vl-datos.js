/* Ventas Link — cuenta de la vendedora y su tienda (habla con la base de datos).
   Todas las funciones devuelven una promesa con { ok: true, ... } o { ok: false, codigo, mensaje } y NUNCA lanzan error:
   el mensaje ya viene en español sencillo, listo para mostrar. Los códigos técnicos no se enseñan al usuario.
   Nota de seguridad: la sesión se guarda en el navegador (sitio sin servidor propio). Por eso todo texto que viene
   de la base se pinta con textContent, nunca como HTML. */
(function () {
  'use strict';
  var C = window.VL_CONFIG || {}, sb = null;
  var COLUMNAS = 'id, slug, nombre, descripcion, tipo, whatsapp, pais, moneda, idioma, horario, publicada, logo_path, portada_path, estilo, created_at';

  function cliente() {
    if (sb) return sb;
    if (!window.supabase || !C.url || !C.llave) return null;
    try {
      sb = window.supabase.createClient(C.url, C.llave, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'implicit', storageKey: 'vl-sesion' } });
    } catch (e) { sb = null; }
    return sb;
  }
  function origen() { return location.origin; }

  /* ---------- De error técnico a mensaje humano ---------- */
  var MENSAJES = {
    sin_conexion: 'No hay conexión. Revisa tu internet e intenta de nuevo.',
    sin_servicio: 'No pudimos conectar con Ventas Link. Intenta de nuevo en un momento.',
    correo_invalido: 'Revisa tu correo: parece que está mal escrito.',
    muchos_correos: 'Estamos enviando muchos correos en este momento. Espera unos minutos e intenta de nuevo.',
    espera: 'Acabamos de enviarte un correo. Espera {s} segundos para pedir otro.',
    correo_no_habilitado: 'Todavía no podemos enviar correos a esta dirección. Estamos terminando de preparar la app: vuelve pronto.',
    codigo_malo: 'El código no es correcto o ya venció. Pide uno nuevo.',
    registro_cerrado: 'Por ahora no estamos aceptando cuentas nuevas. Vuelve pronto.',
    NO_AUTENTICADO: 'Tu sesión se cerró. Vuelve a entrar con tu correo.',
    SIN_TIENDA: 'Todavía no tienes una tienda creada.',
    SLUG_INVALIDO: 'Ese nombre no sirve para el enlace de tu tienda. Prueba con otro nombre.',
    PRUEBA_YA_USADA: 'Ya usaste tu prueba gratis. Puedes seguir con el plan Gratis.',
    PLAN_INVALIDO: 'Ese plan no está disponible.',
    LIMITE_PRODUCTOS: 'Llegaste al máximo de productos de tu plan.',
    LIMITE_SECCIONES: 'Llegaste al máximo de secciones de tu plan.',
    FUNCION_DE_PAGO: 'Las ofertas con fecha son del plan Emprendedor. Puedes probarlo gratis 7 días.',
    OFERTA_FECHA_INVALIDA: 'La oferta debe terminar en una fecha futura.',
    seccion_repetida: 'Ya tienes una sección con ese nombre.',
    foto_grande: 'La foto pesa demasiado. Prueba con otra.',
    foto_cupo: 'Llegaste al máximo de fotos de tu plan.',
    foto_tipo: 'Ese archivo no es una foto. Usa JPG, PNG o WebP.',
    precio_invalido: 'Revisa el precio: debe ser mayor a 0.',
    nombre_tienda: 'El nombre de tu tienda debe tener entre 2 y 60 letras.',
    whatsapp_tienda: 'Revisa tu número de WhatsApp: no parece estar completo.',
    general: 'Algo salió mal. Intenta de nuevo en un momento.'
  };
  function fallo(e) {
    var cod = 'general', seg = 0, txt = String((e && (e.message || e.msg)) || ''), c = String((e && (e.code || e.error_code)) || ''), st = e && e.status;
    if (!e) cod = 'general';
    else if (MENSAJES[txt]) cod = txt;                                                   /* errores con nombre propio de la base */
    else if (e.name === 'TypeError' || /Failed to fetch|NetworkError|Load failed|fetch/i.test(txt) && !st || e.name === 'AuthRetryableFetchError') cod = 'sin_conexion';
    else if (c === 'email_address_not_authorized') cod = 'correo_no_habilitado';
    else if (/only request this after (\d+) seconds/i.test(txt)) { cod = 'espera'; seg = parseInt(RegExp.$1, 10) || 60; }
    else if (c === 'over_email_send_rate_limit' || c === 'over_request_rate_limit' || st === 429) cod = 'muchos_correos';
    else if (c === 'otp_expired' || c === 'otp_disabled' || /expired|invalid.*token|token.*invalid/i.test(txt)) cod = 'codigo_malo';
    else if (c === 'email_address_invalid' || c === 'validation_failed' || /validate email|invalid format|email.*invalid/i.test(txt)) cod = 'correo_invalido';
    else if (c === 'signup_disabled' || c === 'email_provider_disabled') cod = 'registro_cerrado';
    else if (c === '23505' && /secciones_nombre/.test(txt)) cod = 'seccion_repetida';
    else if (st === 413 || e.statusCode === '413' || /exceeded the maximum allowed size|too large/i.test(txt)) cod = 'foto_grande';
    else if (/mime type|invalid_mime/i.test(txt)) cod = 'foto_tipo';
    else if (/row-level security|violates row level/i.test(txt) && /object|storage/i.test(txt + ' ' + (e.name || ''))) cod = 'foto_cupo';
    else if (c === '23514' && /precio/.test(txt)) cod = 'precio_invalido';
    else if (c === '23514' && /nombre/.test(txt) && /tiendas/.test(txt)) cod = 'nombre_tienda';
    else if (c === '23514' && /whatsapp/.test(txt)) cod = 'whatsapp_tienda';
    return { ok: false, codigo: cod, espera: seg, mensaje: MENSAJES[cod].replace('{s}', String(seg)) };
  }
  function sinCliente() { return Promise.resolve({ ok: false, codigo: 'sin_servicio', espera: 0, mensaje: MENSAJES.sin_servicio }); }
  function correoValido(v) { return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(v || '').trim()) && String(v).trim().length <= 120; }

  /* ---------- Cuenta ---------- */
  function sesion() { var c = cliente(); if (!c) return Promise.resolve(null); return c.auth.getSession().then(function (r) { return (r.data && r.data.session) || null; }).catch(function () { return null; }); }
  function alCambiar(fn) { var c = cliente(); if (c) c.auth.onAuthStateChange(function (evento, s) { fn(evento, s || null); }); }
  /* Envía el correo para entrar (con botón; y con código si la plantilla lo trae). Si la persona es nueva, se crea su cuenta: la respuesta es la misma en los dos casos. */
  function enviarCodigo(correo, destino) {
    var c = cliente(); if (!c) return sinCliente();
    if (!correoValido(correo)) return Promise.resolve(fallo({ code: 'email_address_invalid' }));
    return c.auth.signInWithOtp({ email: String(correo).trim().toLowerCase(), options: { shouldCreateUser: true, emailRedirectTo: origen() + '/' + (/^[a-z-]+\.html$/.test(destino || '') ? destino : 'entrar.html') } })
      .then(function (r) { return r.error ? fallo(r.error) : { ok: true }; }).catch(fallo);
  }
  function verificarCodigo(correo, codigo) {
    var c = cliente(); if (!c) return sinCliente();
    var t = String(codigo || '').replace(/\D/g, ''); if (t.length < 6) return Promise.resolve(fallo({ code: 'otp_expired' }));
    return c.auth.verifyOtp({ email: String(correo).trim().toLowerCase(), token: t, type: 'email' })
      .then(function (r) { return r.error ? fallo(r.error) : { ok: true, sesion: r.data.session }; }).catch(fallo);
  }
  function conGoogle() {
    var c = cliente(); if (!c) return sinCliente();
    return c.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: origen() + '/entrar.html' } })
      .then(function (r) { return r.error ? fallo(r.error) : { ok: true }; }).catch(fallo);
  }
  /* Qué formas de entrar están encendidas en el servidor (así el botón de Google solo sale si de verdad funciona). */
  var _metodos = null;
  function metodos() {
    if (_metodos) return _metodos;
    if (!C.url || !C.llave) return Promise.resolve({ correo: false, google: false });
    _metodos = fetch(C.url + '/auth/v1/settings', { headers: { apikey: C.llave } }).then(function (r) { return r.json(); })
      .then(function (j) { var x = (j && j.external) || {}; return { correo: x.email !== false, google: x.google === true }; })
      .catch(function () { _metodos = null; return { correo: true, google: false }; });
    return _metodos;
  }
  function salir() { var c = cliente(); if (!c) return Promise.resolve({ ok: true }); return c.auth.signOut().then(function () { return { ok: true }; }).catch(function () { return { ok: true }; }); }
  /* Si el enlace del correo ya venció, el servidor lo avisa en la dirección de la página. */
  function errorDeEnlace() {
    var h = String(location.hash || '') + '&' + String(location.search || '').replace(/^\?/, '');
    if (!/error(_code|_description)?=/.test(h)) return null;
    try { history.replaceState(null, '', location.pathname); } catch (e) { /* sin historial */ }
    return 'Ese enlace ya venció o ya se usó. Pide un correo nuevo.';
  }

  /* ---------- Tienda ---------- */
  function miTienda() {
    var c = cliente(); if (!c) return sinCliente();
    return c.from('tiendas').select(COLUMNAS).maybeSingle().then(function (r) { return r.error ? fallo(r.error) : { ok: true, tienda: r.data || null }; }).catch(fallo);
  }
  function slugDe(nombre) {
    var s = String(nombre || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').replace(/-{2,}/g, '-').slice(0, 40).replace(/-+$/g, '');
    return s.length >= 3 ? s : (s ? s + '-tienda' : 'mi-tienda');
  }
  /* Crea la tienda con las respuestas del recorrido. Busca un enlace libre (nombre, nombre-2, nombre-3…). Si la cuenta ya tenía tienda, devuelve esa. */
  function crearTienda(d) {
    var c = cliente(); if (!c) return sinCliente();
    var base = slugDe(d.nombre);
    function intentar(i) {
      var s = i === 0 ? base : (i < 7 ? base.slice(0, 36).replace(/-+$/g, '') + '-' + (i + 1) : base.slice(0, 30).replace(/-+$/g, '') + '-' + Math.random().toString(36).slice(2, 7));
      return c.rpc('slug_disponible', { p_slug: s }).then(function (r) {
        if (r.error) throw r.error;
        if (!r.data && i < 9) return intentar(i + 1);
        return c.from('tiendas').insert({ slug: s, nombre: String(d.nombre).trim(), tipo: String(d.tipo || '').slice(0, 40), whatsapp: String(d.whatsapp || '').replace(/\D/g, ''), pais: d.pais || 'EC', moneda: d.moneda || 'USD', fuente: /^[a-z0-9_:.-]{1,40}$/.test(d.fuente || '') ? d.fuente : 'directo' })
          .select(COLUMNAS).single().then(function (q) {
            if (!q.error) return { ok: true, tienda: q.data, nueva: true };
            if (q.error.code !== '23505') throw q.error;
            /* 23505 = ya existe: o esta cuenta ya tenía tienda, o alguien tomó ese enlace hace un instante */
            return miTienda().then(function (t) { if (t.ok && t.tienda) return { ok: true, tienda: t.tienda, nueva: false }; if (i < 9) return intentar(i + 1); throw q.error; });
          });
      });
    }
    return intentar(0).then(function (res) {
      /* Aceptación de Términos + Privacidad (la casilla que la vendedora marcó): queda registrada con su versión. */
      return (d.legal ? aceptarLegal(d.legal, 'recorrido') : Promise.resolve()).then(function () { return res; });
    }).then(function (res) {
      var secs = (d.secciones || []).slice(0, 3);
      if (!res.nueva || !secs.length) return res;
      /* Secciones sugeridas: si fallan no se pierde la tienda (la vendedora las crea luego). */
      return c.from('secciones').insert(secs.map(function (n, k) { return { tienda_id: res.tienda.id, nombre: String(n).slice(0, 40), orden: k }; })).then(function () { return res; }, function () { return res; });
    }).catch(fallo);
  }
  /* Registra que esta cuenta aceptó la versión vigente de Términos + Privacidad. Si falla, no frena a la vendedora. */
  function aceptarLegal(version, origenTxt) {
    var c = cliente(); if (!c || !/^\d{4}-\d{2}-\d{2}$/.test(version || '')) return Promise.resolve({ ok: false });
    return c.rpc('registrar_consentimiento', { p_version: version, p_origen: origenTxt || '' }).then(function (r) { return { ok: !r.error }; }, function () { return { ok: false }; });
  }
  /* Elimina la cuenta de quien tiene la sesión: tienda, productos, fotos y pedidos (función de servidor borrar-cuenta). */
  function borrarCuenta() {
    var c = cliente(); if (!c) return sinCliente();
    return c.functions.invoke('borrar-cuenta', { body: { confirmo: 'ELIMINAR' } }).then(function (r) {
      if (!r.error) return c.auth.signOut().catch(function () { /* la sesión ya no existe */ }).then(function () { try { localStorage.removeItem('vl-recorrido'); } catch (e) { /* ok */ } return { ok: true }; });
      var st = r.error && r.error.context && r.error.context.status;
      if (st === 409) return { ok: false, mensaje: 'Esta es la cuenta de la dueña del panel: no se puede borrar desde aquí.' };
      if (st === 401) return { ok: false, mensaje: 'Tu sesión venció. Vuelve a entrar e inténtalo de nuevo.' };
      return { ok: false, mensaje: 'No pudimos eliminar tu cuenta. Revisa tu conexión e inténtalo de nuevo; si sigue fallando, escríbenos.' };
    }).catch(function () { return { ok: false, mensaje: 'No hay conexión. Revisa tu internet e inténtalo de nuevo.' }; });
  }
  function enlaceTienda(slug) { return origen() + '/t/' + slug; }
  /* Dirección pública de una foto guardada (el catálogo es público por enlace). */
  function fotoUrl(path) { return path ? C.url + '/storage/v1/object/public/media/' + String(path).split('/').map(encodeURIComponent).join('/') : ''; }

  /* ---------- Plan ---------- */
  /* ¿Esta cuenta es la dueña? (lo decide la base; se usa solo para llevarla a su panel) */
  function esAdmin() { var c = cliente(); if (!c) return Promise.resolve(false); return c.rpc('soy_admin').then(function (r) { return !r.error && r.data === true; }).catch(function () { return false; }); }
  /* Sin tienda: la dueña va a su panel; las demás, a crear su tienda */
  function irSinTienda() { return esAdmin().then(function (si) { location.replace(si ? 'admin.html' : 'onboarding-demo.html'); }); }
  function miPlan() { var c = cliente(); if (!c) return sinCliente(); return c.rpc('mi_plan').then(function (r) { return r.error ? fallo(r.error) : { ok: true, plan: r.data }; }).catch(fallo); }
  function iniciarPrueba(plan) {
    var c = cliente(); if (!c) return sinCliente();
    return c.rpc('iniciar_prueba', { p_plan: plan === 'pro' ? 'profesional' : plan }).then(function (r) { return r.error ? fallo(r.error) : { ok: true, plan: r.data }; }).catch(fallo);
  }

  window.VL = { conCodigo: C.correoConCodigo === true, listo: !!(window.supabase && C.url && C.llave) && location.protocol !== 'file:', cliente: cliente, sesion: sesion, alCambiar: alCambiar, enviarCodigo: enviarCodigo, verificarCodigo: verificarCodigo,
    conGoogle: conGoogle, metodos: metodos, salir: salir, errorDeEnlace: errorDeEnlace, correoValido: correoValido, miTienda: miTienda, crearTienda: crearTienda, slugDe: slugDe, enlaceTienda: enlaceTienda, fotoUrl: fotoUrl,
    miPlan: miPlan, esAdmin: esAdmin, irSinTienda: irSinTienda, iniciarPrueba: iniciarPrueba, aceptarLegal: aceptarLegal, borrarCuenta: borrarCuenta, _fallo: fallo };
})();
