# IA de Ventas Link — cómo conectarla (en simple)

**La app funciona completa sin IA.** La IA solo ayuda a escribir textos (descripción de productos y publicaciones). Si no pones la llave, esos dos botones avisan que no están conectados y todo lo demás sigue igual.

La IA **ya está programada** y probada con una IA de mentira. Solo falta **tu llave** (como una contraseña que le dice a Anthropic que la cuenta es tuya y a quién cobrar).

## Qué hace hoy
- **Escribir con IA** (pantalla de producto): escribe la descripción del producto.
- **Mejorar con IA** (pantalla de compartir): reescribe el texto para WhatsApp, Instagram, Facebook o TikTok.
- Ya preparada (falta ponerle botón): mensaje de seguimiento al comprador y respuesta a una pregunta del cliente.
- Nunca inventa datos (talla, material, urgencia falsa) y solo usa lo que el vendedor escribió.

## Qué debes hacer tú (5 minutos)
1. Entra a **console.anthropic.com** y crea tu cuenta.
2. En **Billing** agrega un método de pago y una **recarga pequeña** (por ejemplo US$5) para probar. Define un **límite de gasto mensual** ahí mismo.
3. En **API keys** crea una llave nueva.
4. En la carpeta `servidor` copia `.env.example` como `.env` y pega la llave después de `ANTHROPIC_API_KEY=`.
   - ⚠️ **Nunca pegues la llave en el chat, en un correo ni en el código.** Solo en `.env` (este archivo no se sube a ningún lado).
   - Si alguna vez la pegas por error en un lugar público, bórrala en la consola y crea otra.
5. En una terminal: `cd servidor` y luego `npm start`. Abre http://localhost:3000.

## Qué modelo usa (ya elegido: Haiku, el más barato; se puede cambiar con `AI_MODEL` en `.env`)
Costo aproximado por texto (estimado: ~200 palabras de entrada y ~100 de salida; los precios cambian, revísalos en la consola):
| Modelo | Costo por texto | Para qué |
|---|---|---|
| `claude-haiku-5-5` | ~US$0,001 (una décima de centavo) | Textos cortos de tienda: rápido y baratísimo |
| `claude-sonnet-5-5` | ~US$0,005 | Equilibrio |
| `claude-opus-5-5` | ~US$0,01 a 0,02 | El más capaz; sobra para textos cortos |

## Cuidados de costo ya incluidos
- Tope por visitante: Gratis 5 por hora, Emprendedor 30, Profesional 100 (hipótesis, se ajusta con datos reales).
- Freno de emergencia: máximo de textos por día entre todos (`IA_MAX_DIARIO`, por defecto 200).
- El servidor guarda solo cifras (tokens), nunca los textos de tus clientes ni tu llave.

## Para publicarlo en internet (después)
Hay que subir esta carpeta a un servidor (por ejemplo Vercel o similar) y poner la llave en sus "variables de entorno". Allí también se valida la cuenta y el plan **en el servidor** (hoy el plan se envía desde la pantalla de demostración y no es confiable).
