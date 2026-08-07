# Handoff: Banner «Inntuitivo Academy» — para Claude Code

## Overview
Sección nueva para la landing de Inntuitivo (`www.inntuitivo.com`): un banner que invita a consumir el contenido educativo gratuito del canal de YouTube (IA, tecnología y emprendimiento). Va **como última sección antes del footer**, inmediatamente después del banner de Newsletter («☄️ La misión → Súmate en LinkedIn 🚀»), del que es hermano visual: misma anatomía (eyebrow → título → párrafo → CTA único, centrado, tarjeta sobre fondo oscuro espacial).

Objetivo del usuario: un clic al canal de YouTube. No hay formulario, no hay segundo CTA.

## About the Design Files
Los archivos de este bundle son **referencias de diseño hechas en HTML**: un prototipo que muestra el aspecto y el comportamiento deseados, **no código de producción para pegar tal cual**.

La tarea es **recrear el diseño dentro del entorno real del sitio**, con sus patrones, componentes y variables CSS existentes — las mismas que usa el banner de Newsletter. Los tokens `--ac-*` que declara el prototipo existen sólo para que el archivo sea autocontenido; hay que **mapearlos a las variables reales del sitio**, no duplicarlos.

Nota de contexto: el diseño se hizo leyendo el contenido publicado del sitio y el libro de marca, **sin acceso a su hoja de estilos**. Los valores de fondo, superficie y stack de cuerpo son aproximaciones del render. Donde el sitio ya tenga un token equivalente, **gana el del sitio**.

## Fidelity
**Alta fidelidad (hifi).** Colores, tipografías, escalas, espaciados, estados y keyframes son finales. Recrear pixel-perfect con las librerías y patrones del sitio, con la salvedad de tokens del párrafo anterior.

## Screens / Views

### Banner «Inntuitivo Academy» (única vista)

**Purpose:** el usuario lee qué es Academy y hace clic para ir al canal de YouTube (nueva pestaña).

**Layout desktop (≥768px)**
- `<section>`: `padding: 96px 24px`, fondo `--ac-bg` (`#0A0614`).
- Tarjeta: `max-width: 880px`, centrada (`margin: 0 auto`), `padding: 64px 56px`, `border-radius: 24px`, `border: 1px solid rgba(255,255,255,.10)`, `background: #120B21`, `overflow: hidden`, `position: relative`.
- Contenido: `display:flex; flex-direction:column; align-items:center; gap:20px; text-align:center; position:relative; z-index:1`.

**Layout móvil (<768px)** — mobile-first, el banner completo entra en 390×844 sin empujar el CTA fuera del viewport (altura total ≈ 470–500px).
- Sección: `padding: 56px 16px`. Tarjeta: `padding: 40px 20px`, `border-radius: 20px`. `gap: 16px`.

**Components**

1. **Eyebrow** — `🔭 ACADEMY`
   - Font: `--ac-font-body` (Century Gothic), 700.
   - Desktop 13px / `letter-spacing:.16em`; móvil 12px / `.14em`.
   - `text-transform: uppercase`, color `#F04E77`.
   - Sin estados.

2. **Título** — `Inntuitivo Academy 👨‍🚀`
   - Font: **Audiowide** 400.
   - Desktop `clamp(2rem, 5.2vw, 3.25rem)`, `line-height: 1.14`, `letter-spacing: -.01em`, `text-wrap: balance`.
   - Móvil **28px fijo** (no clamp), `line-height: 1.2`. Cae en dos líneas: `Inntuitivo` / `Academy 👨‍🚀`.
   - Color `#FFFFFF`. Semántica `<h2 id="academy-title">` (alinear al nivel que use el banner de Newsletter).
   - El emoji va envuelto en `<span class="academy__astronaut" aria-hidden="true">` — es el elemento animado.

