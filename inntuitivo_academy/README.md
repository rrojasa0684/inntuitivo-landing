# Handoff — Banner «Inntuitivo Academy»

Sección nueva para `www.inntuitivo.com`. Va **como última sección antes del footer**, después de «☄️ La misión / Súmate en LinkedIn». Es el hermano visual del banner de Newsletter: misma anatomía (eyebrow → título → párrafo → CTA único, centrado, tarjeta sobre fondo oscuro).

**Archivos**
- `academy-banner.html` — referencia autocontenida, abrila en el navegador para ver el diseño y la animación.
- Sin imágenes. Los emojis son texto.

> ⚠️ **Advertencia para quien implemente:** no pegues el HTML/CSS de `academy-banner.html` tal cual en el sitio. Es una **referencia visual**. Recreá la sección con los componentes, clases y variables CSS reales del sitio (las mismas que usa el banner de Newsletter), y mapeá los tokens de abajo a los existentes en vez de duplicarlos. El `<style>` del archivo declara tokens locales `--ac-*` sólo para que la referencia sea autocontenida.

> Nota: no recibí la captura del banner de Newsletter, así que la anatomía y el ritmo salen de la sección publicada en el sitio. Si el componente real tiene otro contenedor o paddings, ganan los del sitio.

---

## 1. Tokens

| Token de referencia | Valor | Origen / mapeo |
|---|---|---|
| `--ac-brand-red` | `#DE0540` | libro de marca |
| `--ac-brand-purple` | `#452774` | libro de marca |
| `--ac-gradient` | `linear-gradient(90deg,#DE0540 0%,#452774 100%)` | gradiente de marca |
| `--ac-bg` | `#0A0614` | fondo espacial del sitio → usar la variable existente |
| `--ac-surface` | `#120B21` | superficie de tarjeta → usar la del banner de Newsletter |
| `--ac-hairline` | `rgba(255,255,255,.10)` | borde de tarjeta |
| `--ac-text` | `#FFFFFF` | |
| `--ac-text-muted` | `rgba(255,255,255,.72)` | párrafo |
| `--ac-eyebrow` | `#F04E77` | rojo de marca aclarado para contraste (ver §4) |
| `--ac-font-display` | `Audiowide` | título |
| `--ac-font-body` | `Century Gothic` + stack del sitio | eyebrow, párrafo, CTA |
| `--ac-radius` | `24px` desktop · `20px` móvil | |

### Dónde vive el gradiente
Tres apariciones, en orden de peso, para que la marca se lea sin gritar sobre el tema oscuro:
1. **CTA**: relleno completo (`--ac-gradient`) — es el punto más brillante de la sección y el único elemento accionable.
2. **Filo superior de la tarjeta**: barra de `3px` a todo el ancho (`::before`).
3. **Halo**: radial muy tenue detrás del título (`::after`, rojo a `.28` → morado a `.22` → transparente). Decorativo, `pointer-events:none`.

El fondo de la tarjeta **no** lleva gradiente: se queda en superficie sólida, como el banner de Newsletter.

---

## 2. Especificación desktop (≥768px)

- Sección: `padding: 96px 24px`, fondo `--ac-bg`.
- Tarjeta: `max-width: 880px`, centrada, `padding: 64px 56px`, `border-radius: 24px`, `border: 1px solid --ac-hairline`, `overflow: hidden`.
- Contenido: columna flex centrada, `gap: 20px`.
- Eyebrow `🔭 ACADEMY`: 13px / 700 / `letter-spacing: .16em` / `text-transform: uppercase` / color `--ac-eyebrow`.
- Título `Inntuitivo Academy 👨‍🚀`: Audiowide 400, `clamp(2rem, 5.2vw, 3.25rem)`, `line-height 1.14`, `text-wrap: balance`.
- Subtítulo: 17px, `line-height 1.65`, `max-width: 52ch`, `--ac-text-muted`, `text-wrap: pretty`.
- CTA: pill (`border-radius: 999px`), `min-height: 56px`, `padding: 0 34px`, 17px/700, texto blanco sobre `--ac-gradient`, `box-shadow: 0 8px 28px rgba(222,5,64,.22)`.
  - hover: `translateY(-2px)` + sombra a `.34`. active: vuelve a `0`.

## 3. Especificación móvil (<768px) — mobile-first

Objetivo: **el banner completo entra en 390 × 844 sin empujar el CTA fuera del viewport.** Altura total de la sección en 390px ≈ **470–500px**, holgado dentro de un viewport útil de ~700px.

