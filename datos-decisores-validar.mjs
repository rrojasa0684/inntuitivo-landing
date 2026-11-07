// #206 y #207: valida el JSON de la tabla de decisores ANTES de publicarlo (lo corre el trabajo diario de publicación). Toda cifra de terceros lleva URL https, quién la midió y fecha de consulta;
// ninguna celda propia lleva un porcentaje (#207: el propio solo cuando pase del 40 %); ninguna cifra de relleno del diseño. Uso: node datos-decisores-validar.mjs archivo.json. Salida: DATOS_DECISORES_VALIDOS o error (exit 1).
import { readFileSync } from 'node:fs';

const errores = [];
let d;
try { d = JSON.parse(readFileSync(process.argv[2], 'utf8')); } catch (e) { console.error('JSON ilegible: ' + e.message); process.exit(1); }
if (!Array.isArray(d.columnas) || d.columnas[0]?.id !== 'inntuitivo' || !Array.isArray(d.filas) || !d.filas.length) errores.push('estructura: faltan columnas (inntuitivo primero) o filas');
else for (const f of d.filas) for (const c of d.columnas) {
  const ce = f.celdas?.[c.id], k = `${f.id}.${c.id}`;
  if (!ce || !['informado', 'no_informado'].includes(ce.estado) || !Array.isArray(ce.datos)) { errores.push(`${k}: celda mal formada`); continue; }
  if (ce.estado === 'informado' && !ce.datos.length) errores.push(`${k}: informada sin datos`);
  for (const x of ce.datos) {
    if (typeof x.texto !== 'string' || !x.texto) errores.push(`${k}: dato sin texto`);
    if (ce.propio === true) { if (/\d\s*%/.test(x.texto)) errores.push(`${k}: porcentaje propio (#207)`); continue; }
    if (!/^https:\/\/[^\s]+$/.test(x.url || '')) errores.push(`${k}: cifra sin URL https`);
    if (!x.midio || !x.fecha_consulta) errores.push(`${k}: falta quién midió o la fecha de consulta`);
  }
}
if (/(^|[^0-9,.])(64|51|48|46|29|28) ?%/.test(JSON.stringify(d))) errores.push('aparece una cifra de relleno del diseño o el porcentaje propio');
if (errores.length) { console.error('DATOS_DECISORES_INVALIDOS\n' + errores.join('\n')); process.exit(1); }
console.log('DATOS_DECISORES_VALIDOS');
