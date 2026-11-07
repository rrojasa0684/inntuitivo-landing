// #206 y #207: valida el JSON de la tabla de decisores ANTES de publicarlo (lo corre el trabajo diario de publicación). Toda cifra de terceros lleva URL https, quién la midió y fecha de consulta;
// ninguna celda propia lleva un porcentaje (#207: el propio solo cuando pase del 40 %); ninguna cifra de relleno del diseño. Uso: node datos-decisores-validar.mjs archivo.json. Salida: DATOS_DECISORES_VALIDOS o error (exit 1).
import { readFileSync } from 'node:fs';

// #211: los enlaces de las fuentes se limitan a estos dominios (la misma lista que DOMINIOS_APROBADOS del motor, app/datos_decisores_publicos.py).
const APROBADOS = ['dev.to', 'bouncezero.io', 'www.clay.com', 'docs.x.ai'];
const aprobado = (u) => { try { const p = new URL(u); return p.protocol === 'https:' && !p.username && (p.port === '' || p.port === '443') && APROBADOS.includes(p.hostname); } catch (e) { return false; } };
const errores = [];
let d;
try { d = JSON.parse(readFileSync(process.argv[2], 'utf8')); } catch (e) { console.error('JSON ilegible: ' + e.message); process.exit(1); }
if (JSON.stringify((d.columnas || []).map((c) => c.id)) !== JSON.stringify(['inntuitivo', 'apollo', 'clay', 'explee', 'grok']) || (d.columnas || []).some((c) => !c.nombre) || !Array.isArray(d.filas) || !d.filas.length || d.filas.some((f) => !f.id || !f.atributo) || new Set(d.filas.map((f) => f.id)).size !== d.filas.length) errores.push('estructura: columnas exactas (inntuitivo, apollo, clay, explee, grok, con nombre) y filas con id único y atributo');
else for (const f of d.filas) for (const c of d.columnas) {
  const ce = f.celdas?.[c.id], k = `${f.id}.${c.id}`;
  if (!ce || !['informado', 'no_informado'].includes(ce.estado) || !Array.isArray(ce.datos)) { errores.push(`${k}: celda mal formada`); continue; }
  if (ce.estado === 'informado' && !ce.datos.length) errores.push(`${k}: informada sin datos`);
  for (const x of ce.datos) {
    if (typeof x.texto !== 'string' || !x.texto) errores.push(`${k}: dato sin texto`);
    if (c.id !== 'inntuitivo' && ce.propio === true) errores.push(`${k}: «propio» solo vale en la columna de Inntuitivo`);
    if (c.id === 'inntuitivo' && ce.propio !== true) errores.push(`${k}: la celda de Inntuitivo debe ser propia`);
    if (ce.propio === true) { if (/\d\s*%|\d+\s+de\s+\d+|por\s*ciento/i.test(x.texto)) errores.push(`${k}: cifra propia (#207)`); continue; }
    if (!/^https:\/\/[^\s]+$/.test(x.url || '')) errores.push(`${k}: cifra sin URL https`);
    if (/^https:\/\/[^\s]+$/.test(x.url || '') && !aprobado(x.url)) errores.push(`${k}: dominio de la fuente fuera de la lista aprobada (#211)`);
    if (!x.midio || !x.fecha_consulta) errores.push(`${k}: falta quién midió o la fecha de consulta`);
  }
}
if (/(^|[^0-9,.])(64|51|48|46|29|28)[\s\u00a0]*%/.test(JSON.stringify(d))) errores.push('aparece una cifra de relleno del diseño o el porcentaje propio');
if (errores.length) { console.error('DATOS_DECISORES_INVALIDOS\n' + errores.join('\n')); process.exit(1); }
console.log('DATOS_DECISORES_VALIDOS');