- Sección: `padding: 56px 16px`.
- Tarjeta: `padding: 40px 20px`, `border-radius: 20px`.
- `gap: 16px`.
- Eyebrow: 12px, `letter-spacing: .14em`.
- Título: **28px fijo** (no clamp), `line-height 1.2`. En 390px cae en dos líneas: `Inntuitivo` / `Academy 👨‍🚀` — el astronauta queda en la segunda línea, junto a la palabra.
- Subtítulo: 16px, `line-height 1.6` (3–4 líneas).
- CTA: `width: 100%`, `min-height: 52px` (por encima del mínimo de 44px), 16px, `padding: 0 20px`. En 390px el texto «Ver el contenido en YouTube 🚀» entra en una línea; si el stack del sitio es más ancho, bajar a 15px antes que romper en dos líneas.

---

## 4. Animación — astronauta 👨‍🚀

Sólo `transform`. Nada de `left`, `top`, `margin`, `width` ni filtros. Sin video, Lottie ni GIF: CSS puro sobre el emoji de texto.

```css
.academy__astronaut{
  display:inline-block;          /* imprescindible: transform no aplica a inline */
  will-change:transform;
  animation:ac-float 5.5s ease-in-out infinite;
}

@keyframes ac-float{
  0%,100%{ transform:translate3d(0,0,0)    rotate(0deg)  }
  50%    { transform:translate3d(0,-10px,0) rotate(-4deg) }
}

/* Móvil: recorrido más corto */
@media (max-width:767px){
  @keyframes ac-float{
    0%,100%{ transform:translate3d(0,0,0)   rotate(0deg)  }
    50%    { transform:translate3d(0,-7px,0) rotate(-3deg) }
  }
}

/* Pausada fuera del viewport */
.academy:not(.is-visible) .academy__astronaut{ animation-play-state:paused }

/* Preferencia del sistema */
@media (prefers-reduced-motion:reduce){
  .academy__astronaut{ animation:none }
  .academy__cta{ transition:none }
  .academy__cta:hover{ transform:none }
}
```

**IntersectionObserver** (threshold `0.15`) sólo agrega/quita la clase `is-visible` en la sección; no toca estilos inline:

```js
var el = document.getElementById('academy');
if (el && 'IntersectionObserver' in window) {
  new IntersectionObserver(function(entries){
    entries.forEach(function(e){ el.classList.toggle('is-visible', e.isIntersecting); });
  }, { threshold: 0.15 }).observe(el);
} else if (el) { el.classList.add('is-visible'); }
```

Si el sitio ya tiene un observer compartido para animaciones de sección, **reusalo** en vez de instanciar otro.

Ciclo 5.5s, `ease-in-out`, amplitud 10px: acompaña al título, no compite con él. No animar el emoji 🪐 del subtítulo ni el 🚀 del CTA.

---

## 5. Accesibilidad

- **Contraste** (sobre `--ac-surface` `#120B21`): título blanco 17.6:1 · subtítulo `rgba(255,255,255,.72)` ≈ 9.5:1 · eyebrow `#F04E77` ≈ 5.6:1 (el `#DE0540` puro queda en ~4.1:1 a 13px, por eso el aclarado). Texto blanco sobre el CTA: 5.0:1 en el extremo rojo y mucho más en el morado — pasa AA para texto de 17px/bold.
- **Focus visible del CTA**: `outline: 3px solid #FFF; outline-offset: 3px`. No usar `outline:none`. Si el sitio tiene un token de focus, usá ese.
- **Semántica**: `<section aria-labelledby="academy-title">` con `<h2>` — respetar el nivel de encabezado que use el banner de Newsletter.
- El astronauta animado va en un `<span aria-hidden="true">`: es decoración, no debe leerse. Los emojis del eyebrow, subtítulo y CTA se leen como parte del texto (igual que en el resto del sitio).
- Enlace externo: `target="_blank" rel="noopener"`.
- La animación se apaga por completo con `prefers-reduced-motion: reduce`.

---

## 6. Contenido (verbatim — no reescribir)

- Eyebrow: `🔭 ACADEMY`
- Título: `Inntuitivo Academy 👨‍🚀`
- Subtítulo: `Contenido gratis en IA, tecnología y emprendimiento para potenciar tu negocio y llevarlo a órbita 🪐`
- CTA: `Ver el contenido en YouTube 🚀` → `https://www.youtube.com/@inntuitivo`

Tuteo, nunca voseo. Sin claims de cantidad de cursos, certificados ni frecuencia de publicación.
