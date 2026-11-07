// #202 a #205 (6-nov-2026): el bloque «Cuántos leads llegan con quien decide» de #precio.
// Tres estados con un navegador real: (1) decisores.json pendiente -> nada se ve y «Tu plan» sigue siendo el 2;
// (2) JSON de PRUEBA verificado con una herramienta publicable y otra no -> el bloque se ve solo con la publicable y «Tu plan» pasa a 3;
// (3) JSON inválido o verificado sin ninguna publicable -> oculto. Además: ninguna cifra de relleno del diseño (64, 51, 48, 46, 29 %) existe en el repo.
// Uso: node decisores-bloque-check.mjs [carpeta_capturas]. Salida: DECISORES_BLOQUE_OK o error (exit 1). Los JSON de prueba nunca se escriben en el repo: se sirven al navegador.
import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';

const salida = process.argv[2];
let JSON_ACTUAL = readFileSync(new URL('./decisores.json', import.meta.url), 'utf8');
const servidor = createServer((req, res) => {
  const ruta = new URL(req.url, 'http://x').pathname;
  if (ruta === '/decisores.json') { res.setHeader('content-type', 'application/json'); return res.end(JSON_ACTUAL); }
  const f = new URL('.' + (ruta === '/' ? '/index.html' : ruta), import.meta.url);
  if (!existsSync(f)) { res.statusCode = 404; return res.end(); }
  res.setHeader('content-type', ruta.endsWith('.json') ? 'application/json' : ruta.endsWith('.css') ? 'text/css' : ruta.endsWith('.js') ? 'text/javascript' : ruta.endsWith('.png') ? 'image/png' : 'text/html');
  res.end(readFileSync(f));
}).listen(0);
const base = `http://127.0.0.1:${servidor.address().port}`;
const verificado = { version: 1, estado: 'verificado', actualizado: '2026-11-30', muestra_empresas: 50, definicion: 'Decisor correcto con fuente pública: PRUEBA.',
  inntuitivo: { nombre: 'Inntuitivo', tasa: 0.4 },
  herramientas: [{ id: 'a', nombre: 'HerramientaPublicable', tipo: 'x', rotulo: '', medida: true, tasa: 0.3, ventaja: 0.33, publicable: true, motivo: 'ok' },
                 { id: 'b', nombre: 'HerramientaNoPublicable', tipo: 'x', rotulo: '', medida: true, tasa: 0.39, ventaja: 0.02, publicable: false, motivo: 'x' }] };
const estados = [
  ['pendiente (el real de hoy)', JSON_ACTUAL, false],
  ['verificado de prueba', JSON.stringify(verificado), true],
  ['verificado sin ninguna publicable', JSON.stringify({ ...verificado, herramientas: [verificado.herramientas[1]] }), false],
  ['json inválido', '{no es json', false],
];
let fallas = [];
const browser = await chromium.launch();
try {
  for (const [nombre, json, visible] of estados) {
    JSON_ACTUAL = json;
    for (const [w, h] of [[390, 900], [1440, 900]]) {
      const page = await browser.newPage({ viewport: { width: w, height: h } });
      await page.goto(base + '/', { waitUntil: 'networkidle' });
      await page.waitForTimeout(400);
      const r = await page.evaluate(() => ({ oculto: document.getElementById('decisores').hidden, vis: !!document.getElementById('decisores').offsetParent, plan: document.getElementById('plan-num').textContent,
        texto: document.getElementById('decisores').innerText, tabla: document.getElementById('dec-tabla').innerText, desborda: document.documentElement.scrollWidth > innerWidth }));
      if (visible !== r.vis) fallas.push(`${nombre} @${w}: visible=${r.vis}, se esperaba ${visible}`);
      if (r.plan !== (visible ? '3' : '2')) fallas.push(`${nombre} @${w}: «Tu plan» es el ${r.plan}`);
      if (r.desborda) fallas.push(`${nombre} @${w}: la página desborda horizontalmente`);
      if (visible) {
        if (!r.texto.includes('HerramientaPublicable') || r.texto.includes('HerramientaNoPublicable')) fallas.push(`${nombre} @${w}: debe mostrar solo la publicable`);
        if (/correo/i.test(r.tabla)) fallas.push(`${nombre} @${w}: no debe haber columna de correo (#149)`);
        if (salida) { mkdirSync(salida, { recursive: true }); await (await page.$('#precio')).screenshot({ path: `${salida}/precio-decisores-${w}.png` }); }
      }
      if (!visible && salida && nombre.startsWith('pendiente')) { mkdirSync(salida, { recursive: true }); await (await page.$('#precio')).screenshot({ path: `${salida}/precio-oculto-${w}.png` }); }
      await page.close();
    }
  }
} finally { await browser.close(); servidor.close(); }
// ninguna cifra de relleno del diseño existe en el repo (64, 51, 48, 46, 29 como tasa de decisores)
for (const n of ['64', '51', '48', '46', '29']) {
  const hit = execSync(`grep -rlE '"(decisor|tasa)": *0?\\.${n}\\b|"(decisor|tasa)": *${n}\\b' --include=*.json --include=*.html --include=*.mjs . || true`, { cwd: new URL('.', import.meta.url).pathname, encoding: 'utf8' }).split('\n').filter((l) => l && !l.includes('node_modules') && !l.endsWith('decisores-bloque-check.mjs'));
  if (hit.length) fallas.push(`cifra de relleno ${n} en: ${hit.join(', ')}`);
}
if (fallas.length) { console.error('DECISORES_BLOQUE_FALLA\n' + fallas.join('\n')); process.exit(1); }
console.log('DECISORES_BLOQUE_OK');
