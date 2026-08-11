# Prompt para Claude Code

Copiá y pegá esto en Claude Code, dentro del repo de inntuitivo.com, con la carpeta `handoff-claude-code/` disponible.

---

En este repo está la landing de inntuitivo.com, que ya tiene la sección de partners ("Quienes impulsan a Inntuitivo") con un carrusel infinito de logos. **No rehagas la sección: solo agregá 5 logos nuevos y verificá dos detalles del hover.**

## 1. Assets

Copiá los 5 PNG de `handoff-claude-code/partners/` a la misma carpeta pública donde ya viven los logos actuales (en producción se sirven desde `/partners/`):

- `grok.png`
- `n8n.png`
- `miro.png`
- `bridge-for-billions.png`
- `catalitec.png`

Ya vienen normalizados igual que los 10 existentes: lienzo de 600×200 px, fondo transparente, logo recortado a su bounding box, escalado con 8 px de padding y centrado en ambos ejes, en versión blanca para fondo oscuro. No los reescales ni los recomprimas.

Si la sección alguna vez se usa sobre fondo claro, las versiones en escala de grises están en `handoff-claude-code/partners-gris/` (mismos nombres de archivo).

## 2. Orden en la cinta

Insertá los nuevos logos en **ambas copias** de la lista (la visible y la duplicada con `aria-hidden="true"`), en estas posiciones exactas:

| # | Logo | archivo | alt |
|---|---|---|---|
| 1 | AWS | `aws.png` | AWS for Startups |
| 2 | Microsoft Founders Hub | `microsoft-founders-hub.png` | Microsoft for Startups Founders Hub |
| 3 | Google for Startups | `google-for-startups.png` | Google for Startups |
| 4 | OpenAI | `openai.png` | OpenAI |
| 5 | Claude | `claude.png` | Claude |
| **6** | **Grok** ⟵ nuevo | `grok.png` | Grok |
| **7** | **n8n** ⟵ nuevo | `n8n.png` | n8n |
| 8 | HubSpot | `hubspot-for-startups.png` | HubSpot for Startups |
| 9 | Neural Coders | `neural-coders.png` | Neural Coders |
| 10 | Mural | `mural.png` | Mural |
| **11** | **Miro** ⟵ nuevo | `miro.png` | Miro |
| 12 | SCRUMstudy | `scrumstudy.png` | SCRUMstudy Authorized Training Partner |
| 13 | Advice Legal Studio | `advice-legal.png` | Advice Legal Studio |
| **14** | **Bridge for Billions** ⟵ nuevo | `bridge-for-billions.png` | Bridge for Billions |
| **15** | **Catalitec** ⟵ nuevo | `catalitec.png` | Catalitec |

En la copia duplicada, `alt=""` (como ya está hoy).

## 3. Velocidad del marquee

La cinta pasó de 10 a 15 logos, así que la duración de la animación tiene que escalar en la misma proporción para que la velocidad de desplazamiento se vea igual que hoy:

**46s → 69s** (`animation: marquee 69s linear infinite`).

Si el valor actual en el repo no es 46s, multiplicá el que haya por 1.5.

No toques el `translate3d(-50%, 0, 0)` de los keyframes: sigue funcionando porque las dos copias son idénticas.

## 4. Hover (verificar, no rediseñar)

El comportamiento correcto, el que ya tiene producción, es:

- Al pasar el mouse sobre el wrapper del marquee, la cinta se **detiene** (`animation-play-state: paused` en el track).
- El logo apuntado sube de `opacity: .55` a `1` con `transition: opacity .35s ease`. **No escala.**

⚠️ Un detalle que rompió esto en el prototipo y conviene revisar en el repo: si la opacidad base `.55` se aplica como **estilo inline** en cada `<img>`, gana sobre la regla `.logo-item:hover img { opacity: 1 }` y el logo nunca se aclara. La opacidad base debe vivir en el CSS (o en una custom property, ej. `--partner-op`), nunca inline.

## 5. Rendimiento

Con 15 logos el track mide ~7680 px, así que revisá que estén estas cuatro cosas:

- Cada `<img>` con `width="600" height="200"` y `decoding="async"` — reserva el espacio y evita reflow al cargar.
- `will-change: transform` y `backface-visibility: hidden` en el track.
- Nada de JS que reescriba el `src` o los estilos de las imágenes en cada render: fuerza redecodificar los 30 `<img>` y produce tirones.
- Evitar `filter: blur()` sobre capas grandes dentro de la sección; el halo superior se resuelve con un `radial-gradient` puro.

## 6. Copy

Sin cambios. El título de la sección sigue siendo **«Quienes impulsan a Inntuitivo 🚀»** y el párrafo queda tal cual está hoy.

## 7. Accesibilidad

Sin cambios: la segunda copia sigue con `aria-hidden="true"` y `alt=""`, y bajo `@media (prefers-reduced-motion: reduce)` el marquee y el parpadeo de estrellas quedan en `animation: none`.

## Referencia

`handoff-claude-code/Carrusel Partners.dc.html` es el prototipo con el resultado final (abrilo en el navegador). `handoff-claude-code/README.md` tiene la especificación completa de la sección: tokens, espaciados, tipografía y comportamiento. Ambos son referencia visual, no código para pegar.

## Entregable

Un solo commit con: los 5 PNG nuevos en la carpeta de assets, los 10 `<li>`/`<div>` nuevos (5 en cada copia de la lista) y el ajuste de duración a 69s. Mostrame el diff antes de aplicarlo.
