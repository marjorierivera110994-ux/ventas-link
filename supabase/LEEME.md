# Base de datos de Ventas Link (Supabase)

Proyecto: `vqhkbijlnpjtklnlvvuf` (us-west-2, Postgres 17). Las migraciones de `migrations/` se aplican en orden por su fecha; una base vacía se reconstruye solo con ellas.

## Regla de oro
- **El público (sin cuenta) no tiene permiso sobre ninguna tabla** (salvo leer `planes`). Entra solo por funciones: `tienda_publica`, `crear_pedido`, `registrar_visita`, `slug_disponible` (y `registrar_evento` / `registrar_error` para medición y errores).
- **Cada vendedora ve y edita solo lo suyo** (RLS por `tiendas.owner_id = auth.uid()`), con permisos por columna.
- Lo que cuesta dinero o define el plan (`suscripciones`, `pedidos`, `contador_pedidos`) **no se escribe desde el navegador**: solo por funciones o por el servidor (`service_role`).

## Tablas
| Tabla | Qué guarda | Quién escribe |
|---|---|---|
| `planes` | Límites y precio de cada plan | Solo el dueño de la app |
| `tiendas` | Lo que el cliente ve de la tienda (nombre, enlace, WhatsApp, estilo) | La vendedora (el enlace `slug` no se cambia) |
| `tienda_privado` | Datos de cobro, metas y contador de pedidos | La vendedora (menos el contador) |
| `suscripciones` | Plan pagado y prueba gratis | Solo servidor / `iniciar_prueba()` |
| `secciones`, `productos` | Catálogo | La vendedora, con el tope de su plan |
| `pedidos`, `pedido_items` | Pedidos con copia de nombre y precio | Solo `crear_pedido()` y `actualizar_estado_pedido()` |
| `visitas_dia` | Visitas por día | Solo `registrar_visita()` |
| Almacén `media` | Fotos (JPG/PNG/WebP, máx. 4 MB), carpeta = id de la tienda | La vendedora, en su carpeta, con tope por plan |

## Funciones (se llaman con `supabase.rpc(...)`)
- `tienda_publica(p_slug)` → `{ tienda, secciones, productos, total_productos }` o `null`. Trae hasta 300 productos (falta paginar para catálogos más grandes). `precio_final` ya incluye la oferta vigente.
- `crear_pedido(p_slug, p_clave, p_items, p_nombre, p_entrega, p_pago, p_direccion, p_tel, p_nota, p_idioma)` → `{ id, numero, subtotal, moneda, repetido }`. `p_clave` = un uuid que el navegador crea UNA vez por pedido (si se reenvía, no duplica). `p_items` = `[{ producto_id, variante, cantidad }]`. **El precio nunca viaja desde el navegador.** Si esta llamada falla, igual se abre WhatsApp: registrar es secundario.
- `actualizar_estado_pedido(p_pedido, p_estado)` → `solicitado → confirmado → pagado → entregado` (o `cancelado`). Al entregar descuenta stock y devuelve `agotados`.
- `mi_plan()` → plan vigente, origen (`pagado`/`prueba`/`gratis`), vencimiento, límites y uso.
- `iniciar_prueba(p_plan)` → 7 días, una sola vez por tienda, sin tarjeta. Al vencer vuelve sola a `gratis`.
- `registrar_visita(p_slug)`, `slug_disponible(p_slug)`.

## Mensajes de error (vienen en `error.message`)
`LIMITE_PRODUCTOS`, `LIMITE_SECCIONES` (el tope va en `error.details`) · `FUNCION_DE_PAGO` · `OFERTA_FECHA_INVALIDA` · `SLUG_INVALIDO` · `PRUEBA_YA_USADA` · `PLAN_INVALIDO` · `SIN_TIENDA` · `NO_AUTENTICADO` · `TIENDA_NO_ENCONTRADA` · `PRODUCTO_NO_DISPONIBLE` · `SIN_STOCK` · `CANTIDAD_INVALIDA` · `VARIANTE_INVALIDA` · `CARRITO_INVALIDO` · `NOMBRE_INVALIDO` · `DIRECCION_INVALIDA` · `TELEFONO_INVALIDO` · `PAGO_INVALIDO` · `ENTREGA_INVALIDA` · `DEMASIADOS_PEDIDOS` · `PEDIDO_NO_ENCONTRADO` · `CAMBIO_NO_PERMITIDO`. Cada uno se traduce a un mensaje amable en pantalla; nunca se muestra el código al usuario.

## Prueba de seguridad
`pruebas/seguridad.sql` — 50 comprobaciones con dos vendedoras de mentira y un visitante. No deja datos (se deshace sola). Última corrida: 2026-11-16, 50 de 50 correctas. **Se corre tras cada cambio de la base.**

## Panel de la dueña
Funciones admin_* (resumen, vendedoras, costos, config, bitácora) solo responden a la cuenta que está en private.admins. Para agregar a la dueña: insert into private.admins (user_id) select id from auth.users where email = 'CORREO';
Función de servidor admin-usuarios: crea cuentas y enlaces de entrada (supabase/functions/admin-usuarios). Prueba: pruebas/panel.sql.

## Capa legal (2026-11-20)
- `consentimientos`: la vendedora acepta Términos + Privacidad con `registrar_consentimiento(p_version, p_origen)` (solo su cuenta; versión no futura).
- Función de servidor `borrar-cuenta` (supabase/functions/borrar-cuenta): la vendedora borra SU cuenta (pide `confirmo: ELIMINAR`); usa `cuenta_para_borrar(uid)` (solo servidor) para saber qué fotos borrar; la dueña no se borra desde ahí.
- Al borrar una tienda, su enlace queda retirado (`private.slugs_retirados`, solo huella sha256): `slug_disponible` dice no y crear la tienda da 23505.
- Al borrar una cuenta (`auth.users`), un disparador quita su correo de la bitácora del panel y deja un evento anónimo `cuenta_eliminada`.
- Retención (pg_cron `ventaslink-retencion`, diario 08:17 UTC): datos de contacto de compradores a los 12 meses, eventos 25 meses, errores 90 días, bitácora 25 meses (`private.aplicar_retencion()`).
- Prueba: pruebas/legal.sql (18 de 18).

## Mi camino al éxito + avisos push (2026-11-21)
- Migraciones `camino_avisos` y `camino_avisos_ajuste_texto`. Tablas: `camino_logros`, `camino_puntos`, `avisos_preferencias`, `push_suscripciones` (todas con RLS: cada vendedor solo LEE lo suyo), `private.avisos` (bandeja), `private.push_config` (llaves de firma y contraseña interna), `private.actividad`.
- Funciones para la app (con sesión): `mi_camino()`, `camino_nuevos()`, `camino_visto(ids)`, `guardar_meta_semanal(meta)`, `push_clave_publica()`, `push_guardar(...)`, `push_borrar(endpoint)`, `avisos_mias()`, `avisos_guardar(...)`, `avisos_probar()`. Para compradores: `registrar_consulta(slug, producto)`.
- Solo para la función de envío (service_role): `push_config_servidor()`, `push_guardar_llaves(...)`, `avisos_tomar(n)`, `avisos_resultado(...)`.
- Edge Function `enviar-avisos` (verify_jwt = false: se protege con la contraseña interna `x-vl-token`). Cron `ventaslink-avisos` cada minuto.
- Pruebas: `supabase/pruebas/camino_avisos.sql` y `node herramientas/prueba-webpush.mjs`.
