// #206 y #207 (7-nov-2026): la tabla «Cómo llega cada herramienta a quien decide» de #precio, con un navegador real.
//  1. JSON válido (el real del repo) -> la tabla se ve, «Tu plan» es el 3, hay 5 columnas y 6 filas, cada cifra lleva un enlace https, «No informado» donde no hay fuente.
//  2. JSON ausente (404), inválido, o con una cifra sin URL -> el bloque no se ve y «Tu plan» es el 2.
//  3. A 390 px la página no se desborda a lo ancho (se lee por tarjetas); a 1440 px se ve la tabla y la columna de Inntuitivo.
//  4. Ningún porcentaje propio de Inntuitivo (#207) y ninguna cifra de relleno del diseño (64, 51, 48, 46, 29 %) en el repo.
// Uso: node decisores-bloque-check.mjs [carpeta_capturas]. Salida: DECISORES_BLOQUE_OK o error (exit 1). Los JSON de prueba solo se sirven al navegador.
import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';

const salida = process.argv[2];
const REAL = readFileSync(new URL('./datos-decisores-publicos.json', import.meta.url), 'utf8');
let ACTUAL = REAL, CODIGO = 200;
const servidor = createServer((req, res) => {
  const ruta = new URL(req.url, 'http://x').pathname;
  if (ruta === '/datos-decisores-publicos.json') { res.statusCode = CODIGO; res.setHeader('content-type', 'application/json'); return res.end(CODIGO === 200 ? ACTUAL : ''); }
  const f = new URL('.' + (ruta === '/' ? '/index.html' : ruta), import.meta.url);
  if (!existsSync(f)) { res.statusCode = 404; return res.end(); }
  res.setHeader('content-type', ruta.endsWith('.json') ? 'application/json' : ruta.endsWith('.css') ? 'text/css' : ruta.endsWith('.js') ? 'text/javascript' : ruta.endsWith('.png') ? 'image/png' : 'text/html');
  res.end(readFileSync(f));
}).listen(0);
const base = `http://127.0.0.1:${servidor.address().port}`;
const sinUrl = JSON.parse(REAL); sinUrl.filas[3].celdas.apollo.datos[0].url = '';
const estados = [
  ['válido (el real del repo)', REAL, 200, true],
  ['JSON ausente (404)', '', 404, false],
  ['JSON inválido', '{no es json', 200, false],
  ['una cifra sin URL', JSON.stringify(sinUrl), 200, false],
];
const fallas = [];
const browser = await chromium.launch();
try {
  for (const [nombre, json, codigo, visible] of estados) {
    ACTUAL = json; CODIGO = codigo;
    for (const [w, h] of [[390, 900], [1440, 900]]) {
      const page = await browser.newPage({ viewport: { width: w, height: h } });
      await page.goto(base + '/', { waitUntil: 'networkidle' });
      await page.waitForTimeout(400);
      const r = await page.evaluate(() => {
        const b = document.getElementById('decisores');
        const filas = document.querySelectorAll('#dec-tabla tbody tr').length, cols = document.querySelectorAll('#dec-tabla thead th').length;
        const enlaces = [...document.querySelectorAll('#decisores .dec-fuente')];
        const cifras = [...document.querySelectorAll('#dec-tabla tbody td .dec-dato')].filter((p) => /\d/.test(p.textContent) && !p.closest('.col-inntuitivo'));
        return { vis: !!b.offsetParent, plan: document.getElementById('plan-num').textContent, filas, cols, enlaces: enlaces.length, https: enlaces.every((a) => a.href.startsWith('https://')),
          cifrasSinEnlace: cifras.filter((p) => !p.querySelector('.dec-fuente')).length, ni: document.querySelectorAll('#dec-tabla .dec-ni').length,
          desborda: document.documentElement.scrollWidth > innerWidth, texto: b.innerText, inn: !!document.querySelector('#dec-tabla thead .col-inntuitivo'),
          tarjetas: document.querySelectorAll('#dec-cards .tabla-real-card').length, tablaVisible: !!document.querySelector('#dec-tabla').offsetParent, tarjetasVisibles: !!document.querySelector('#dec-cards').offsetParent };
      });
      const etiqueta = `${nombre} @${w}`;
      if (visible !== r.vis) fallas.push(`${etiqueta}: visible=${r.vis}, se esperaba ${visible}`);
      if (r.plan !== (visible ? '3' : '2')) fallas.push(`${etiqueta}: «Tu plan» es el ${r.plan}`);
      if (r.desborda) fallas.push(`${etiqueta}: la página desborda horizontalmente`);
      if (visible) {
        if (r.cols !== 6 || r.filas !== 6) fallas.push(`${etiqueta}: ${r.cols} columnas y ${r.filas} filas (se esperaban 6 y 6: atributo + 5 herramientas)`);
        if (r.enlaces !== 16 || !r.https) fallas.push(`${etiqueta}: ${r.enlaces} enlaces de fuente (se esperaban 16 = 8 datos en la tabla y en las tarjetas, todos https)`);
        if (r.cifrasSinEnlace) fallas.push(`${etiqueta}: ${r.cifrasSinEnlace} cifra(s) de terceros sin enlace de fuente`);
        if (r.ni !== 17) fallas.push(`${etiqueta}: ${r.ni} «No informado» (se esperaban 17)`);
        if (!r.inn || r.tarjetas !== 5) fallas.push(`${etiqueta}: falta la columna o la tarjeta de Inntuitivo`);
        if (/28\s*%|14 de 50/.test(r.texto)) fallas.push(`${etiqueta}: aparece el porcentaje propio (#207)`);
        if (w === 390 && (r.tablaVisible || !r.tarjetasVisibles)) fallas.push(`${etiqueta}: en celular debe verse por tarjetas`);
        if (w === 1440 && (!r.tablaVisible || r.tarjetasVisibles)) fallas.push(`${etiqueta}: en computadora debe verse la tabla`);
        if (salida) { mkdirSync(salida, { recursive: true }); await (await page.$('#precio')).screenshot({ path: `${salida}/precio-decisores-${w}.png` }); }
      }
      await page.close();
    }
  }
} finally { await browser.close(); servidor.close(); }
for (const n of ['64', '51', '48', '46', '29', '28']) {
  const hit = execSync(`grep -rlE '(^|[^0-9,.])${n} ?%' --include=*.json --include=*.mjs . || true`, { cwd: new URL('.', import.meta.url).pathname, encoding: 'utf8' }).split('\n').filter((l) => l && !l.includes('node_modules') && !l.includes('package') && !l.endsWith('decisores-bloque-check.mjs') && !l.includes('precios-competencia'));
  if (hit.length) fallas.push(`porcentaje de relleno o propio ${n} % en: ${hit.join(', ')}`);
}
if (fallas.length) { console.error('DECISORES_BLOQUE_FALLA\n' + fallas.join('\n')); process.exit(1); }
console.log('DECISORES_BLOQUE_OK');
