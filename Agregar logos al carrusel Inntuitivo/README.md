# Handoff: Carrusel de partners — Inntuitivo

## Overview
Sección de prueba social para la landing de inntuitivo.com: un carrusel infinito (marquee) con los logos de los partners, programas y plataformas que respaldan a Inntuitivo. Título, párrafo y una cinta de logos que se desplaza en loop, se pausa al hacer hover y resalta el logo apuntado.

## About the Design Files
Los archivos de este bundle son **referencias de diseño creadas en HTML** — un prototipo del look y el comportamiento buscados, no código de producción para copiar tal cual. La tarea es **recrear este diseño dentro del entorno del sitio real** (el stack actual de inntuitivo.com) usando sus patrones, sus utilidades de estilo y sus fuentes ya cargadas. El HTML adjunto sirve como especificación visual y de comportamiento.

Importante: el diseño se construyó **sin acceso al CSS de inntuitivo.com**. La paleta y las tipografías salen del libro de marca (adjunto). Al implementarlo, **reemplazar los valores de color/tipografía por los tokens reales del sitio** cuando existan equivalentes, y ajustar el fondo de la sección al de la sección vecina para que no rompa el flujo.

## Fidelity
**High-fidelity.** Colores, espaciados, tamaños tipográficos, tiempos de animación y estados están definidos y deben recrearse con precisión, adaptando los tokens al design system del sitio.

## Screens / Views

### Sección "Partners"
- **Purpose**: dar respaldo/credibilidad. No tiene interacción de conversión; solo hover.
- **Ubicación recomendada en la landing**: inmediatamente después del hero (antes de "Hecho para ti si tus clientes son empresas como") — o, como alternativa, entre "Quién construye tu agente" y "Muestra gratis".
- **Layout**:
  - `<section>` a todo el ancho, `position: relative`, `overflow: hidden`.
  - Padding vertical: `84px` arriba, `88px` abajo. Sin padding lateral (la cinta sangra a los bordes).
  - Borde superior e inferior de 1px (hairline) para coser la sección con las vecinas.
  - Contenedor de texto: `max-width: 1200px`, `margin: 0 auto`, `padding: 0 32px`, flex column, `align-items: center`, `gap: 18px`.
  - Cinta de logos: `margin-top: 60px`.
- **Components**:
  1. **Pill / eyebrow** — texto `🪐 Partners`. Inline-flex, `padding: 7px 16px`, `border-radius: 999px`, borde 1px `rgba(255,255,255,.16)`, fondo `rgba(255,255,255,.06)`, color `#E9E2F7`, `font-size: 13px`, `letter-spacing: .12em`, `text-transform: uppercase`.
  2. **Título (h2)** — `Quienes impulsan a Inntuitivo 🚀`. Audiowide 400, `font-size: 34px`, `line-height: 1.3`, color `#FFFFFF`, centrado, `text-wrap: balance`.
  3. **Párrafo** — `Empresas, startups, inversionistas, programas, plataformas y equipos con los que trabajamos para poner tu agente de IA en órbita. 🪐`. Questrial 400, `font-size: 17px`, `line-height: 1.6`, color `rgba(233,226,247,.72)`, `max-width: 620px`, centrado, `text-wrap: pretty`.
  4. **Marquee** — wrapper con `mask-image: linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent)` (y `-webkit-mask-image`) para que los logos se desvanezcan en los bordes. Track `display: flex; width: max-content` con **dos copias idénticas** de la lista de logos (la segunda con `aria-hidden="true"` y `alt=""`).
  5. **Logo item** — `flex: 0 0 auto`; `gap: 88px` entre logos y `padding-right: 88px` al final de cada copia. Imagen: `height: 56px; width: auto; display: block; opacity: .55`.
  6. **Estrellas de fondo** (solo tema oscuro) — 9 puntos blancos de 2–3px, `border-radius: 50%`, posicionados en % dentro de la sección, con animación `twinkle` de 4s y delays escalonados. Más un halo: elipse de 900×420px centrada arriba (`top: -260px`), `radial-gradient(closest-side, rgba(222,5,64,.28), transparent 70%)`, `filter: blur(10px)`.

## Interactions & Behavior
- **Marquee**: `@keyframes marquee { from { transform: translate3d(0,0,0) } to { transform: translate3d(-50%,0,0) } }`, `animation: marquee 69s linear infinite`. El `-50%` funciona porque el track contiene la lista duplicada exactamente dos veces: el loop es invisible.
- **Hover de logo** (como en producción): la cinta se detiene (`animation-play-state: paused` en el track al hacer hover sobre el wrapper) y el logo apuntado sube de `opacity: .55` a `1`, con transición `.35s ease`. El logo **no** escala.
- `pausaEnHover: false` desactiva solo la pausa (el logo sigue aclarándose).
- **Twinkle**: `@keyframes twinkle { 0%,100% { opacity: .25 } 50% { opacity: .9 } }`, 4s ease-in-out infinite.
- **Accesibilidad**: bajo `@media (prefers-reduced-motion: reduce)` se desactivan ambas animaciones (`animation: none`). La segunda copia de logos está oculta a lectores de pantalla.
- **Responsive**: la cinta ya funciona a cualquier ancho. En móvil (<768px) bajar la altura de logo a ~40px, el gap a ~48px, el título a ~26px y el padding vertical a ~56/60px.

## State Management
Ninguno. Es una sección estática con animación CSS. En el prototipo hay props configurables (ver Design Tokens → Props) que en producción pueden ser constantes o campos del CMS.