3. **Subtítulo**
   - Texto exacto: `Contenido gratis en IA, tecnología y emprendimiento para potenciar tu negocio y llevarlo a órbita 🪐`
   - Desktop 17px / `line-height 1.65`; móvil 16px / `1.6`.
   - `max-width: 52ch`, color `rgba(255,255,255,.72)`, `text-wrap: pretty`.

4. **CTA** — `Ver el contenido en YouTube 🚀`
   - `<a href="https://www.youtube.com/@inntuitivo" target="_blank" rel="noopener">`.
   - Pill: `border-radius: 999px`, `min-height: 56px` (móvil 52px), `padding: 0 34px` (móvil 0 20px), `width: 100%` en móvil.
   - Font body 700, 17px (móvil 16px), color `#FFFFFF`.
   - Fondo: `linear-gradient(90deg,#DE0540 0%,#452774 100%)`.
   - `box-shadow: 0 8px 28px rgba(222,5,64,.22)`.
   - **hover**: `transform: translateY(-2px)`, sombra `0 12px 34px rgba(222,5,64,.34)`.
   - **active**: `transform: translateY(0)`.
   - **focus-visible**: `outline: 3px solid #FFF; outline-offset: 3px`. Nunca `outline:none`.
   - `transition: transform .18s ease, box-shadow .18s ease`.
   - En 390px el texto entra en una línea; si el stack real es más ancho, bajar a 15px antes que romper en dos líneas.

5. **Decoración de marca** (dos pseudo-elementos de la tarjeta, ambos no interactivos)
   - `::before` — filo de gradiente: `inset: 0 0 auto 0; height: 3px; background: var(--ac-gradient)`.
   - `::after` — halo: `inset: -40% -10% auto -10%; height: 340px;`
     `background: radial-gradient(ellipse at 50% 0%, rgba(222,5,64,.28) 0%, rgba(69,39,116,.22) 45%, transparent 72%);`
     `pointer-events: none`.
   - El fondo de la tarjeta **no** lleva gradiente: superficie sólida, como el banner de Newsletter.

## Interactions & Behavior

- **Único handler**: el CTA abre `https://www.youtube.com/@inntuitivo` en nueva pestaña (`target="_blank" rel="noopener"`). Sin router, sin modal.
- **Animación — astronauta flotando.** Sólo `transform`. Nada que anime layout (`left`, `top`, `margin`, `width`), ningún filtro. Sin video, Lottie ni GIF: CSS puro sobre el emoji de texto.

```css
.academy__astronaut{
  display:inline-block;          /* imprescindible: transform no aplica a inline */
  will-change:transform;
  animation:ac-float 5.5s ease-in-out infinite;
}
@keyframes ac-float{
  0%,100%{ transform:translate3d(0,0,0)     rotate(0deg)  }
  50%    { transform:translate3d(0,-10px,0) rotate(-4deg) }
}
@media (max-width:767px){          /* recorrido más corto en móvil */
  @keyframes ac-float{
    0%,100%{ transform:translate3d(0,0,0)    rotate(0deg)  }
    50%    { transform:translate3d(0,-7px,0) rotate(-3deg) }
  }
}
.academy:not(.is-visible) .academy__astronaut{ animation-play-state:paused }
@media (prefers-reduced-motion:reduce){
  .academy__astronaut{ animation:none }
  .academy__cta{ transition:none }
  .academy__cta:hover{ transform:none }
}
```

- **Pausa fuera del viewport** — IntersectionObserver, `threshold: 0.15`, sólo togglea una clase (no toca estilos inline):

```js
var el = document.getElementById('academy');
if (el && 'IntersectionObserver' in window) {
  new IntersectionObserver(function(entries){
    entries.forEach(function(e){ el.classList.toggle('is-visible', e.isIntersecting); });
  }, { threshold: 0.15 }).observe(el);
} else if (el) { el.classList.add('is-visible'); }
```

Si el sitio ya tiene un observer compartido para animaciones de sección, **reusalo** en vez de instanciar otro.

- No animar el 🪐 del subtítulo ni el 🚀 del CTA. Un solo elemento en movimiento.
- Sin estados de carga ni de error: la sección es estática.

