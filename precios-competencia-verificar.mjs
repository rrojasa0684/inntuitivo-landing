// 1-oct-2026: verifica con un navegador real (Playwright, ya instalado para otro chequeo) que cada página pública de precios
// de Apollo, Lusha y Hunter siga mostrando las cifras "ancla" de precios-competencia.json. Solo LEE páginas públicas: no envía
// nada, no usa secretos. Salida: JSON por stdout. Código 0 = sin cambios, 2 = algo cambió o no se pudo confirmar, 1 = error.
// ⚠️ Límite: las páginas muestran por defecto la facturación anual; las cifras de facturación mensual ($59 Apollo, $49.90 Lusha) no
// aparecen sin interactuar con la página y NO se confirman aquí (solo las anclas del JSON).
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';

const datos = JSON.parse(readFileSync(new URL('./precios-competencia.json', import.meta.url), 'utf8'));
const resultado = { ok: true, fuentes: [] };
let browser;
try {
  browser = await chromium.launch();
  for (const c of datos.competidores) {
    const fila = { id: c.id, url: c.url, faltan: [], error: null };
    try {
      const page = await browser.newPage({ userAgent: 'Mozilla/5.0 (compatible; inntuitivo-precio-check)' });
      await page.goto(c.url, { waitUntil: 'load', timeout: 60000 });
      await page.waitForTimeout(6000);  // las páginas pintan los precios por JS después de cargar
      const texto = (await page.evaluate(() => document.body.innerText)).replace(/\$\s+/g, '$').replace(/\s+/g, ' ');
      fila.faltan = c.anclas.filter((a) => !new RegExp(a.replace('$', '\\$') + '(?![0-9])').test(texto));
      await page.close();
    } catch (e) {
      fila.error = String(e.message || e).slice(0, 200);
    }
    if (fila.error || fila.faltan.length) resultado.ok = false;
    resultado.fuentes.push(fila);
  }
} catch (e) {
  console.log(JSON.stringify({ ok: false, error: String(e.message || e).slice(0, 200) }));
  process.exit(1);
} finally {
  if (browser) await browser.close();
}
console.log(JSON.stringify(resultado));
process.exit(resultado.ok ? 0 : 2);
