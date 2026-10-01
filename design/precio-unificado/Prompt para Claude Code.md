# Prompt para Claude Code — sección de Precio de inntuitivo.com

Repo: rrojasa0684/inntuitivo-landing

Adjunto `Precio Unificado.html`. Es el diseño aprobado para la sección "✨ Precio". Impleméntalo en la landing respetando el código y los estilos actuales del sitio (no copies los estilos inline del mockup tal cual; tradúcelos a las clases/CSS existentes).

## 1. Unificar las dos tablas en una sola tarjeta
- La tabla comparativa (Apollo, Lusha, Hunter / Contratar un vendedor / Inntuitivo) y el bloque "Un precio por agente 🚀" ($65) deben vivir dentro de **una misma tarjeta** con borde degradado #DE0540 → #452774.
- Parte 1: "1 · Lo que cuesta cada opción" (tabla). Parte 2: "2 · Tu plan" (precio, beneficios, botón). Separadas por una línea interna, no por dos tarjetas distintas.
- Columna de Inntuitivo resaltada (fondo rgba(222,5,64,.10)).
- Mantén la versión móvil en tarjetas por columna que ya existe, pero dentro de la misma tarjeta.

## 2. Un solo botón "Activar mi agente"
- Elimina el botón "Activar mi agente 🤖" que está debajo de la tabla comparativa (hoy apunta a `#precio`).
- Queda solo el botón del plan: "Activar mi agente 🚀" → `https://api.inntuitivo.com/suscribir`.

## 3. Anclas de los botones "Activar"
- Pon `id="activar"` en el bloque "2 · Tu plan" (no en la tabla).
- Todos los "Activar mi agente" del sitio (nav, hero, Mercately) deben llevar a `#activar`, es decir al plan/checkout, no al benchmark de competencia.

## 4. Encabezado de la sección
- Sin cambios de texto: "✨ / Precio / Una inversión, no un empleado / No comparamos qué tan buena es cada herramienta…".
- Alineado a la izquierda.

## 5. Nota de precios verificados
- Muévela al pie de la tarjeta unificada.
- Quita el link a GitHub (`precio-competencia-check.sh`). Ese script es interno y no debe enlazarse públicamente.
- Texto: "Precios de Apollo, Lusha y Hunter verificados el {fecha} contra sus páginas públicas (plan de entrada, facturación mensual, sin compromiso anual). ¿Ves un precio viejo? Avísanos." → "Avísanos" = `mailto:info@inntuitivo.com?subject=Precio%20desactualizado`.

## 6. Actualización automática de precios
- Mueve los precios de la competencia y la fecha de verificación a un archivo de datos (p. ej. `precios-competencia.json`) que la tabla y la nota lean.
- Crea un GitHub Action programado (semanal) que corra `precio-competencia-check.sh`:
  - Si los precios no cambiaron, actualiza solo la fecha de verificación y hace commit.
  - Si cambiaron o el script falla, abre un Issue/PR con el diff para revisión (no publicar precios automáticamente sin revisión).
- La fecha que se muestra en el sitio sale de ese JSON.

## Marca
- Tipografía: Audiowide (títulos y precios), Century Gothic (texto; fallback Jost).
- Colores: #DE0540, #452774, #FFFFFF.
