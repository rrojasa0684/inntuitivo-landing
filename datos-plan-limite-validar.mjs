// #227: valida datos-plan-limite.json ANTES de publicarlo: correos_por_dia es un entero de 1 a 1000 (nunca una cifra escrita a mano). Uso: node datos-plan-limite-validar.mjs <archivo>
import { readFileSync } from 'node:fs';

let d;
try { d = JSON.parse(readFileSync(process.argv[2], 'utf8')); } catch (e) { console.error('JSON ilegible: ' + e.message); process.exit(1); }
const n = d && d.correos_por_dia;
if (!Number.isInteger(n) || n < 1 || n > 1000) { console.error('correos_por_dia no es un entero de 1 a 1000'); process.exit(1); }
console.log('plan-limite ok: ' + n);
