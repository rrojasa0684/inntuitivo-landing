// 25-nov-2026: la parte del chequeo en vivo que necesita un navegador (la tabla vieja la dibujaba JavaScript, un curl no la veía). Contexto NUEVO de Playwright (sin caché, sin cookies), carga <base>/ y falla si:
//  - el texto visible trae «Cifras públicas de terceros» o «De dónde sale el decisor»;
//  - falta «Ver las fuentes» (el desplegable de la sección 2);
//  - la página pide algo de datos-decisores o de /datos/decisores-publicos (ya no se muestran);
//  - la página desborda horizontalmente a 360, 390, 430 o 1280 px.
// Uso: node chequeo-en-vivo-navegador.mjs <base>. Salida: NAVEGADOR_OK o NAVEGADOR_FALLA y la lista (exit 1).
import { chromium } from 'playwright';
const base = (process.argv[2] || 'https://www.inntuitivo.com').replace(/\/$/, '');
const fallas = [], browser = await chromium.launch();
try {
  for (const w of [360, 390, 430, 1280]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: 900 }, serviceWorkers: 'block' });
    const page = await ctx.newPage(), pedidos = [];
    page.on('request', (r) => pedidos.push(r.url()));
    await page.goto(base + '/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(600);
    const r = await page.evaluate(() => ({ t: document.body.innerText, desborda: document.documentElement.scrollWidth > innerWidth }));
    for (const x of ['Cifras públicas de terceros', 'De dónde sale el decisor']) if (r.t.includes(x)) fallas.push(`@${w}: el sitio publicado muestra «${x}»`);
    if (!r.t.includes('Ver las fuentes')) fallas.push(`@${w}: falta «Ver las fuentes» en la sección 2`);
    const viejo = pedidos.filter((u) => /datos-decisores|datos\/decisores-publicos/.test(u));
    if (viejo.length) fallas.push(`@${w}: la página todavía pide ${viejo.join(', ')}`);
    if (r.desborda) fallas.push(`@${w}: la página desborda horizontalmente`);
    await ctx.close();
  }
} finally { await browser.close(); }
if (fallas.length) { console.error('NAVEGADOR_FALLA\n' + fallas.map((f) => '  - ' + f).join('\n')); process.exit(1); }
console.log('NAVEGADOR_OK');
