// 25-nov-2026: la parte del chequeo en vivo que necesita un navegador (la tabla vieja la dibujaba JavaScript, un curl no la veía). Contexto NUEVO de Playwright (sin caché, sin cookies), carga <base>/ y falla si:
//  - el texto visible trae «Cifras públicas de terceros» o «De dónde sale el decisor»;
//  - falta «Ver las fuentes» (el desplegable de la sección 2);
//  - la página pide algo de datos-decisores o de /datos/decisores-publicos (ya no se muestran);
//  - la página desborda horizontalmente a 360, 390, 430 o 1280 px.
// 25-nov-2026, comparativo en móvil (360x780, 390x844, 414x896 y 1280x800): pista de deslizar si alguna columna asoma cortada; Inntuitivo y Apollo completas al inicio en celular; primera columna fija al deslizar; el botón de volver arriba no tapa ninguna celda; UN solo borde en «Ver las fuentes», centrado y con aire entre texto e ícono; ninguna etiqueta de fila pasa de 3 líneas; nada visible entre el borde superior y la cabecera fija (opaca); los anclajes respetan la altura real de la cabecera; en 1280 no hay pista y las etiquetas siguen largas.
// Uso: node chequeo-en-vivo-navegador.mjs <base>. Salida: NAVEGADOR_OK o NAVEGADOR_FALLA y la lista (exit 1).
import { chromium, webkit, devices } from 'playwright';
const base = (process.argv[2] || 'https://www.inntuitivo.com').replace(/\/$/, '');
const fallas = [];
for (const [motor, tipo] of [['chromium', chromium], ['webkit', webkit]]) {
const browser = await tipo.launch();
// WebKit en 390 usa el perfil del iPhone 13; el resto, ventana con ese ancho
const opts = (w, h, extra = {}) => (motor === 'webkit' && w === 390 ? { ...devices['iPhone 13'], serviceWorkers: 'block', ...extra } : { viewport: { width: w, height: h }, hasTouch: w < 500, serviceWorkers: 'block', ...extra });
try {
  for (const w of [360, 390, 430, 1280]) {
    const ctx = await browser.newContext(opts(w, 900));
    const page = await ctx.newPage(), pedidos = [];
    page.on('request', (r) => pedidos.push(r.url()));
    await page.goto(base + '/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(600);
    const r = await page.evaluate(() => ({ t: document.body.innerText, desborda: document.documentElement.scrollWidth > innerWidth }));
    for (const x of ['Cifras públicas de terceros', 'De dónde sale el decisor']) if (r.t.includes(x)) fallas.push(`${motor}@${w}: el sitio publicado muestra «${x}»`);
    if (!r.t.includes('Ver las fuentes')) fallas.push(`${motor}@${w}: falta «Ver las fuentes» en la sección 2`);
    const viejo = pedidos.filter((u) => /datos-decisores|datos\/decisores-publicos/.test(u));
    if (viejo.length) fallas.push(`${motor}@${w}: la página todavía pide ${viejo.join(', ')}`);
    if (r.desborda) fallas.push(`${motor}@${w}: la página desborda horizontalmente`);
    await ctx.close();
  }
  // --- comparativo en móvil y escritorio (25-nov) ---
  for (let [w, h] of [[360, 780], [390, 844], [414, 896], [1280, 800]]) {
    const ctx = await browser.newContext(opts(w, h));
    const page = await ctx.newPage();
    h = page.viewportSize().height; // el perfil del iPhone 13 trae su propio alto
    await page.goto(base + '/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(500);
    const e = `${motor}@${w}x${h}`;
    try {
      if (w === 1280) { const css = await page.evaluate(() => document.documentElement.outerHTML); if (/\b100vw\b/.test(css)) fallas.push(`${e}: el CSS usa 100vw (con barra de desplazamiento ensancha la página); usar sombra o 100vmax`); }
    if (!(await page.$('.cmp-wrap'))) { fallas.push(`${e}: no hay tabla comparativa`); await ctx.close(); continue; }
    const irA = (y) => page.evaluate((yy) => { document.documentElement.style.scrollBehavior = 'auto'; window.scrollTo(0, yy); }, y);
    const topTabla = () => page.evaluate(() => document.querySelector('.cmp-wrap').getBoundingClientRect().top + scrollY);
    await irA((await topTabla()) - 200); await page.waitForTimeout(500);
    // inicio: columnas, pista, etiquetas
    const ini = await page.evaluate(() => {
      const wr = document.querySelector('.cmp-wrap').getBoundingClientRect(), caja = document.querySelector('.cmp-caja'), pista = document.querySelector('.cmp-pista');
      const ths = [...document.querySelectorAll('.cmp thead th')].map((t) => { const r = t.getBoundingClientRect(); return { n: t.innerText.trim().split(/\s/)[0].toLowerCase(), completa: r.left >= wr.left - 0.5 && r.right <= wr.right + 0.5, algoVisible: r.left < wr.right - 0.5 && r.right > wr.left + 0.5 }; });
      const pistaVisible = !pista.hidden && getComputedStyle(pista).display !== 'none' && pista.getBoundingClientRect().height > 0 && /^Desliza para ver .+ →$/.test(pista.textContent) && caja.classList.contains('cmp-scroll');
      const lineas = [...document.querySelectorAll('.cmp tbody th')].map((th) => { const sp = [...th.querySelectorAll('span')].find((x) => getComputedStyle(x).display !== 'none') || th; const rects = [...(function () { const r = document.createRange(); r.selectNodeContents(sp); return r.getClientRects(); })()]; return new Set(rects.map((q) => Math.round(q.top))).size; });
      const largo = getComputedStyle(document.querySelector('.cmp .lab-largo')).display !== 'none';
      return { ths, pistaVisible, lineas, largo, scrolla: document.querySelector('.cmp-wrap').scrollWidth > document.querySelector('.cmp-wrap').clientWidth + 1, corte: ths.some((t) => ['apollo', 'clay', 'explee', 'grok'].includes(t.n) && t.algoVisible && !t.completa) };
    });
    if (w < 500) {
      for (const n of ['inntuitivo', 'apollo']) if (!ini.ths.find((t) => t.n === n)?.completa) fallas.push(`${e}: la columna ${n} no se ve completa al inicio`);
      if (!ini.pistaVisible) fallas.push(`${e}: falta la pista «Desliza para ver Clay, Explee y Grok →»`);
      if (!ini.ths.some((t) => t.n === 'clay' && t.algoVisible)) fallas.push(`${e}: no asoma la columna siguiente (Clay)`);
      if (ini.largo) fallas.push(`${e}: en celular deben verse las etiquetas cortas`);
    } else {
      if (ini.scrolla || ini.pistaVisible || ini.corte) fallas.push(`${e}: en escritorio la tabla debe verse completa, sin pista ni scroll (scrolla ${ini.scrolla}, pista ${ini.pistaVisible}, cortada ${ini.corte})`);
      if (!ini.largo) fallas.push(`${e}: en escritorio las etiquetas deben seguir largas`);
    }
    if (ini.corte && !ini.pistaVisible) fallas.push(`${e}: una columna de competidor asoma cortada sin la pista de deslizar`);
    if (Math.max(...ini.lineas) > 3) fallas.push(`${e}: una etiqueta de fila ocupa ${Math.max(...ini.lineas)} líneas (máximo 3)`);
    // primera columna fija al deslizar y pista fuera al llegar al final
    if (ini.scrolla) {
      const fij = await page.evaluate(async () => { const wrp = document.querySelector('.cmp-wrap'); wrp.scrollLeft = wrp.scrollWidth; await new Promise((r) => setTimeout(r, 300));
        const wr = wrp.getBoundingClientRect(), th = document.querySelector('.cmp tbody th').getBoundingClientRect(), hd = document.querySelector('.cmp thead .cmp-th-lab').getBoundingClientRect(), bg = getComputedStyle(document.querySelector('.cmp tbody th')).backgroundColor;
        const pp = document.querySelector('.cmp-pista'), pista = pp.hidden ? 'none' : getComputedStyle(pp).display; const grok = [...document.querySelectorAll('.cmp thead th')].pop().getBoundingClientRect();
        const r = { fijaTh: Math.abs(th.left - wr.left) <= 1, fijaHd: Math.abs(hd.left - wr.left) <= 1, bgOpaco: !/rgba\(.*,\s*0(\.\d+)?\)$/.test(bg) && bg !== 'transparent', pistaFin: pista, grokCompleta: grok.right <= wr.right + 1 && grok.left >= wr.left }; wrp.scrollLeft = 0; return r; });
      if (!fij.fijaTh || !fij.fijaHd || !fij.bgOpaco) fallas.push(`${e}: la primera columna no queda fija y opaca al deslizar (${JSON.stringify(fij)})`);
      if (fij.pistaFin !== 'none') fallas.push(`${e}: la pista no desaparece al llegar al final`);
      if (!fij.grokCompleta) fallas.push(`${e}: Grok no queda completa al final del deslizamiento`);
    }
    // el botón de volver arriba no tapa ninguna celda (en varias posiciones de la página con la tabla en pantalla)
    const t0 = await topTabla(), alto = await page.evaluate(() => document.querySelector('.cmp-wrap').offsetHeight);
    for (const off of [h - 120, h / 2, 80, 0, -(alto - h + 120)]) {
      await irA(Math.max(t0 - off, h + 40)); await page.waitForTimeout(450);
      const tapa = await page.evaluate(() => { const b = document.querySelector('.top-btn'), st = getComputedStyle(b); const vis = st.visibility !== 'hidden' && parseFloat(st.opacity) > 0.05; if (!vis) return null;
        const r = b.getBoundingClientRect(); return [...document.querySelectorAll('.cmp td, .cmp th')].filter((c) => { const q = c.getBoundingClientRect(); return q.width && q.left < r.right && q.right > r.left && q.top < r.bottom && q.bottom > r.top && q.top < innerHeight && q.bottom > 0; }).length; });
      if (tapa) fallas.push(`${e}: el botón de volver arriba tapa ${tapa} celda(s) de la tabla`);
    }
    // cabecera fija: opaca, a todo el ancho y sin nada visible entre el borde superior y ella
    await irA((await topTabla()) - 260); await page.waitForTimeout(500);
    const nv = await page.evaluate(() => { const nav = document.querySelector('nav'), r = nav.getBoundingClientRect(), bg = getComputedStyle(nav, '::before').backgroundColor, bgn = getComputedStyle(nav).backgroundColor; const malos = [];
      for (const y of [1, Math.round(r.bottom / 2), Math.round(r.bottom) - 2]) for (const x of [Math.round(r.left) + 1, Math.round(r.left + r.width * 0.3), Math.round(r.left + r.width * 0.7), Math.round(r.right) - 2]) { const el = document.elementFromPoint(x, y); if (!el || !(nav.contains(el) || el === nav)) malos.push(`(${x},${y}) ${el && el.tagName + '.' + el.className}`); }
      const sombra = getComputedStyle(nav, '::before').boxShadow; return { top: r.top, sombra, bg, bgn, malos, navH: Math.round(r.height), prop: getComputedStyle(document.documentElement).getPropertyValue('--nav-h') }; });
    if (Math.abs(nv.top) > 1) fallas.push(`${e}: la cabecera fija no está pegada al borde superior (top ${nv.top})`);
    if (!/rgb\(13, 7, 34\)/.test(nv.bgn) || !/rgb\(13, 7, 34\)/.test(nv.bg)) fallas.push(`${e}: la cabecera no es opaca (${nv.bgn} / ${nv.bg})`);
    if (!/rgb\(13, 7, 34\)/.test(nv.sombra)) fallas.push(`${e}: la franja opaca de la cabecera no llega de borde a borde (sombra de relleno ausente)`);
    if (nv.malos.length) fallas.push(`${e}: hay contenido visible junto o sobre la cabecera fija: ${nv.malos.join('; ')}`);
    if (Math.abs(parseFloat(nv.prop) - nv.navH) > 1) fallas.push(`${e}: --nav-h (${nv.prop}) no es la altura real de la cabecera (${nv.navH})`);
    // anclajes (#activar y #prueba, los de la cabecera): el destino queda justo bajo la cabecera, sin taparse
    for (const id of ['activar', 'prueba']) {
      await irA(0); await page.waitForTimeout(300);
      await page.evaluate((i) => { document.documentElement.style.scrollBehavior = 'auto'; document.querySelector(`a[href="#${i}"]`).click(); }, id); await page.waitForTimeout(900);
      const an = await page.evaluate((i) => ({ top: document.getElementById(i).getBoundingClientRect().top, nav: document.querySelector('nav').getBoundingClientRect().bottom }), id);
      if (an.top < an.nav - 2 || an.top > an.nav + 40) fallas.push(`${e}: el anclaje #${id} queda a ${Math.round(an.top)} px y la cabecera termina en ${Math.round(an.nav)} px`);
    }
    // «Ver las fuentes»: un solo borde, centrado, con aire entre texto e ícono
    await page.evaluate(() => { const d = document.querySelector('.dec-detalle'); d.open = false; d.scrollIntoView({ block: 'center' }); }); await page.waitForTimeout(500);
    const bd = await page.evaluate(() => { const d = document.querySelector('.dec-detalle'), sum = d.querySelector('summary'), sr = sum.getBoundingClientRect(), dr = d.getBoundingClientRect();
      const conBorde = (el) => ['Top', 'Right', 'Bottom', 'Left'].some((l) => parseFloat(getComputedStyle(el)['border' + l + 'Width']) > 0 && getComputedStyle(el)['border' + l + 'Style'] !== 'none');
      let cajas = 0; for (let el = sum; el && el !== d.parentElement; el = el.parentElement) if (conBorde(el)) { const q = el.getBoundingClientRect(); if (q.width > 40 && q.height > 30) cajas++; }
      const rg = document.createRange(); rg.selectNodeContents(sum); const tr = rg.getBoundingClientRect(), a = getComputedStyle(sum, '::after');
      return { cajas, centradoV: Math.abs((tr.top + tr.bottom) / 2 - (sr.top + sr.bottom) / 2), aire: (sr.right - parseFloat(a.right) - parseFloat(a.width)) - tr.right, ancho: Math.abs(dr.width - d.parentElement.getBoundingClientRect().width), iconoTop: parseFloat(a.top), alto: sr.height, hijosBorde: [...sum.children].filter(conBorde).length }; });
    if (![bd.aire, bd.iconoTop, bd.alto, bd.centradoV].every(Number.isFinite)) fallas.push(`${e}: no se pudo medir «Ver las fuentes» (${JSON.stringify(bd)})`);
    if (bd.cajas !== 1 || bd.hijosBorde) fallas.push(`${e}: «Ver las fuentes» tiene ${bd.cajas} caja(s) con borde (debe ser 1)`);
    if (bd.centradoV > 3) fallas.push(`${e}: «Ver las fuentes» no está centrado (desvío ${bd.centradoV.toFixed(1)} px)`);
    if (bd.aire < 8) fallas.push(`${e}: el ícono está pegado al texto de «Ver las fuentes» (${bd.aire.toFixed(1)} px de aire)`);
    if (Math.abs(bd.iconoTop - bd.alto / 2) > 4) fallas.push(`${e}: el ícono de «Ver las fuentes» no está en la línea del texto`);
    } catch (err) { fallas.push(`${e}: el chequeo no pudo medir la tabla (${String(err.message).split('\n')[0].slice(0, 120)})`); }
    await ctx.close();
  }
  // --- barrido de anchos: la pista aparece si y solo si hay una columna de competidor sin verse completa a la derecha (25-nov) ---
  for (const w of [360, 390, 414, 480, 520, 560, 600, 650, 700, 768, 1280]) {
    const ctx = await browser.newContext(opts(w, 800));
    const page = await ctx.newPage();
    try {
      await page.goto(base + '/', { waitUntil: 'networkidle' }); await page.waitForTimeout(500);
      await page.evaluate(() => { document.documentElement.style.scrollBehavior = 'auto'; scrollTo(0, document.querySelector('.cmp-wrap').getBoundingClientRect().top + scrollY - 200); }); await page.waitForTimeout(400);
      // WebKit no devuelve la opacidad de un pseudo-elemento (cadena vacía): ahí vale la clase; la opacidad la cubre Chromium
      const medir = () => page.evaluate(() => { const wr = document.querySelector('.cmp-wrap'), lim = wr.getBoundingClientRect().left + wr.clientWidth + 0.5, pi = document.querySelector('.cmp-pista'), caja = document.querySelector('.cmp-caja');
        const ocultas = [...document.querySelectorAll('.cmp thead th')].filter((t) => !t.matches('.cmp-th-lab, .cmp-inn') && t.getBoundingClientRect().right > lim).map((t) => t.textContent.trim());
        return { ocultas, pista: !pi.hidden && getComputedStyle(pi).display !== 'none' && pi.getBoundingClientRect().height > 0, texto: pi.textContent, grad: caja.classList.contains('cmp-scroll') && (() => { const o = parseFloat(getComputedStyle(caja, '::after').opacity); return Number.isNaN(o) || o > 0.5; })(), wrapAncho: wr.clientWidth }; });
      const ini = await medir(), e = `${motor}@${w}`;
      if (ini.ocultas.length && !ini.pista) fallas.push(`${e}: hay columnas ocultas (${ini.ocultas.join(', ')}) y no hay pista`);
      if (!ini.ocultas.length && ini.pista) fallas.push(`${e}: la pista se ve sin columnas ocultas`);
      if (ini.grad !== ini.ocultas.length > 0) fallas.push(`${e}: el degradado ${ini.grad ? 'se ve' : 'falta'} con ${ini.ocultas.length} columna(s) oculta(s)`);
      if (ini.pista) for (const n of ini.ocultas) if (!ini.texto.includes(n)) fallas.push(`${e}: la pista no nombra a ${n} («${ini.texto}»)`);
      if (ini.pista && /Desliza para ver/.test(ini.texto) && ini.ocultas.some((n) => !ini.texto.includes(n))) fallas.push(`${e}: texto de pista incompleto`);
      if (ini.ocultas.length) {
        await page.evaluate(() => { const wr = document.querySelector('.cmp-wrap'); wr.scrollLeft = wr.scrollWidth; }); await page.waitForTimeout(350);
        const fin = await medir();
        if (fin.ocultas.length || fin.pista || fin.grad) fallas.push(`${e}: al llegar al final quedan ${fin.ocultas.length} oculta(s), pista ${fin.pista}, degradado ${fin.grad}`);
      }
    } catch (err) { fallas.push(`${motor}@${w}: el barrido no pudo medir (${String(err.message).split('\n')[0].slice(0, 120)})`); }
    await ctx.close();
  }
} finally { await browser.close(); }
}

if (fallas.length) { console.error('NAVEGADOR_FALLA\n' + fallas.map((f) => '  - ' + f).join('\n')); process.exit(1); }
console.log('NAVEGADOR_OK');
