# ESTADO — Tienda digital con pedidos por WhatsApp (nombre provisional)
Última actualización: 2026-11-14 | Sesión actual: 1

⏸️ CHECKPOINT — Última acción completada: reporte de validación aprobado; usuario eligió construir ya (opción 2). / Siguiente acción exacta: PREGUNTA DE REFERENCIA visual (54, PASO 0) y luego Plan Maestro (B5).

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
- FICHA-ARTE.md: NO existe
- ¿Referencia visual del usuario?: pendiente de preguntar

## Avatar y venta
- FICHA-AVATAR.md: NO existe (obligatoria antes de la página de ventas)

## Estrategia de monetización
- Pendiente de decidir (matriz 02C). Hipótesis del usuario arriba.

## Constitución del producto (derivada del PDF)
- Primera victoria: el vendedor publica su primer producto y abre su enlace de tienda funcionando en pocos minutos
- 3 funciones del MVP: catálogo + enlace único · pedido por WhatsApp prellenado · panel de pedidos del vendedor
- Reglas "nunca": no simular cobros/integraciones; no cobrar al terminar la prueba; no mostrar datos de un vendedor a otro; no publicar teléfono/ubicación sin consentimiento; no afirmar que el pedido está confirmado al enviar el mensaje

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