## Design Tokens

### Colores (libro de marca Inntuitivo)
| Token | Valor |
|---|---|
| Morado marca | `#452774` |
| Magenta marca | `#DE0540` |
| Blanco | `#FFFFFF` |
| Fondo oscuro (base) | `#0B0616` |
| Fondo oscuro (medio) | `#1B0E33` |
| Texto secundario oscuro | `rgba(233,226,247,.72)` |
| Hairline oscuro | `rgba(255,255,255,.08)` |
| Fondo tema claro | `linear-gradient(180deg, #FFFFFF 0%, #F6F3FB 100%)` |
| Título tema claro | `#241540` |
| Texto secundario claro | `rgba(36,21,64,.66)` |
| Hairline claro | `rgba(69,39,116,.12)` |

Fondo de la sección (tema oscuro): `radial-gradient(120% 90% at 50% 0%, #452774 0%, #1B0E33 45%, #0B0616 100%)`.

### Tipografía
- **Títulos**: Audiowide 400 (fuente del logotipo Inntuitivo, Google Fonts).
- **Cuerpo**: Century Gothic según libro de marca; en web se usa **Questrial 400** como sustituto (Google Fonts). Si el sitio ya carga otra fuente de cuerpo, usar esa.
- Escala usada: 34px / 1.3 (h2), 17px / 1.6 (párrafo), 13px + .12em tracking (eyebrow).

### Espaciado
32 (padding lateral) · 18 (gap del bloque de texto) · 60 (texto → cinta) · 84/88 (padding vertical de la sección) · 88 (gap entre logos).

### Otros
- Border radius: `999px` (pill). Los logos no llevan radio ni sombra.
- Duración de animación: 69s (marquee, escalada de 46s a 15 logos para mantener la misma velocidad de desplazamiento), .35s (hover), 4s (twinkle).

### Rendimiento
- `will-change: transform` y `backface-visibility: hidden` en el track para mantenerlo en su propia capa de composición.
- Cada `<img>` lleva `width="600" height="200"` y `decoding="async"`: reserva el espacio (sin reflow al cargar) y evita bloquear el hilo principal.
- El halo superior es un `radial-gradient` puro, sin `filter: blur()` (el blur obliga a repintar una capa de 900×420 en cada frame en algunos navegadores).
- Los PNG están normalizados a 600×200 y reescalados por pasos (halving progresivo) para que se vean nítidos a 56px de alto en pantallas retina.

### Props del prototipo
| Prop | Default | Rango |
|---|---|---|
| `titulo` | Quienes impulsan a Inntuitivo 🚀 | texto |
| `subtitulo` | Empresas, startups, inversionistas, programas… 🪐 | texto |
| `tema` | Oscuro | Oscuro / Claro |
| `velocidad` | 69s | 15–120s |
| `alturaLogo` | 56px | 32–90px |
| `opacidad` | 0.55 | 0.2–1 |
| `pausaEnHover` | true | true / false |

## Assets
Logos entregados como PNG con fondo transparente, todos normalizados a un lienzo de **600×200px** con el logo recortado a su bounding box, escalado a caber con 8px de padding y centrado — por eso alinean ópticamente sin ajustes manuales. Vienen en dos variantes:

- `logos/` — escala de grises (para fondos claros)
- `logos-blanco/` — versión blanca invertida (para fondos oscuros)

Archivos (mismo nombre en ambas carpetas): `aws.png`, `microsoft-founders-hub.png`, `google-for-startups.png`, `openai.png`, `claude.png`, `grok.png`, `n8n.png`, `hubspot-for-startups.png`, `neural-coders.png`, `mural.png`, `miro.png`, `scrumstudy.png`, `advice-legal.png`, `bridge-for-billions.png`, `catalitec.png`.

Nota sobre `miro.png` (versión blanca): el cuadro amarillo de Miro se resolvió como blanco con opacidad proporcional al tono original (en vez de invertir la luminancia), para que el contenedor no quede oscuro sobre fondo oscuro.

Origen: archivos originales a color provistos por el cliente, convertidos a B/N y normalizados. Si en algún momento consiguen los SVG oficiales de cada partner, conviene sustituirlos (los originales eran mapas de bits, no hay vectores que extraer).

Orden en la cinta: AWS → Microsoft Founders Hub → Google for Startups → OpenAI → Claude → Grok → n8n → HubSpot → Neural Coders → Mural → Miro → SCRUMstudy → Advice Legal → Bridge for Billions → Catalitec.

## Files
- `Carrusel Partners.dc.html` — el prototipo completo (markup + estilos + lógica de tema/velocidad).
- `logos/` y `logos-blanco/` — los assets listos para producción.
- `libro-de-marca.pdf` — manual de marca Inntuitivo (colores y tipografías oficiales).

## Prompt sugerido para Claude Code
> Implementá la sección "Partners" de inntuitivo.com siguiendo `design_handoff_carrusel_partners/README.md`. El HTML incluido es una referencia de diseño: recreálo con los patrones y tokens que ya existen en el repo del sitio, no lo pegues tal cual. Copiá `logos-blanco/` (o `logos/` si la sección va sobre fondo claro) a la carpeta de assets del proyecto. Colocá la sección justo después del hero. Respetá el marquee con duplicado de lista, la pausa en hover, el fade lateral por mask y `prefers-reduced-motion`. Ajustá el fondo para que empalme con la sección vecina.
