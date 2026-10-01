// 1-oct-2026: verifica con un navegador real (Playwright) el precio MENSUAL del plan de entrada de Apollo, Lusha y Hunter y lo compara con
// precios-competencia.json. Solo LEE páginas públicas: no envía nada, no usa secretos. Para cada sitio activa el interruptor de facturación
// mensual y lee el precio del plan de entrada. Si el interruptor no se encuentra, no se activa o el precio no se lee con certeza, es FALLA
// (nunca se marca verificado algo que no se leyó). Salida JSON por stdout. Código 0 = todo leído y igual al JSON, 2 = cambió o no se
// pudo confirmar, 1 = error general.
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';

const datos = JSON.parse(readFileSync(new URL('./precios-competencia.json', import.meta.url), 'utf8'));

// Por sitio: cómo activar "mensual" y cómo leer el plan de entrada (regex sobre el texto visible, con "$ 37 .45" ya normalizado).
const SITIOS = {
  apollo: { activar: (p) => p.getByRole('button', { name: /Monthly billing/i }), leer: /Basic\s*\$(\d+(?:\.\d+)?)\s*Per seat per month, billed monthly/g },
  lusha: { activar: (p) => p.getByText('Pay monthly', { exact: true }), leer: /Starter\s*\$(\d+(?:\.\d+)?)\s*USD \/ month\s*Billed monthly/g },
  hunter: { activar: (p) => p.getByText('Pay monthly', { exact: true }), leer: /Starter[^$]{0,80}\$(\d+(?:\.\d+)?)\s*\/month\s*billed monthly/g },
};

const normalizar = (s) => s.replace(/\$\s+/g, '$').replace(/(\d)\s+\.(\d)/g, '$1.$2').replace(/\s+/g, ' ');
const resultado = { ok: true, fuentes: [] };
let browser;
try {
  browser = await chromium.launch();
  for (const c of datos.competidores) {
    const esperado = parseFloat(String(c.entrada_mensual).replace('$', ''));
    const fila = { id: c.id, url: c.url, esperado, leido: null, error: null };
    try {
      const sitio = SITIOS[c.id];
      if (!sitio) throw new Error('sin receta de lectura para este sitio');
      const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, userAgent: 'Mozilla/5.0 (compatible; inntuitivo-precio-check)' });
      await page.goto(c.url, { waitUntil: 'load', timeout: 60000 });
      await page.waitForTimeout(6000);  // las páginas pintan los precios por JS después de cargar
      const interruptor = sitio.activar(page).first();
      if ((await sitio.activar(page).count()) === 0) throw new Error('no se encontró el interruptor de facturación mensual');
      await interruptor.click({ timeout: 10000 });
      await page.waitForTimeout(2000);
      const texto = normalizar(await page.evaluate(() => document.body.innerText));
      const valores = [...new Set([...texto.matchAll(sitio.leer)].map((m) => parseFloat(m[1])))];
      if (valores.length !== 1 || Number.isNaN(valores[0])) throw new Error(`precio mensual no leído con certeza (lecturas: ${JSON.stringify(valores)})`);
      fila.leido = valores[0];
      await page.close();
    } catch (e) {
      fila.error = String(e.message || e).slice(0, 200);
    }
    if (fila.error || fila.leido !== fila.esperado) resultado.ok = false;
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
