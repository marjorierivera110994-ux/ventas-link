/* Ventas Link — frases positivas con fondos profesionales (todo se dibuja en el celular, sin subir nada).
   - Frases ORIGINALES (no son citas de personas famosas: así nunca se atribuye algo falso a nadie).
   - Fondos: 36 paletas x 12 diseños, y cada uno cambia de forma con cada semilla: nunca sale dos veces igual.
   Uso: VL_ARTE.frase(['ventas','network','vida'], 'llave') · VL_ARTE.pintarFondo(canvas, semilla) · VL_ARTE.imagen({...}) · VL_ARTE.compartir(canvas, nombre, texto) */
(function (G) {
  'use strict';

  var FRASES = {
    ventas: [
      'Vender es ayudar a alguien a decidir bien.',
      'Quien escucha primero, vende mejor.',
      'Un "no" de hoy te acerca al "sí" de mañana.',
      'Responder rápido es la mejor publicidad.',
      'Una foto clara vende más que mil explicaciones.',
      'El seguimiento amable cierra más ventas que el mejor discurso.',
      'No vendes productos: resuelves problemas y alegras días.',
      'Cada cliente feliz te trae otro. Cuida el trato.',
      'El precio se olvida; el buen trato se recuerda.',
      'Pregunta más y ofrece menos: el cliente te dirá qué necesita.',
      'Publica hoy, aunque no salga perfecto.',
      'La confianza se gana cumpliendo lo que prometes.',
      'Vende con la verdad y venderás muchas veces.',
      'Tu mejor vitrina es un cliente contento.',
      'Quien muestra todos los días, vende todos los meses.',
      'Detrás de cada pedido hay una persona. Trátala por su nombre.',
      'El cierre empieza con una buena pregunta.',
      'No esperes al cliente perfecto: atiende perfecto al que llegó.',
      'Una objeción es una pregunta que todavía no respondes.',
      'Lo que se mide, mejora. Anota tus ventas.',
      'Hazlo fácil: quien compra sin enredos, vuelve.',
      'Tu producto vale. Dilo con seguridad.',
      'Hoy alguien busca justo lo que tú vendes. Muéstralo.',
      'Las ventas grandes nacen de detalles pequeños.',
      'Agradece cada compra: la gratitud también fideliza.',
      'Primero sirve, después vende.',
      'Un mensaje a tiempo vale más que diez descuentos.',
      'Conoce tu producto como conoces tu casa.',
      'La constancia vende más que el talento que no se mueve.',
      'Cierra el día con un seguimiento más.',
      'Vender bien es dejar al cliente mejor de lo que llegó.',
      'Tu energía se nota hasta en un mensaje. Escribe con ganas.',
      'Ofrece soluciones, no solo productos.',
      'Cada publicación es una puerta abierta a tu tienda.',
      'El cliente que pregunta ya dio el primer paso. Acompáñalo.',
      'Menos excusas, más mensajes enviados.',
      'Si hoy no vendiste, hoy aprendiste. Sigue.',
      'Cumple lo que dices y tu nombre venderá por ti.',
      'Haz que comprarte sea una experiencia bonita.',
      'Una venta honesta hoy es una recomendación mañana.'
    ],
    network: [
      'Tu red crece cuando tú creces.',
      'Comparte tu historia: inspira más que cualquier catálogo.',
      'Un equipo unido llega más lejos que una estrella sola.',
      'Enseña lo que sabes y multiplicarás lo que logras.',
      'Cada conversación es una semilla. Siembra todos los días.',
      'Lidera con el ejemplo, no con el discurso.',
      'Ayuda a otros a ganar y ganarás con ellos.',
      'Tu negocio crece al ritmo de tus relaciones.',
      'Invita con ilusión, acompaña con paciencia.',
      'La duplicación empieza cuando lo haces simple.',
      'No buscas clientes: construyes una comunidad.',
      'El que suma personas, multiplica oportunidades.',
      'Celebra los logros de tu equipo como si fueran tuyos.',
      'Hoy conoce a una persona nueva y escúchala de verdad.',
      'Los grandes equipos se hacen con pequeños hábitos diarios.',
      'Sé la persona que te hubiera gustado tener al empezar.',
      'Una red fuerte se teje con confianza, hilo por hilo.',
      'Comparte la oportunidad sin presionar: el que es, llega.',
      'Tu constancia es el mejor entrenamiento para tu equipo.',
      'Conecta primero, presenta después.',
      'Aprende algo hoy y enséñaselo a alguien mañana.',
      'El liderazgo es servicio con visión.',
      'Quien cuida a su equipo, cuida su futuro.',
      'Un mensaje sincero abre más puertas que cien copiados.',
      'Crece tú, y tu red te seguirá.',
      'No cuentes contactos: cultiva relaciones.',
      'El éxito compartido sabe mejor.',
      'Cada "sí" empezó con alguien que se animó a invitar.',
      'Da seguimiento con cariño: nadie quiere sentirse un número.',
      'Tu ejemplo habla más fuerte que tu presentación.',
      'Rodéate de gente que te empuje hacia arriba.',
      'Reconoce en público, corrige en privado.',
      'Un sueño compartido se convierte en un plan.',
      'Tu red es tu mayor activo: inviértele tiempo.',
      'Empieza con quien tienes cerca y llegarás lejos.',
      'Escuchar a tu equipo también es liderar.',
      'Trabaja como si todos te siguieran: alguien lo está haciendo.',
      'Hoy ayuda a una persona de tu equipo a dar su primer paso.',
      'La paciencia construye redes que duran años.',
      'Juntos se llega más lejos y se disfruta más el camino.'
    ],
    vida: [
      'Hoy es un buen día para empezar de nuevo.',
      'Pequeños pasos cada día construyen grandes historias.',
      'Cree en ti: ya has superado días más difíciles.',
      'La gratitud convierte lo que tienes en suficiente.',
      'Sonríe: alguien necesita hoy tu alegría.',
      'Lo bueno llega a quien se anima a dar el primer paso.',
      'Cuídate, quiérete y date ese gusto que mereces.',
      'La vida es más linda cuando la compartes con los tuyos.',
      'Hoy haz algo que tu yo de mañana te agradezca.',
      'Pequeños detalles hacen grandes días.',
      'Tú puedes más de lo que imaginas. Sigue adelante.',
      'Respira hondo: todo empieza con calma.',
      'Cada amanecer trae una oportunidad nueva.',
      'Lo que haces con amor siempre deja huella.',
      'Agradece lo que tienes mientras trabajas por lo que quieres.',
      'Eres más fuerte de lo que crees.',
      'Hoy elige ver lo bonito.',
      'Los sueños se cumplen caminando.',
      'Sé amable contigo: estás haciendo lo mejor que puedes.',
      'La felicidad está en las cosas sencillas.',
      'Un día a la vez, un paso a la vez.',
      'Regala una palabra bonita: no cuesta y vale mucho.',
      'Lo mejor está por venir.',
      'Florece donde estés.',
      'Tu actitud pinta el color de tu día.',
      'Celebra lo pequeño: de eso está hecha la vida.',
      'Quien siembra alegría, cosecha amigos.',
      'Nunca es tarde para empezar algo que te ilusiona.',
      'Hoy puede ser el día que cambie todo.',
      'La calma también es avanzar.',
      'Abraza fuerte a quienes quieres.',
      'Mereces cosas bonitas. Empieza por creerlo.',
      'Cada día es un regalo: ábrelo con ganas.',
      'Haz hoy algo que te haga sonreír.',
      'La vida premia a quien no se rinde.',
      'Llena tu día de momentos, no de pendientes.',
      'Donde hay ganas, hay camino.',
      'Lo que das con el corazón, vuelve multiplicado.',
      'Brilla a tu manera.',
      'Hoy es tu día: disfrútalo.'
    ]
  };

  /* [color 1, color 2, acento, 1 = fondo oscuro (letra blanca) / 0 = fondo claro (letra oscura)]
     Pedido del 20-nov-2026: las frases NUNCA salen en caja oscura; las 20 paletas oscuras pasaron a celeste. */
  var PALETAS = [
    ['#e3f5ff', '#a9dcfb', '#ff7a1a', 0], ['#eaf8ff', '#bfe6ff', '#2f9bea', 0], ['#dff3ff', '#9fd6f7', '#4fae12', 0], ['#f0faff', '#c6e9fc', '#e0457b', 0],
    ['#e6f6ff', '#b3e0fa', '#f08c00', 0], ['#dcf1fe', '#97d1f4', '#1c5d99', 0], ['#eef9ff', '#cdeefe', '#6741d9', 0], ['#e1f4fd', '#a3d9f5', '#0b7285', 0],
    ['#e9f7ff', '#b8e3fb', '#d6336c', 0], ['#e4f6ff', '#acdffb', '#5c940d', 0], ['#ecf8ff', '#c2e7fc', '#ff6a00', 0], ['#ddf2fe', '#9bd3f5', '#3b5bdb', 0],
    ['#e7f7ff', '#b5e2fb', '#ae3ec9', 0], ['#f2fbff', '#d3f0ff', '#2f9bea', 0], ['#e2f4fe', '#a6daf8', '#e8590c', 0], ['#eaf7fd', '#bde4f7', '#0ca678', 0],
    ['#e5f6ff', '#afe0fa', '#c92a2a', 0], ['#dff4ff', '#a1d8f8', '#b5651d', 0], ['#edf9ff', '#c9ebfd', '#4fae12', 0], ['#e0f3ff', '#a0d6f6', '#ff7a1a', 0],
    ['#fff1e6', '#ffd7ba', '#ff7a1a', 0], ['#e8f7ff', '#bfe6ff', '#2f9bea', 0], ['#f1ffe0', '#d4f5a8', '#4fae12', 0], ['#fff0f6', '#ffd1e3', '#e0457b', 0],
    ['#fffbe0', '#ffec99', '#f08c00', 0], ['#f3f0ff', '#d9d0ff', '#6741d9', 0], ['#e6fcf5', '#b8f2df', '#0ca678', 0], ['#fdf6ec', '#f1dfc3', '#b5651d', 0],
    ['#eef3f8', '#d3dee9', '#1c5d99', 0], ['#fff4e6', '#ffd8a8', '#e8590c', 0], ['#f8f0fc', '#eebefa', '#ae3ec9', 0], ['#e3fafc', '#b2ebf2', '#0b7285', 0],
    ['#fef9ef', '#fde2c4', '#d6336c', 0], ['#f4fce3', '#e2f5a6', '#5c940d', 0], ['#edf2ff', '#c5d4ff', '#3b5bdb', 0], ['#fff5f5', '#ffd0cc', '#c92a2a', 0]
  ];
  var TINTA_CLARA = '#ffffff', TINTA_OSCURA = '#14202b';

  function azar(semilla) { var s = (semilla >>> 0) || 1; return function () { s |= 0; s = s + 0x6D2B79F5 | 0; var t = Math.imul(s ^ s >>> 15, 1 | s); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  function rgb(hex) { var n = parseInt(hex.slice(1), 16); return (n >> 16) + ',' + (n >> 8 & 255) + ',' + (n & 255); }
  function nuevaSemilla() { return Math.floor(Math.random() * 4294967295) + 1; }

  /* ---------- 12 diseños de fondo: marcas suaves para que la frase siempre se lea ---------- */
  var DISENOS = [
    function orbes(x, W, H, r, c) { for (var i = 0; i < 5; i++) { var cx = r() * W, cy = r() * H, R = (.22 + r() * .32) * Math.max(W, H), g = x.createRadialGradient(cx, cy, 0, cx, cy, R); g.addColorStop(0, 'rgba(' + (i % 2 ? c.t : c.a) + ',.20)'); g.addColorStop(1, 'rgba(' + c.t + ',0)'); x.fillStyle = g; x.fillRect(0, 0, W, H); } },
    function bandas(x, W, H, r, c) { x.save(); x.translate(W / 2, H / 2); x.rotate(-.5 + r() * .25); var L = Math.max(W, H) * 1.6, y = -L / 2; while (y < L / 2) { var h = (.03 + r() * .09) * L; x.fillStyle = 'rgba(' + (r() > .7 ? c.a : c.t) + ',' + (.04 + r() * .08) + ')'; x.fillRect(-L, y, L * 2, h); y += h * (1.6 + r() * 1.8); } x.restore(); },
    function puntos(x, W, H, r, c) { var p = Math.max(W, H) / (16 + Math.floor(r() * 8)), ox = r() * W, oy = r() * H, D = Math.max(W, H); for (var a = p / 2; a < W; a += p) for (var b = p / 2; b < H; b += p) { var d = Math.hypot(a - ox, b - oy) / D, k = Math.max(0, 1 - d * 1.5); if (k <= 0) continue; x.fillStyle = 'rgba(' + c.t + ',' + (.20 * k) + ')'; x.beginPath(); x.arc(a, b, p * .13 * (.5 + k), 0, 7); x.fill(); } },
    function ondas(x, W, H, r, c) { for (var i = 0; i < 5; i++) { var base = H * (.52 + i * .1 + r() * .04), amp = H * (.03 + r() * .04), f = 1 + r() * 2, fase = r() * 7; x.fillStyle = 'rgba(' + (i === 2 ? c.a : c.t) + ',' + (.06 + i * .018) + ')'; x.beginPath(); x.moveTo(0, H); for (var a = 0; a <= W; a += W / 60) x.lineTo(a, base + Math.sin(a / W * 6.283 * f + fase) * amp); x.lineTo(W, H); x.closePath(); x.fill(); } },
    function rayos(x, W, H, r, c) { var cx = r() > .5 ? W * (.8 + r() * .3) : W * (-.1 + r() * .3), cy = H * (-.05 + r() * .2), n = 14 + Math.floor(r() * 10), L = Math.max(W, H) * 1.8, a0 = r() * 7; for (var i = 0; i < n; i += 2) { var a = a0 + i / n * 6.283, b = a + 6.283 / n * .9; x.fillStyle = 'rgba(' + c.t + ',' + (.045 + r() * .05) + ')'; x.beginPath(); x.moveTo(cx, cy); x.lineTo(cx + Math.cos(a) * L, cy + Math.sin(a) * L); x.lineTo(cx + Math.cos(b) * L, cy + Math.sin(b) * L); x.closePath(); x.fill(); } var g = x.createRadialGradient(cx, cy, 0, cx, cy, Math.max(W, H) * .35); g.addColorStop(0, 'rgba(' + c.a + ',.28)'); g.addColorStop(1, 'rgba(' + c.a + ',0)'); x.fillStyle = g; x.fillRect(0, 0, W, H); },
    function anillos(x, W, H, r, c) { for (var k = 0; k < 2; k++) { var cx = k ? W * (r() * .3) : W * (.7 + r() * .3), cy = k ? H * (.75 + r() * .3) : H * (r() * .3), paso = Math.max(W, H) * (.035 + r() * .02); x.lineWidth = Math.max(1.5, paso * .16); for (var i = 1; i < 12; i++) { x.strokeStyle = 'rgba(' + (i % 4 === 0 ? c.a : c.t) + ',' + Math.max(0, .17 - i * .012) + ')'; x.beginPath(); x.arc(cx, cy, i * paso, 0, 7); x.stroke(); } } },
    function confeti(x, W, H, r, c) { var n = 46, u = Math.max(W, H) / 60; for (var i = 0; i < n; i++) { var a = r() * W, b = r() * H, centro = Math.abs(a - W / 2) < W * .3 && Math.abs(b - H / 2) < H * .24; x.save(); x.translate(a, b); x.rotate(r() * 6.283); x.fillStyle = 'rgba(' + (r() > .55 ? c.a : c.t) + ',' + (centro ? .06 : .12 + r() * .14) + ')'; var w = u * (.6 + r() * 1.4); if (r() > .5) { x.beginPath(); x.arc(0, 0, w * .5, 0, 7); x.fill(); } else x.fillRect(-w, -w * .28, w * 2, w * .56); x.restore(); } },
    function colinas(x, W, H, r, c) { var g = x.createRadialGradient(W * (.25 + r() * .5), H * .3, 0, W * .5, H * .3, Math.max(W, H) * .5); g.addColorStop(0, 'rgba(' + c.a + ',.22)'); g.addColorStop(1, 'rgba(' + c.a + ',0)'); x.fillStyle = g; x.fillRect(0, 0, W, H); for (var i = 0; i < 4; i++) { var base = H * (.68 + i * .08), p1 = r() * W, p2 = r() * W; x.fillStyle = 'rgba(' + c.t + ',' + (.07 + i * .03) + ')'; x.beginPath(); x.moveTo(0, H); x.lineTo(0, base); x.bezierCurveTo(p1, base - H * (.08 + r() * .1), p2, base + H * (.02 + r() * .06), W, base - H * (r() * .08)); x.lineTo(W, H); x.closePath(); x.fill(); } },
    function estrellas(x, W, H, r, c) { var u = Math.max(W, H) / 100; for (var i = 0; i < 60; i++) { var a = r() * W, b = r() * H, s = u * (.25 + r() * .9); x.fillStyle = 'rgba(' + (r() > .8 ? c.a : c.t) + ',' + (.14 + r() * .3) + ')'; if (r() > .75) { x.beginPath(); x.moveTo(a, b - s * 2.4); x.quadraticCurveTo(a, b, a + s * 2.4, b); x.quadraticCurveTo(a, b, a, b + s * 2.4); x.quadraticCurveTo(a, b, a - s * 2.4, b); x.quadraticCurveTo(a, b, a, b - s * 2.4); x.fill(); } else { x.beginPath(); x.arc(a, b, s * .55, 0, 7); x.fill(); } } var fx = W * (.55 + r() * .3), fy = H * (.08 + r() * .12), L = Math.max(W, H) * .22, gr = x.createLinearGradient(fx - L, fy + L * .5, fx, fy); gr.addColorStop(0, 'rgba(' + c.t + ',0)'); gr.addColorStop(1, 'rgba(' + c.a + ',.6)'); x.strokeStyle = gr; x.lineWidth = u * .9; x.lineCap = 'round'; x.beginPath(); x.moveTo(fx - L, fy + L * .5); x.lineTo(fx, fy); x.stroke(); },
    function bokeh(x, W, H, r, c) { for (var i = 0; i < 22; i++) { var a = r() * W, b = r() * H, R = Math.max(W, H) * (.03 + r() * .1); x.fillStyle = 'rgba(' + (r() > .6 ? c.a : c.t) + ',' + (.04 + r() * .08) + ')'; x.beginPath(); x.arc(a, b, R, 0, 7); x.fill(); x.strokeStyle = 'rgba(' + c.t + ',.07)'; x.lineWidth = Math.max(1, R * .04); x.stroke(); } },
    function malla(x, W, H, r, c) { var p = Math.max(W, H) / (9 + Math.floor(r() * 6)); x.save(); x.translate(W / 2, H / 2); x.rotate(r() > .5 ? .785 : 0); var L = Math.max(W, H); x.lineWidth = Math.max(1, p * .03); for (var a = -L; a <= L; a += p) { x.strokeStyle = 'rgba(' + c.t + ',.09)'; x.beginPath(); x.moveTo(a, -L); x.lineTo(a, L); x.stroke(); x.beginPath(); x.moveTo(-L, a); x.lineTo(L, a); x.stroke(); } x.restore(); var g = x.createRadialGradient(W * r(), H * r(), 0, W / 2, H / 2, L * .7); g.addColorStop(0, 'rgba(' + c.a + ',.24)'); g.addColorStop(1, 'rgba(' + c.a + ',0)'); x.fillStyle = g; x.fillRect(0, 0, W, H); },
    function cintas(x, W, H, r, c) { for (var i = 0; i < 4; i++) { var y0 = H * r(), y1 = H * r(), g = Math.max(W, H) * (.05 + r() * .09); x.strokeStyle = 'rgba(' + (i === 1 ? c.a : c.t) + ',' + (.07 + r() * .08) + ')'; x.lineWidth = g; x.lineCap = 'round'; x.beginPath(); x.moveTo(-g, y0); x.bezierCurveTo(W * .3, y0 + H * (r() - .5) * .9, W * .7, y1 + H * (r() - .5) * .9, W + g, y1); x.stroke(); } }
  ];

  function estilo(semilla) { var r = azar(semilla), p = PALETAS[Math.floor(r() * PALETAS.length)], d = Math.floor(r() * DISENOS.length); return { paleta: p, diseno: d, oscuro: !!p[3], tinta: p[3] ? TINTA_CLARA : TINTA_OSCURA, acento: p[2], r: r }; }

  function pintarFondoCtx(x, W, H, semilla) {
    var e = estilo(semilla), r = e.r, p = e.paleta, ang = r() * 6.283, cx = W / 2, cy = H / 2, L = Math.hypot(W, H) / 2;
    var g = x.createLinearGradient(cx - Math.cos(ang) * L, cy - Math.sin(ang) * L, cx + Math.cos(ang) * L, cy + Math.sin(ang) * L); g.addColorStop(0, p[0]); g.addColorStop(1, p[1]);
    x.fillStyle = g; x.fillRect(0, 0, W, H);
    DISENOS[e.diseno](x, W, H, r, { t: e.oscuro ? '255,255,255' : rgb(p[2]), a: rgb(p[2]) });
    return e;
  }
  function pintarFondo(canvas, semilla) { return pintarFondoCtx(canvas.getContext('2d'), canvas.width, canvas.height, semilla); }

  function partir(x, texto, ancho) { var pal = texto.split(/\s+/), lin = [], act = ''; pal.forEach(function (w) { var pr = act ? act + ' ' + w : w; if (act && x.measureText(pr).width > ancho) { lin.push(act); act = w; } else act = pr; }); if (act) lin.push(act); return lin; }
  function iniciales(n) { var p = String(n || '').trim().split(/\s+/).filter(Boolean); return ((p[0] || 'T')[0] + (p[1] ? p[1][0] : '')).toUpperCase(); }

  /* Imagen completa lista para compartir: fondo + frase + nombre del negocio. */
  function imagen(o) {
    var W = o.w || 1080, H = o.h || 1920, c = document.createElement('canvas'); c.width = W; c.height = H; var x = c.getContext('2d');
    var e = pintarFondoCtx(x, W, H, o.semilla), m = W * .1, F = '"Bricolage Grotesque", "Instrument Sans", system-ui, sans-serif', alto = H > W * 1.5, ancho = W > H;
    var y0 = H * (alto ? .2 : ancho ? .2 : .14), y1 = H * (alto ? .74 : ancho ? .63 : .72), cajaH = y1 - y0, tam = Math.round(W * (alto ? .092 : ancho ? .056 : .07)), lin;
    do { x.font = '800 ' + tam + 'px ' + F; lin = partir(x, o.texto, W - m * 2); tam -= 2; } while ((lin.length * tam * 1.2 > cajaH - tam * 1.4 || lin.some(function (l) { return x.measureText(l).width > W - m * 2; })) && tam > 26);
    tam += 2; x.font = '800 ' + tam + 'px ' + F; var bloque = lin.length * tam * 1.2, ty = y0 + (cajaH - bloque) / 2 + tam * .5;
    x.fillStyle = e.acento; x.font = '800 ' + Math.round(tam * 2.6) + 'px Georgia, serif'; x.textAlign = 'left'; x.textBaseline = 'alphabetic'; x.fillText('“', m - tam * .08, ty - tam * .1);
    x.fillStyle = e.tinta; x.font = '800 ' + tam + 'px ' + F; x.textBaseline = 'top';
    lin.forEach(function (l, i) { x.fillText(l, m, ty + tam * .5 + i * tam * 1.2); });
    x.fillStyle = e.acento; x.fillRect(m, ty + tam * .5 + bloque + tam * .5, W * .16, Math.max(6, W * .009));
    if (o.marca) {
      var R = W * (ancho ? .04 : .058), by = H * (alto ? .86 : .87), nomT = Math.round(W * (ancho ? .034 : .046));
      x.fillStyle = e.acento; x.beginPath(); x.arc(m + R, by, R, 0, 7); x.fill();
      x.fillStyle = TINTA_OSCURA; x.font = '800 ' + Math.round(R * .82) + 'px ' + F; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(iniciales(o.marca), m + R, by + R * .04);
      x.fillStyle = e.tinta; x.textAlign = 'left'; x.font = '800 ' + nomT + 'px ' + F; var maxN = W - m * 2 - R * 2.5; while (x.measureText(o.marca).width > maxN && nomT > 22) { nomT -= 2; x.font = '800 ' + nomT + 'px ' + F; }
      x.fillText(o.marca, m + R * 2.5, by - (o.pie ? nomT * .42 : 0));
      if (o.pie) { x.globalAlpha = .82; x.font = '500 ' + Math.round(W * (ancho ? .022 : .03)) + 'px ' + F; x.fillText(o.pie, m + R * 2.5, by + nomT * .62); x.globalAlpha = 1; }
    }
    x.globalAlpha = .6; x.fillStyle = e.tinta; x.textAlign = 'right'; x.textBaseline = 'alphabetic'; x.font = '600 ' + Math.round(W * .024) + 'px ' + F; x.fillText('Hecho con Ventas Link', W - m, H - W * .045); x.globalAlpha = 1;
    return c;
  }

  /* Elige una frase sin repetir la última. cats: ['ventas','network','vida'] */
  function frase(cats, llave) {
    var lista = []; (cats || ['vida']).forEach(function (k) { (FRASES[k] || []).forEach(function (t) { lista.push({ texto: t, cat: k }); }); });
    var ult = -1, i; try { ult = parseInt(localStorage.getItem(llave || 'vl-frase'), 10); } catch (e) { ult = -1; }
    do { i = Math.floor(Math.random() * lista.length); } while (i === ult && lista.length > 1);
    try { localStorage.setItem(llave || 'vl-frase', String(i)); } catch (e) { /* sin almacenamiento */ }
    return lista[i];
  }

  /* Comparte la imagen (estados de WhatsApp, redes) o la descarga si el navegador no puede compartir archivos. */
  function compartir(canvas, nombre, texto) {
    return new Promise(function (ok) {
      canvas.toBlob(function (b) {
        if (!b) { ok('error'); return; }
        var f = new File([b], nombre || 'frase-ventas-link.png', { type: 'image/png' }), datos = { files: [f] }; if (texto) datos.text = texto;
        if (navigator.canShare && navigator.canShare({ files: [f] })) { navigator.share(datos).then(function () { ok('compartido'); }).catch(function () { ok('cancelado'); }); return; }
        var a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = f.name; document.body.appendChild(a); a.click(); a.remove(); setTimeout(function () { URL.revokeObjectURL(a.href); }, 4000); ok('descargado');
      }, 'image/png');
    });
  }
  function conFuente() { return document.fonts && document.fonts.load ? document.fonts.load('800 48px "Bricolage Grotesque"').catch(function () { /* sin fuente: se usa la del sistema */ }) : Promise.resolve(); }

  G.VL_ARTE = { FRASES: FRASES, PALETAS: PALETAS, DISENOS: DISENOS.length, nuevaSemilla: nuevaSemilla, estilo: estilo, pintarFondo: pintarFondo, pintarFondoCtx: pintarFondoCtx, imagen: imagen, frase: frase, compartir: compartir, conFuente: conFuente };
})(typeof window !== 'undefined' ? window : globalThis);
