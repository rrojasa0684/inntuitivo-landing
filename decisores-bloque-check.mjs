// #206 y #207 (7-nov-2026): la tabla «Cómo llega cada herramienta a quien decide» de #precio, con un navegador real.
//  1. #208: solo se muestran las filas con dato con fuente en al menos 3 de las 4 herramientas de la competencia; con menos de 2 filas el bloque se oculta y «Tu plan» es el 2; con 2 o más, se ve y «Tu plan» es el 3.
//     Se prueba con el JSON real del repo (lo esperado se calcula con la misma regla, así una fuente nueva hace volver la fila sin tocar este archivo) y con dos JSON de prueba (3 filas que cumplen; solo 1 que cumple).
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
const COMP = ['apollo', 'clay', 'explee', 'grok'];
const informadas = (f) => COMP.filter((c) => f.celdas[c].estado === 'informado').length;
const esperadasDe = (json) => JSON.parse(json).filas.filter((f) => informadas(f) >= 3);
// JSON de prueba: copia la primera cifra de Apollo (con su fuente) a las celdas de la competencia que se indican en cada fila
const conCompetencia = (porFila) => {
  const d = JSON.parse(REAL), modelo = d.filas.flatMap((f) => f.celdas.apollo.estado === 'informado' ? [f.celdas.apollo] : [])[0];
  d.filas.forEach((f, i) => COMP.forEach((c, k) => {
    f.celdas[c] = k < (porFila[i] ?? 0) ? JSON.parse(JSON.stringify(modelo)) : { estado: 'no_informado', datos: [] };
  }));
  return JSON.stringify(d);
};
const TRES_FILAS = conCompetencia([3, 4, 3, 2, 2, 1]);   // cumplen las filas 0, 1 y 2
const UNA_FILA = conCompetencia([3, 2, 2, 1, 0, 0]);     // cumple solo la 0
const sinUrl = JSON.parse(TRES_FILAS); sinUrl.filas[0].celdas.apollo.datos[0].url = '';
const estados = [
  ['el real del repo', REAL, 200],
  ['3 filas cumplen (3, 4 y 3 de 4)', TRES_FILAS, 200],
  ['solo 1 fila cumple', UNA_FILA, 200],
  ['JSON ausente (404)', '', 404],
  ['JSON inválido', '{no es json', 200],
  ['una cifra sin URL', JSON.stringify(sinUrl), 200],
];
const fallas = [];
const browser = await chromium.launch();
try {
  for (const [nombre, json, codigo] of estados) {
    ACTUAL = json; CODIGO = codigo;
    let esp = [];
    try { esp = codigo === 200 ? esperadasDe(json) : []; } catch { esp = []; }
    const valido = (() => { try { const d = JSON.parse(json); return codigo === 200 && !JSON.stringify(d).includes('"url":""'); } catch { return false; } })();
    const visible = valido && esp.length >= 2;
    if (nombre === 'el real del repo') console.log(`real: ${esp.length} fila(s) cumplen la regla de #208 -> ${visible ? 'se muestra' : 'se oculta'}`);
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
        const datos = esp.reduce((n, f) => n + COMP.reduce((m, c) => m + (f.celdas[c].estado === 'informado' ? f.celdas[c].datos.length : 0), 0), 0);
        const ni = esp.reduce((n, f) => n + ['inntuitivo', ...COMP].filter((c) => f.celdas[c].estado !== 'informado').length, 0);
        if (r.cols !== 6 || r.filas !== esp.length) fallas.push(`${etiqueta}: ${r.cols} columnas y ${r.filas} filas (se esperaban 6 y ${esp.length})`);
        if (r.enlaces !== datos * 2 || !r.https) fallas.push(`${etiqueta}: ${r.enlaces} enlaces de fuente (se esperaban ${datos * 2} = ${datos} datos en la tabla y en las tarjetas, todos https)`);
        if (r.cifrasSinEnlace) fallas.push(`${etiqueta}: ${r.cifrasSinEnlace} cifra(s) de terceros sin enlace de fuente`);
        if (r.ni !== ni) fallas.push(`${etiqueta}: ${r.ni} «No informado» (se esperaban ${ni})`);
        if (!r.inn || r.tarjetas !== 5) fallas.push(`${etiqueta}: falta la columna o la tarjeta de Inntuitivo`);
        if (/28\s*%|14 de 50/.test(r.texto)) fallas.push(`${etiqueta}: aparece el porcentaje propio (#207)`);
        if (w === 390 && (r.tablaVisible || !r.tarjetasVisibles)) fallas.push(`${etiqueta}: en celular debe verse por tarjetas`);
        if (w === 1440 && (!r.tablaVisible || r.tarjetasVisibles)) fallas.push(`${etiqueta}: en computadora debe verse la tabla`);
        if (salida && nombre === 'el real del repo') { mkdirSync(salida, { recursive: true }); await (await page.$('#precio')).screenshot({ path: `${salida}/precio-decisores-${w}.png` }); }
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