## State Management
Ninguno. Es una sección presentacional sin datos, sin formulario y sin estado de aplicación. La única variable es la clase `is-visible` en el nodo de la sección, gobernada por el IntersectionObserver.

## Design Tokens

**Color**
| Token | Valor | Uso |
|---|---|---|
| `--ac-brand-red` | `#DE0540` | libro de marca |
| `--ac-brand-purple` | `#452774` | libro de marca |
| `--ac-gradient` | `linear-gradient(90deg,#DE0540 0%,#452774 100%)` | CTA, filo superior |
| `--ac-bg` | `#0A0614` | fondo de sección → mapear al del sitio |
| `--ac-surface` | `#120B21` | tarjeta → mapear al del banner de Newsletter |
| `--ac-hairline` | `rgba(255,255,255,.10)` | borde de tarjeta |
| `--ac-text` | `#FFFFFF` | título |
| `--ac-text-muted` | `rgba(255,255,255,.72)` | párrafo |
| `--ac-eyebrow` | `#F04E77` | rojo de marca aclarado por contraste |

**Espaciado** — 12 · 16 · 20 · 24 · 34 · 40 · 56 · 64 · 96 px.

**Tipografía** — display `Audiowide` 400; cuerpo `Century Gothic` (fallbacks `Questrial`, `URW Gothic`, `system-ui`) 400/700.
Escala: eyebrow 13/12 · subtítulo 17/16 · CTA 17/16 · título `clamp(2rem,5.2vw,3.25rem)` / 28px.

**Radios** — `24px` tarjeta desktop · `20px` tarjeta móvil · `999px` CTA.

**Sombras** — `0 8px 28px rgba(222,5,64,.22)` (CTA reposo) · `0 12px 34px rgba(222,5,64,.34)` (hover).

**Motion** — `5.5s ease-in-out infinite` (flotación) · `.18s ease` (CTA).

## Accessibility
- Contraste sobre `#120B21`: título blanco **17.6:1** · subtítulo **≈9.5:1** · eyebrow `#F04E77` **≈5.6:1** (el `#DE0540` puro queda en ~4.1:1 a 13px, de ahí el aclarado). Blanco sobre el CTA: **5.0:1** en el extremo rojo, más en el morado — AA para 17px bold.
- Focus visible obligatorio en el CTA (ver specs). Si el sitio tiene token de focus, usar ese.
- `<section aria-labelledby="academy-title">`.
- Astronauta en `<span aria-hidden="true">`: decoración, no debe leerse. Los emojis del eyebrow, subtítulo y CTA sí se leen, como en el resto del sitio.
- `prefers-reduced-motion: reduce` apaga animación y transiciones por completo.

## Content (verbatim — no reescribir)
- Eyebrow: `🔭 ACADEMY`
- Título: `Inntuitivo Academy 👨‍🚀`
- Subtítulo: `Contenido gratis en IA, tecnología y emprendimiento para potenciar tu negocio y llevarlo a órbita 🪐`
- CTA: `Ver el contenido en YouTube 🚀` → `https://www.youtube.com/@inntuitivo`

Reglas de copy: tuteo, nunca voseo. Prohibidas las palabras «solución», «sinergia», «transformación digital». Sin claims no comprobables — nada de cantidad de cursos, certificados ni frecuencia de publicación. Sólo lo cierto hoy: hay contenido, es gratis, está en YouTube.

## Assets
Ninguno. Sin imágenes, sin iconos, sin SVG. Todos los emojis son **texto**, no imágenes. Audiowide se carga desde Google Fonts (el sitio ya la usa: no agregar fuentes nuevas).

## Files
- `academy-banner.html` — prototipo de referencia autocontenido (abrir en el navegador para ver diseño y animación).
- `README.md` — spec de diseño en formato del handoff de Partners (tokens, desktop, móvil, animación, accesibilidad).
- `HANDOFF_CLAUDE_CODE.md` — este documento.
