# ESTADO — Tienda digital con pedidos por WhatsApp (nombre provisional)
Última actualización: 2026-11-14 | Sesión actual: 1

⏸️ CHECKPOINT — Última acción completada: comparativa de 3 estilos (direcciones-abc.html) lista para que el usuario elija. / Siguiente acción exacta: usuario elige/combina/pide otras 3/ajusta; luego tour de la app y FICHA-ARTE.md.

## Qué es esta app (3 líneas máximo)
Plataforma web móvil: cada vendedor crea su tienda, comparte un enlace único y recibe pedidos armados por WhatsApp. El comprador no instala nada ni se registra. Para pequeños comercios de Ecuador (mercado inicial). Plan gratis permanente + planes mensuales (hipótesis).

## Promesa central
"Crea tu tienda, comparte tu enlace y recibe pedidos claros por WhatsApp." (Sin prometer más ventas ni automatizar WhatsApp.)
Documento fuente del usuario: C:\Users\User\Downloads\Prompt_maestro_app_tiendas_digitales.pdf (decisiones ya tomadas: ver abajo).

## Reporte de validación (Sesión 1)
- Veredicto: Viable con ajustes
- Referencias: Take App (plan gratis ilimitado sin comisión, premium ~$14/mes — datos del proveedor), Dukaan (~$14.99/mes int'l, quejas de soporte/comisiones), catálogo gratis de WhatsApp Business
- Oportunidad: pedidos ordenados + producto pensado para Ecuador (español cotidiano, pagos locales)
- Brecha Ecuador: no confirmada con evidencia; ninguna herramienta específica encontrada
- Precio de referencia del mercado: $0 (gratis) a ~$14-15/mes
- Riesgo principal: no validado que paguen $5.99-14.99 teniendo alternativas gratis. Usuario decidió construir igual y validar con los primeros usuarios.
- Cobros recurrentes Ecuador (sin confirmar con proveedores): Datafast / Paymentez parecen soportarlos; PayPhone probablemente no. El usuario debe aprobar proveedor.

## Decisiones ya tomadas por el usuario (PDF)
- Una tienda por vendedor; comprador entra por enlace, sin app ni cuenta
- Pedido = mensaje prellenado a WhatsApp del vendedor; pago/envío se acuerdan fuera de la app
- Prueba premium 7 días, luego plan gratis automático, SIN cobro automático
- Planes (hipótesis NO validadas): Gratis (10 productos) · $5.99 · $9.99 · $14.99
- Diseño: profesional, moderno, verde esmeralda + blanco/neutros (punto de partida; falta pregunta de referencia)
- Fuera del MVP: directorio de tiendas, app nativa, WhatsApp API oficial, pagos en la app, logística, IA
- No simular cobros ni integraciones: todo botón visible funciona o se marca como demostración

## Dirección de Arte (Sesión 2)
- FICHA-ARTE.md: NO existe (esperando elección del usuario)
- ¿Referencia visual del usuario?: NO — pidió "dame opciones" → Ruta de diseño: propuesta propia (3 estilos A/B/C)
- Comparativa: direcciones-abc.html (kit abc-v2) — A "Tienda de confianza" (claro crema + esmeralda #0E6B4F, Figtree) · B "Meta y racha" (oscuro #0F1715 + #34D399 + racha ámbar #FBBF24, Nunito) · C "Cuaderno de pedidos" (claro #FAF8F4 + coral #C73E22, Bricolage Grotesque + Instrument Sans)
- REFERENCIA DEL USUARIO (2026-11-14, CONTRATO de paleta): verde menta #A8DCC5 · amarillo verdoso #D5DF70 · beige #F2E9D8 · blanco #FFFFFF, más negro #131313 y coral #EF8767 de su misma captura (negro = botones y tarjeta de meta; coral = solo avisos). Capturas en docs/revisiones/referencia-paleta-1.jpg y -2.jpg. Aplicada en app-con-tus-colores.html (3 pantallas) y como estilo "D · Tus colores" en vista-pagina-ventas.html. Texto sobre menta/lima siempre negro (contraste). Pendiente: aprobación del usuario y FICHA-ARTE.md.
- Limitación: tabla de líderes (16 PASO 0.2bis) hecha de forma ligera; pares tipográficos tomados de la tabla 29; sin screenshot archivado en docs/revisiones (solo revisión en vivo)

## Avatar y venta
- FICHA-AVATAR.md: NO existe (obligatoria antes de la página de ventas)

## Estrategia de monetización
- Pendiente de decidir (matriz 02C). Hipótesis del usuario arriba.

## Constitución del producto (derivada del PDF)
- Primera victoria: el vendedor publica su primer producto y abre su enlace de tienda funcionando en pocos minutos
- 3 funciones del MVP: catálogo + enlace único · pedido por WhatsApp prellenado · panel de pedidos del vendedor
- Reglas "nunca": no simular cobros/integraciones; no cobrar al terminar la prueba; no mostrar datos de un vendedor a otro; no publicar teléfono/ubicación sin consentimiento; no afirmar que el pedido está confirmado al enviar el mensaje

## Gamificación y retención (pedido del usuario: crecimiento tipo Duolingo medido por ventas semana/mes)
- Decisión: DOS mecánicas separadas, nunca mezcladas
  (NOMBRE DE CARA AL USUARIO: "camino de éxito" — la palabra "racha" NO se usa en la app ni en el copy; decisión del usuario 2026-11-14)
  1. CAMINO DE ÉXITO semanal (antes "racha") de constancia (no diaria: un comercio no vende todos los días). Semana activa = el vendedor hizo ≥1 de: compartir su enlace, publicar/editar un producto, actualizar el estado de un pedido. Congelador semanal GANADO (no comprado). Reparación <48h. Nunca copy de culpa. Sube desde la semana 2.
  2. PROGRESO DE VENTAS con meta propia, semanal y mensual: barra hacia la meta que fija el vendedor, "tu mejor semana/mes", comparación SOLO contra sí mismo (sin rankings). "Ventas" = suma de subtotales de pedidos que el vendedor marca como entregados; se etiqueta "según tus pedidos registrados". La racha NUNCA se rompe por vender poco.
- Por qué: la app no ve pagos ni entregas (pago fuera de la app). Medir la racha en ventas la rompería por factores ajenos al vendedor y incentivaría marcar pedidos falsos. La racha premia lo que el vendedor controla; las ventas se celebran como progreso.
- Registro del pedido: se guarda al pulsar "Enviar pedido por WhatsApp" (estado "solicitado", no confirmado), para que el panel tenga datos aunque el vendedor no los copie.
- Plan: camino de éxito semanal + meta + récords en el plan Gratis (es el gancho); reportes de varios meses, estadísticas detalladas y mejora de fotos en planes de pago.
- Loop: Gatillo = aviso semanal accionable (máx 1-2/semana) → Acción = compartir enlace / atender pedido → Recompensa = barra de meta, hito, récord → Inversión = catálogo y pedidos acumulados.
- Pendiente para Sesión 4/5: validar con 24, 56 (momentos emocionales) y tabla de datos con permisos por vendedor.

## Requisitos nuevos del usuario (2026-11-14) — cosa juzgada salvo que él lo cambie
- Producto "se vende solo": el comprador de la app debe poder VER que funciona → la página de ventas incluye una tienda de DEMOSTRACIÓN interactiva (datos de ejemplo claramente marcados como demo) donde se prueba el catálogo, el carrito y el mensaje de WhatsApp
- Inicio del vendedor: sube nombre del negocio, descripción, servicios, catálogo; obtiene enlace para compartir en redes; el cliente final ve catálogo con precios
- Plan GRATIS: prueba con hasta 10 productos/fotos (fotos con límite de tamaño)
- Plan PAGADO (desde "Emprendedor"): MÁS fotos y espacio de catálogo + estadísticas + mejora de fotos (fondo blanco, recorte, luz/color) + plantillas para personalizar la foto del producto + colores y estilo del catálogo personalizables
- Diferenciador: resolver lo que las apps de la competencia hacen mal (quejas reales encontradas: soporte lento, comisiones ocultas, fallas de cobro, lentitud). Reglas de producto: cero comisión por venta, límites y precios siempre visibles, soporte por WhatsApp con tiempo prometido, carga rápida en celular, cancelación en 1 toque
- Aviso de alcance: mejora automática de fotos usa servicio externo con costo por foto → entra al gate de economía (40) antes de fijar cupos y precio; el PDF original lo dejaba fuera del MVP; se construye por fases (ver Plan)
- Fases del premium: F1 más fotos + estadísticas + colores/plantillas de catálogo; F2 recorte/fondo blanco/luz automático + plantillas de foto (cuando el costo por foto esté medido)

## Mejoras de producto aplicadas (desde el reporte de validación)
- Diferenciador 1: pedido ordenado (mensaje prellenado con productos, variantes, subtotal y aclaración de que no está confirmado)
- Diferenciador 2: hecho para Ecuador (español cotidiano; el mensaje puede indicar formas de pago que el vendedor acepta: transferencia, efectivo, Deuna, tarjeta)
- Plan Gratis permanente como gancho frente a Take App / catálogo gratis de WhatsApp
- Validación con los primeros usuarios: medir cuántos activan tienda, comparten enlace y reciben un pedido en 7 días

## Secuencia maestra de construcción
- Estado: ninguna etapa iniciada
- Ruta: `/` → `/onboarding` → `/paywall` → `/login` → `/app`

## Decisiones técnicas
- Pendientes (Sesión 1, se deciden y documentan aquí)

## Sesiones completadas ✅
- (ninguna)

## Sesión en progreso 🔧
- Sesión 1 — validación hecha; falta avatar, mercado, modelo, monetización, arquitectura

## Próximas sesiones 📋
- Ver Plan Maestro (INICIO B5), se presenta tras la pregunta de referencia

## Problemas conocidos ⚠️
- Hotmart es el cobro por defecto del SO, pero el usuario pidió elegir proveedor compatible con Ecuador y aprobarlo: conflicto a resolver en Sesión 1/6
- Python no está instalado en el equipo; algunas utilidades del SO pueden requerir Node (sí instalado)

## Pendientes del usuario
- [ ] Responder la pregunta de referencia visual
- [ ] (Después) crear cuentas de servicios cuando se le pida

## Notas para la próxima sesión
- SO instalado en C:\Users\User\Desktop\Xiomara\APP; git inicializado
