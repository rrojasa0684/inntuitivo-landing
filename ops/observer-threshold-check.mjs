// 18-sep-2026: candado para la clase de bug que rompió "La diferencia", la tabla
// de precios, y scroll_precio -- las TRES veces en el mismo día -- por la MISMA
// causa: un IntersectionObserver con threshold porcentual (>0) sobre un elemento
// que puede medir más que un viewport típico. Un threshold así necesita que ese
// % de la ALTURA PROPIA del elemento esté visible -- si el elemento crece (o ya
// nació alto), ese % puede volverse matemáticamente inalcanzable en scroll real,
// y el evento deja de disparar EN SILENCIO (sin error, sin warning, solo datos
// que nunca llegan). El fix de fondo en cada caso fue el mismo: threshold:0 +
// rootMargin (dispara por la POSICIÓN del borde del elemento, no por cuánto de
// su propia área es visible -- inmune a que crezca).
//
// Este chequeo abre la página REAL en un navegador (no puede evaluarse por
// grep/parseo estático -- necesita layout con CSS real) con un viewport chico
// (375x650, el peor caso razonable de celular con la barra del navegador
// visible), intercepta CADA IntersectionObserver.observe() antes de que corra
// el script de la página, y para cada observación con threshold>0 mide la
// altura real del elemento observado. Si supera el viewport, falla -- así el
// PRÓXIMO bloque que alguien agregue (o el que ya existe, si crece) no puede
// romper una medición en silencio sin que CI lo cace primero.
//
// Requiere Playwright (ver package.json en la raíz del repo) -- es la única
// pieza de este repo "cero framework, sin build" que necesita Node, porque es
// la única pregunta ("¿cuánto mide esto YA RENDERIZADO?") que no se puede
// contestar sin un motor de layout real.
//
// 18-sep-2026 (2da corrección): un threshold porcentual (p.ej. 0.6) YA NO es
// violación por sí solo si el MISMO array de thresholds incluye también 0
// (ej. threshold:[0, 0.6]). Con 0 presente, el callback del observer SÍ
// dispara apenas cualquier parte del elemento cruza el borde -- lo que basta
// para armar un failsafe por temporizador (ver revelarSinHueco() en
// index.html) sin importar si el 0.6 llega a alcanzarse alguna vez. El riesgo
// real que este chequeo cierra es "el callback nunca se invoca" -- eso solo
// pasa cuando CERO de los thresholds configurados es alcanzable.

import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const indexPath = path.join(__dirname, '..', 'index.html');
const VIEWPORT = { width: 375, height: 650 };

const initScript = () => {
  window.__observaciones = [];
  const OriginalIO = window.IntersectionObserver;
  window.IntersectionObserver = new Proxy(OriginalIO, {
    construct(target, args) {
      const [callback, options] = args;
      const instance = new target(callback, options);
      const originalObserve = instance.observe.bind(instance);
      instance.observe = (el) => {
        window.__observaciones.push({ el, threshold: (options && options.threshold) ?? 0 });
        return originalObserve(el);
      };
      return instance;
    },
  });
};

function describir(el) {
  const tag = el.tagName;
  const id = el.id ? '#' + el.id : '';
  const cls = el.className && typeof el.className === 'string'
    ? '.' + el.className.trim().split(/\s+/).join('.')
    : '';
  return tag + id + cls;
}

async function main() {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: VIEWPORT });
  await page.addInitScript(initScript);
  await page.goto('file://' + indexPath);
  // Deja correr el DOMContentLoaded de la página (donde se crean los observers).
  await page.waitForTimeout(500);

  const violaciones = await page.evaluate(({ viewportHeight }) => {
    const out = [];
    for (const obs of window.__observaciones || []) {
      const thresholds = Array.isArray(obs.threshold) ? obs.threshold : [obs.threshold];
      const tienePorcentaje = thresholds.some((t) => t > 0);
      const ceroPresente = thresholds.some((t) => t === 0);
      if (!tienePorcentaje || ceroPresente) continue;
      const height = obs.el.getBoundingClientRect().height;
      if (height > viewportHeight) {
        out.push({
          desc: (() => {
            const tag = obs.el.tagName;
            const id = obs.el.id ? '#' + obs.el.id : '';
            const cls = obs.el.className && typeof obs.el.className === 'string'
              ? '.' + obs.el.className.trim().split(/\s+/).join('.')
              : '';
            return tag + id + cls;
          })(),
          threshold: obs.threshold,
          height: Math.round(height),
        });
      }
    }
    return out;
  }, { viewportHeight: VIEWPORT.height });

  await browser.close();

  if (violaciones.length > 0) {
    console.error('::error::Elemento(s) observado(s) con threshold porcentual (>0, y SIN 0 en el mismo array) que miden más que el viewport de referencia (' + VIEWPORT.height + 'px) -- el callback puede no invocarse nunca en scroll real. Agregá 0 al array de thresholds (para que el callback dispare igual y pueda armar un failsafe), o usá threshold:0 + rootMargin con un elemento ancla chico (ver revelarSinHueco() en index.html).');
    for (const v of violaciones) {
      console.error('  - ' + v.desc + ': threshold=' + JSON.stringify(v.threshold) + ', altura=' + v.height + 'px');
    }
    process.exit(1);
  }

  console.log('OBSERVER_THRESHOLD_OK -- ningún observer con threshold porcentual observa un elemento más alto que ' + VIEWPORT.height + 'px.');
}

main().catch((err) => {
  console.error('::error::El chequeo de observers no pudo correr: ' + err.message);
  process.exit(1);
});
