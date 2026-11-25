#!/usr/bin/env python3
"""25-nov-2026: cada referencia local a un .css o .js de la landing lleva ?v=<8 primeros hex del sha256 del archivo>, para que un cambio publicado nunca conviva con un archivo viejo en la caché del navegador o de la red de Pages.
Uso: python3 ops/version-cache.py          reescribe las referencias (idempotente)
     python3 ops/version-cache.py --check  falla (exit 1) si alguna falta o está vieja"""
import hashlib, pathlib, re, sys
RAIZ = pathlib.Path(__file__).resolve().parent.parent
REF = re.compile(r'((?:href|src)=")([^"#?:]+\.(?:css|js))(?:\?v=[0-9a-f]+)?(")')
def huella(p): return hashlib.sha256(p.read_bytes()).hexdigest()[:8]
malas, cambios = [], 0
for h in sorted(list(RAIZ.glob('*.html')) + list(RAIZ.glob('panel/*.html'))):
    txt = h.read_text(encoding='utf-8')
    def sustituir(m):
        arch = (h.parent / m.group(2)) if not m.group(2).startswith('/') else (RAIZ / m.group(2).lstrip('/'))
        if not arch.is_file(): return m.group(0)
        return f'{m.group(1)}{m.group(2)}?v={huella(arch)}{m.group(3)}'
    nuevo = REF.sub(sustituir, txt)
    if nuevo != txt:
        if '--check' in sys.argv: malas.append(h.name)
        else: h.write_text(nuevo, encoding='utf-8'); cambios += 1
if malas: print('VERSION_CACHE_FALLA: referencias sin versión o viejas en', ', '.join(malas), '(corre python3 ops/version-cache.py)'); sys.exit(1)
print('VERSION_CACHE_OK' + ('' if '--check' in sys.argv else f' ({cambios} página(s) actualizadas)'))
