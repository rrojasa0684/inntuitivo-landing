// 25-nov-2026: comparativo simplificado ✓ ✕ — de #precio.
//  1. Estático: 8 filas × 5 columnas; cada celda con aria-label; todo ✓ o ✕ de la competencia con data-fuente que apunta a su fuente en el detalle (enlace https y fecha de consulta); Inntuitivo con ✓ en todas; el detalle cerrado por defecto. Se prueba también que el chequeo FALLA si falta una fuente o un aria-label.
//  2. Navegador (360, 390, 430 y 1280 px): sin desborde horizontal de la página; en celular la tabla se desplaza dentro de su caja, con la primera columna fija y Inntuitivo visible al entrar; áreas de 44 px o más; contraste de texto 4.5:1 o más; el desplegable abre.
// Uso: node comparativo-simplificado-check.mjs. Salida: COMPARATIVO_OK o error (exit 1).
import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, existsSync } from 'node:fs';

const HTML = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const revisar = (html) => {
  const f = [];
  const bloque = (/<table class="cmp">[\s\S]*?<\/table>/.exec(html) || [''])[0];
  const filas = bloque.match(/<tbody>[\s\S]*<\/tbody>/) ? bloque.match(/<tr>[\s\S]*?<\/tr>/g).slice(1) : [];
  if (filas.length !== 8) f.push(`${filas.length} filas (se esperaban 8)`);
  for (const tr of filas) {
    const tds = tr.match(/<td\b[^>]*>[\s\S]*?<\/td>/g) || [];
    if (tds.length !== 5) f.push(`fila con ${tds.length} celdas (se esperaban 5)`);
    tds.forEach((td, i) => {
      if (!/aria-label="[^"]{8,}"/.test(td)) f.push(`celda sin aria-label: ${td.slice(0, 60)}`);
      const marca = /cmp-(si|no)\b/.test(td);
      if (i === 0 && !/cmp-si-inn/.test(td)) f.push('Inntuitivo sin ✓ en una fila');
      if (i > 0 && marca) {
        const id = (/data-fuente="([^"]+)"/.exec(td) || [])[1];
        if (!id) f.push(`✓/✕ de la competencia sin fuente: ${(/aria-label="([^"]+)"/.exec(td) || [])[1]}`);
        else {
          const det = (/<details class="dec-detalle">[\s\S]*?<\/details>/.exec(html) || [''])[0];
          const li = new RegExp(`<li id="fuente-${id}">[\\s\\S]*?</li>`).exec(det);
          const marcaTabla = /cmp-si\b/.test(td) ? 'Sí' : 'No', marcaFuente = li && (/<span class="fu-marca">([^<]+)<\/span>/.exec(li[0]) || [])[1];
          if (li && marcaTabla !== marcaFuente) f.push(`la marca de «${id}» dice ${marcaTabla} en la tabla y ${marcaFuente} en las fuentes`);
          if (!li) f.push(`la fuente «${id}» no está en el detalle`);
          else if (!/href="https:\/\/[^"\s]+"/.test(li[0]) || !/Consultado el \d{1,2} [a-z]{3} \d{4}/.test(li[0])) f.push(`la fuente «${id}» sin enlace https o sin fecha`);
        }
      } else if (i > 0 && !/data-fuente/.test(td) === false) f.push('una celda «sin dato» lleva fuente');
    });
  }
  if (/<details class="dec-detalle"[^>]*\bopen\b/.test(html)) f.push('el detalle debe estar cerrado por defecto');
  if (!/<summary>Ver las fuentes<\/summary>/.test(html)) f.push('falta «Ver las fuentes»');
  if (/dec-tabla|dec-cards|datos-decisores|Cifras públicas de terceros<\/h4>/.test(html)) f.push('quedó código o texto de la tabla de cifras');
  const fechas = [...html.matchAll(/Consultado el (\d{1,2}) ([a-z]{3}) (\d{4})/g)].map((m) => m[0].slice(13));
  const pie = (/<p class="dec-pie">Fuentes públicas, consultadas el ([^.]+)\. ¿Ves un dato desactualizado\? <a href="mailto:/.exec(html) || [])[1];
  const MES = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'], orden = (x) => { const m = /(\d+) (\w+) (\d+)/.exec(x); return m ? +m[3] * 10000 + MES.indexOf(m[2]) * 100 + +m[1] : 0; };
  if (!pie) f.push('falta el pie «Fuentes públicas, consultadas el …»');
  else if (fechas.length && orden(pie) !== Math.max(...fechas.map(orden))) f.push(`la fecha del pie (${pie}) no es la de la fuente más reciente`);
  if (!/— significa sin dato público/.test(html)) f.push('falta la línea que explica «—»');
  if (!/<span class="fu-nota">Fuente patrocinada[^<]*<\/span>/.test(html)) f.push('la fuente patrocinada de Explee no lo dice en su línea');
  if (!/✓<\/span> Sí/.test(html) || !/✕<\/span> No/.test(html) || !/—<\/span> Sin dato público/.test(html)) f.push('falta la leyenda');
  return f;
};
const fallas = revisar(HTML).map((x) => `estático: ${x}`);
// el chequeo tiene que fallar si se quita una fuente o un aria-label
const sinFuente = HTML.replace(/ data-fuente="apollo-precio"/, '');
if (!revisar(sinFuente).length) fallas.push('el chequeo no detectó una celda ✕ sin fuente');
const sinAria = HTML.replace(/(<td aria-label=")Apollo: no tiene precio fijo con usuarios ilimitados"/, '<td data-x="');
if (!revisar(sinAria).length) fallas.push('el chequeo no detectó una celda sin aria-label');
const invertida = HTML.replace(/(id="fuente-apollo-precio">[\s\S]*?fu-marca">)No/, '$1Sí');
if (!revisar(invertida).length) fallas.push('el chequeo no detectó una marca invertida entre tabla y fuentes');
const sinLi = HTML.replace(/<li id="fuente-clay-web">/, '<li id="x-clay-web">');
if (!revisar(sinLi).length) fallas.push('el chequeo no detectó una fuente ausente del detalle');

const servidor = createServer((req, res) => {
  const ruta = new URL(req.url, 'http://x').pathname;
  const f = new URL('.' + (ruta === '/' ? '/index.html' : ruta), import.meta.url);
  if (!existsSync(f)) { res.statusCode = 404; return res.end(); }
  res.setHeader('content-type', ruta.endsWith('.json') ? 'application/json' : ruta.endsWith('.css') ? 'text/css' : ruta.endsWith('.js') ? 'text/javascript' : ruta.endsWith('.png') ? 'image/png' : ruta.endsWith('.svg') ? 'image/svg+xml' : 'text/html');
  res.end(readFileSync(f));
}).listen(0, '127.0.0.1');
await new Promise((ok) => servidor.once('listening', ok));
const base = `http://127.0.0.1:${servidor.address().port}`;
const browser = await chromium.launch();
try {
  for (const w of [360, 390, 430, 1280]) {
    const page = await browser.newPage({ viewport: { width: w, height: 900 } });
    await page.goto(base + '/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(400);
    const r = await page.evaluate(() => {
      const lum = (c) => { const v = c.map((x) => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); }); return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]; };
      const rgba = (s) => { const m = s.match(/[\d.]+/g).map(Number); return [m[0], m[1], m[2], m.length > 3 ? m[3] : 1]; };
      const fondo = (el) => { // mezcla los fondos de los ancestros hasta uno opaco
        const capas = []; for (let e = el; e; e = e.parentElement) { const c = rgba(getComputedStyle(e).backgroundColor); if (c[3] > 0) capas.push(c); if (c[3] >= 1) break; }
        let base = [13, 7, 34]; if (!capas.length || capas[capas.length - 1][3] < 1) capas.push([...base, 1]);
        return capas.reverse().reduce((acc, c) => [0, 1, 2].map((i) => c[i] * c[3] + acc[i] * (1 - c[3])), [0, 0, 0]);
      };
      const contraste = (el) => { const f = fondo(el), t = rgba(getComputedStyle(el).color), a = lum(f), b = lum(t.slice(0, 3)); return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05); };
      window.__contraste = contraste;
      const wrap = document.querySelector('.cmp-wrap'), tabla = document.querySelector('.cmp');
      const wr = wrap.getBoundingClientRect(), inn = document.querySelector('.cmp tbody .cmp-inn').getBoundingClientRect();
      const th = document.querySelector('.cmp tbody th');
      const sum = document.querySelector('.dec-detalle > summary');
      const textos = ['.cmp tbody th', '.cmp thead .cmp-th-lab', '.cmp thead th:nth-child(3)', '.cmp thead .cmp-inn', '.cmp-leyenda', '.cmp-sd', '.cmp-no', '.cmp-si', '.cmp-si-inn', '.dec-detalle > summary', '.comparativo .dec-pie'];
      const bajos = textos.map((q) => [q, contraste(document.querySelector(q))]).filter(([, c]) => c < 4.5).map(([q, c]) => `${q} ${c.toFixed(2)}`);
      const celdas = [...document.querySelectorAll('.cmp tbody td')].map((td) => td.getBoundingClientRect());
      return { desborda: document.documentElement.scrollWidth > innerWidth, scrollea: wrap.scrollWidth > wrap.clientWidth, sticky: getComputedStyle(th).position, innVisible: inn.left >= wr.left && inn.right <= wr.right + 1,
        altoMin: Math.min(...celdas.map((c) => c.height)), anchoMin: Math.min(...celdas.map((c) => c.width)), sumAlto: sum.getBoundingClientRect().height, sumBorde: getComputedStyle(sum).borderTopWidth, sumFondo: getComputedStyle(sum).backgroundColor, sumAncho: Math.round(sum.getBoundingClientRect().width), detAncho: Math.round(document.querySelector('.dec-detalle').getBoundingClientRect().width), contAncho: Math.round(document.querySelector('.comparativo').getBoundingClientRect().width), masTransf: getComputedStyle(sum, '::after').transform, mas: (() => { const a = getComputedStyle(sum, '::after'); return { top: parseFloat(a.top), right: parseFloat(a.right), pos: a.position, h: sum.getBoundingClientRect().height }; })(), bajos,
        filas: document.querySelectorAll('.cmp tbody tr').length, detalleCerrado: !document.querySelector('.dec-detalle').open, tablaWidth: tabla.getBoundingClientRect().width, wrapW: wr.width };
    });
    const e = `@${w}`;
    if (r.desborda) fallas.push(`${e}: la página desborda horizontalmente`);
    if (w <= 430 && !r.scrollea) fallas.push(`${e}: la tabla no se desplaza dentro de su caja`);
    if (w <= 430 && r.sticky !== 'sticky') fallas.push(`${e}: la primera columna no es fija`);
    if (!r.innVisible) fallas.push(`${e}: la columna de Inntuitivo no se ve al entrar`);
    if (r.altoMin < 44 || r.anchoMin < 44) fallas.push(`${e}: celdas de ${r.anchoMin}×${r.altoMin} px (mínimo 44)`);
    if (r.sumAlto < 44) fallas.push(`${e}: «Ver las fuentes» de ${r.sumAlto} px de alto`);
    if (r.sumBorde !== '0px' || r.sumFondo !== 'rgba(0, 0, 0, 0)') fallas.push(`${e}: el desplegable tiene una segunda caja (borde ${r.sumBorde}, fondo ${r.sumFondo})`);
    if (Math.abs(r.detAncho - r.contAncho) > 2 || r.sumAncho < r.detAncho - 50) fallas.push(`${e}: el desplegable no ocupa el ancho del contenedor (${r.detAncho} de ${r.contAncho}; el título ${r.sumAncho})`);
    if (Math.abs(r.mas.top - r.mas.h / 2) > 4 || r.mas.right > 24) fallas.push(`${e}: el «+» no está en la línea del título, a la derecha (top ${r.mas.top}, alto ${r.mas.h}, right ${r.mas.right})`);
    if (r.bajos.length) fallas.push(`${e}: contraste bajo 4.5:1 en ${r.bajos.join(', ')}`);
    if (r.filas !== 8 || !r.detalleCerrado) fallas.push(`${e}: filas ${r.filas}, detalle cerrado ${r.detalleCerrado}`);
    // el desplegable abre con un toque y muestra las fuentes y la tabla detallada
    await page.click('.dec-detalle > summary'); await page.waitForTimeout(350);
    const ab = await page.evaluate(() => { const d = document.querySelector('.dec-detalle'), sum = d.querySelector(':scope > summary'), a = getComputedStyle(sum, '::after'), h = sum.getBoundingClientRect().height;
      return { abierto: d.open, fuentes: [...d.querySelectorAll('.cmp-fuentes li')].every((l) => l.offsetParent), desborda: document.documentElement.scrollWidth > innerWidth || d.scrollWidth > d.clientWidth + 1,
        sumAlto: h, masTop: parseFloat(a.top), masTransf: a.transform, grupos: d.querySelectorAll('h4.dec-h4').length, lineas: d.querySelectorAll('.cmp-fuentes li').length, sumBorde: getComputedStyle(sum).borderTopWidth, contrasteBajo: ['.cmp-fuentes li', '.fu-cap', '.fu-marca', '.fu-fecha', '.cmp-fuentes a', '.fu-pie'].map((q) => [q, window.__contraste(d.querySelector(q))]).filter(([, c]) => c < 4.5).map(([q, c]) => q + ' ' + c.toFixed(2)), enlaceAlto: Math.min(...[...d.querySelectorAll('.cmp-fuentes a')].map((x) => x.getBoundingClientRect().height)) }; });
    if (!ab.abierto || !ab.fuentes || ab.lineas !== 9 || ab.grupos !== 4) fallas.push(`${e}: el desplegable no muestra las 9 fuentes en 4 grupos (${JSON.stringify(ab)})`);
    if (ab.sumAlto < 44 || Math.abs(ab.masTop - ab.sumAlto / 2) > 4 || ab.masTransf === r.masTransf || ab.sumBorde !== '0px') fallas.push(`${e}: abierto, el título/«−» se descuadra (${JSON.stringify(ab)})`);
    if (ab.contrasteBajo.length) fallas.push(`${e}: abierto, contraste bajo 4.5:1 en ${ab.contrasteBajo.join(', ')}`);
    if (ab.enlaceAlto < 44) fallas.push(`${e}: un enlace de fuente mide ${ab.enlaceAlto} px de alto (mínimo 44)`);
    if (ab.desborda) fallas.push(`${e}: con el detalle abierto la página desborda`);
    await page.close();
  }
} finally { await browser.close(); servidor.close(); }
if (fallas.length) { console.error('COMPARATIVO_FALLA\n' + fallas.join('\n')); process.exit(1); }
console.log('COMPARATIVO_OK');
