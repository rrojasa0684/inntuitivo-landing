#!/usr/bin/env bash
# Textos vigentes del sitio (#107, 30-oct-2026): (1) los textos bloqueados siguen literales; (2) ninguna página dice que el agente envía
# desde inntuitivo.com / la infraestructura de Inntuitivo, que hay un tope de 300 al mes, "modo plataforma" o que se escribe "a mano";
# (3) todo JSON-LD parsea y cada pregunta del FAQ coincide con su <details> visible.
set -euo pipefail
python3 - <<'PY'
import glob, hashlib, html, json, re, sys
mal = []
idx = open("index.html", encoding="utf-8").read()
BLOQUEADOS = [
 "🎯 Para pymes y startups B2B que venden a empresas",
 "Un agente de IA que <em>consigue clientes 24/7</em> mientras tú duermes&nbsp;🚀",
 "Pon tus ventas en órbita 🪐 de manera intuitiva 🚀",
 "🪐 Tu plataforma de agentes de IA más innovadora e inntuitiva ✨",
 "Agentes que trabajan por ti 24/7, en tu idioma, sin que aprendas nada técnico.",
 "Tu agente busca empresas en la web abierta, no en una base de datos comprada. Lee el sitio de cada una y escribe un correo que cita un dato real, con su fuente. Envía a ritmo humano, sin caer en spam, y te avisa solo cuando alguien responde en serio.",
 "Quienes impulsan a Inntuitivo 🚀",
 "Empresas, startups, inversionistas, programas, plataformas y equipos con los que trabajamos para poner tu agente de IA en órbita. 🪐",
 "🪐 Partners",
]
for b in BLOQUEADOS:
    if b not in idx: mal.append(f"texto bloqueado ausente o cambiado: {b}")
if "Conecta tu correo y tu agente arranca solo: prospecta, escribe y envía en tu nombre. Lo haces una vez — no tienes que volver a tocarlo. Todo sale desde tu propio correo, con tu firma y tu marca.</p>" not in idx:
    mal.append("el párrafo del hero cambió (frase completa aprobada, #107/#115)")
# huella del bloque bloqueado completo (sin comentarios HTML ni espacios): hero con su panel y carrusel de partners
def huella(ini, fin):
    i = idx.find(ini); j = idx.find(fin, i)
    if i < 0 or j < 0: return None
    b = re.sub(r"\s+", " ", re.sub(r"<!--.*?-->", "", idx[i:j + len(fin)], flags=re.S)).strip()
    return hashlib.sha256(b.encode()).hexdigest()
HUELLAS = {"hero (con su panel)": ('<header class="hero">', "</header>", "d95fa56731deaf7b1e90a01ee1218fc8c23a2eafc39e2fc98ce7852a46c95350"),
           "partners (con su carrusel)": ('<section class="partners"', "</section>", "3d9fed73b1cccd9fae3c67745a2d96177065c373a891e1684c684cbe7a000b6a")}
for nombre, (ini, fin, esperada) in HUELLAS.items():
    if huella(ini, fin) != esperada: mal.append(f"bloque bloqueado cambiado: {nombre} (si Ricardo aprobó el cambio, actualizar la huella)")
PROHIBIDAS = ["desde inntuitivo.com", "300 al mes", "modo plataforma", "infraestructura de Inntuitivo", "infraestructura de inntuitivo", "a mano", "25 contactos", "un clic", "un solo toque", "con un toque"]
# usos legítimos de "a mano" que no hablan del agente (no se tocan: fuera de lo aprobado)
PERMITIDAS = ["Prospectar a mano", "selector armado a mano", "te ayudamos a mano", "Te escribo porque trabajo con despachos"]
for f in sorted(glob.glob("*.html")):
    t = open(f, encoding="utf-8").read()
    for linea in t.splitlines():
        low = linea.lower()
        for p in PROHIBIDAS:
            if p.lower() not in low: continue
            if p == "a mano" and any(x in linea for x in PERMITIDAS): continue
            if p == "un clic" and ("verificarlo en un clic" in linea or "verificable en un clic" in linea): continue   # otro uso: la fuente de cada dato, no la conexión con Microsoft
            if p.lower() == "modo plataforma" and f == "cancelar.html" and linea.strip().startswith("//"): continue
            mal.append(f"{f}: '{p}' en: {linea.strip()[:90]}")
# JSON-LD válido y FAQ == HTML
faq = []
for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', idx, re.S):
    try: d = json.loads(m.group(1))
    except Exception as e: mal.append(f"JSON-LD inválido: {e}"); continue
    for nodo in (d.get("@graph", [d]) if isinstance(d, dict) else d):
        if nodo.get("@type") == "FAQPage":
            faq = [(q["name"], q["acceptedAnswer"]["text"]) for q in nodo["mainEntity"]]
norm = lambda s: re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s))).strip()
det = {norm(m.group(1)): norm(m.group(2)) for m in re.finditer(r"<details>\s*<summary>(.*?)</summary>(.*?)</details>", idx, re.S)}
for q, a in faq:
    if q not in det: mal.append(f"pregunta del JSON-LD sin su <details>: {q}")
    elif det[q] != norm(a): mal.append(f"respuesta distinta entre JSON-LD y HTML: {q}")
for q in det:
    if q not in {x for x, _ in faq}: mal.append(f"pregunta visible sin su entrada en el JSON-LD: {q}")
if not any(q == "¿Qué es un agente SDR y qué hace el mío?" for q, _ in faq): mal.append("falta la pregunta del SDR")
if any("a mano" in a for _, a in faq): mal.append("el FAQ dice 'a mano'")
# #169: la respuesta del SDR dice que Inntuitivo es tu SDR con IA (aprobado por Ricardo)
SDR_A = dict(faq).get("¿Qué es un agente SDR y qué hace el mío?", "")
if "Inntuitivo es tu SDR con IA: hace ese trabajo por ti. Busca empresas" not in SDR_A or "Tu agente de IA hace ese trabajo" in SDR_A: mal.append("la respuesta del SDR no dice «Inntuitivo es tu SDR con IA» (#169)")
# #124: la pregunta de Microsoft 365, con su respuesta exacta, en el JSON-LD (y, por la igualdad de arriba, en el <details> visible)
MS_P = "¿Funciona con Microsoft 365?"
MS_R = "Sí. Solo inicias sesión. En algunas empresas el administrador aprueba la conexión una vez: te guiamos y le escribimos por ti."
if (MS_P, MS_R) not in faq: mal.append("falta la pregunta «¿Funciona con Microsoft 365?» con su respuesta aprobada (#124)")
# #168: la pregunta de las listas, con su respuesta exacta, y la línea de «Cómo funciona» (aprobadas por Ricardo)
LS_P = "¿Puedo usar mis listas de Apollo, Lusha, Hunter o Explee?"
LS_R = "Sí. Desde tu panel subes tus listas en CSV o Excel. Tu agente las suma a las empresas que encuentra solo en la web abierta, las filtra con tu perfil de cliente ideal, busca a quien decide, verifica cada correo antes de escribir y les escribe con tu marca. Tus listas son solo tuyas: nadie más las usa."
LS_L = "¿Ya tienes tus listas? Súbelas y tu agente las filtra, verifica cada correo y les escribe como a las empresas que encuentra solo."
if (LS_P, LS_R) not in faq: mal.append("falta la pregunta de las listas con su respuesta aprobada (#168)")
if '<p class="listas-linea">' + LS_L + '</p>' not in idx: mal.append("falta la línea de las listas en «Cómo funciona» (#168)")
# #175/#176: textos aprobados de la prueba gratis y de los llamados «Ver demo 💰» (aprobados por Ricardo)
PG = ["Pruébalo gratis", "Escribe tu sitio: tu agente entiende qué vendes y a quién.",
 "Tu agente busca a tus clientes ideales, busca a quien decide y les escribe.",
 "Lo ves todo en tu panel, listo para enviar. Activa cuando quieras.",
 "Escribe tu sitio y tu agente hace el trabajo con tu empresa. No envía nada hasta que actives.", "Tú · 30 segundos", "Tu agente</span>", "Tu panel</span>",
 "créditos gratis</span><small>1 crédito = 1 lead completo</small>", "<li>Empresa que encaja</li><li>Correo verificado</li><li>Quien decide, si es público</li><li>Correo ya redactado</li>",
 "Probar gratis 🚀", "Sin tarjeta · No envía nada hasta que actives · Se borra a los 14 días si no activas"]      # #181: la sección rediseñada (la línea larga de créditos se reemplazó por la franja)
for t in PG:
    if t not in idx: mal.append(f"falta el texto aprobado de la prueba gratis (#175): {t[:50]}")
if 'id="prueba"' not in idx or '<span id="muestra"></span>' not in idx: mal.append("falta la sección #prueba con el alias #muestra (#175)")
if idx.count("Ver demo 💰") != 3: mal.append("deben quedar exactamente 3 llamados «Ver demo 💰» (barra, hero y precio; #176, #181)")
if "demo/estado" in idx: mal.append("la landing no puede ocultar «Pruébalo gratis» según /demo/estado: la prueba real nunca se apaga por el demo (#160, review 5-nov)")
# #180/#181: los «Ver demo 💰» de la barra, el hero y el precio bajan a #prueba; lo único que abre el demo es el formulario de la sección (origen «prueba»)
import re as _re
_demo=[m.group(0) for m in _re.finditer(r'<a [^>]*data-ver-demo[^>]*>', idx)]
if sorted(_re.search(r'data-ver-demo-origen="(\w+)"',x).group(1) for x in _demo if 'data-ver-demo-origen=' in x)!=["barra","hero","precio"] or any('href="#prueba"' not in x for x in _demo): mal.append("los Ver demo de barra, hero y precio deben apuntar a #prueba (#180)")
_abre=[m.group(0) for m in _re.finditer(r'<[^>]*api\.inntuitivo\.com/demo[^>]*>', idx)]
if len(_abre)!=1 or 'id="prueba-form"' not in _abre[0] or 'method="get"' not in _abre[0]: mal.append("lo único que abre el demo es el formulario de la sección Pruébalo gratis (#181)")
if 'name="o" value="prueba"' not in idx or 'name="sitio"' not in idx or 'for="prueba-sitio"' not in idx: mal.append("el formulario de la sección debe llevar el origen prueba, el campo sitio y su etiqueta (#181)")
if "style=" in idx[idx.index('<section id="prueba">'):idx.index('<section id="precio">')]: mal.append("la sección Pruébalo gratis no puede llevar estilos en línea (CSP, #181)")
if "Ver una muestra gratis" in idx or "Pide una muestra gratis" in idx or 'id="ms-form"' in idx: mal.append("quedó la muestra gratis anterior en la landing (#175)")
# #179: textos legales de la prueba gratis, tal cual los aprobó Ricardo, y ninguna línea de la muestra por correo
TER = open("terminos.html", encoding="utf-8").read(); PRI = open("privacidad.html", encoding="utf-8").read()
LEGAL_T = ["<h2>7. Prueba gratis</h2>", "Puedes probar Inntuitivo gratis una vez por empresa. Con tu sitio y tu correo de trabajo, tu agente busca clientes posibles, busca a quien decide (cuando su nombre es público) y redacta correos que ves en tu panel, hasta usar los créditos de la prueba. Durante la prueba no se envía ningún correo. Si no activas tu agente, borramos tu prueba y todos sus datos a los 14 días. Si lo activas, tus leads pasan a tu cuenta."]
LEGAL_P = ["<strong>Prueba gratis:</strong> guardamos tu sitio, tu correo de trabajo y los leads que tu agente encuentra, solo para mostrártelos en tu panel. Se borran a los 14 días si no activas, o pasan a tu cuenta si activas. Los datos de empresas y personas que aparecen como leads son datos profesionales públicos, con su fuente."]
for x in LEGAL_T:
    if x not in TER: mal.append(f"terminos.html: falta el texto legal aprobado (#179): {x[:50]}")
for x in LEGAL_P:
    if x not in PRI: mal.append(f"privacidad.html: falta el texto legal aprobado (#179): {x[:50]}")
for viejo in ["La muestra gratuita", "La muestra no tiene costo", "Limitamos una muestra por dominio", "muestra gratuita", "formulario público de muestras", "Solicitudes de muestra"]:
    for nombre, doc in (("terminos.html", TER), ("privacidad.html", PRI)):
        if viejo in doc: mal.append(f"{nombre}: quedó el texto de la muestra por correo (#179): {viejo}")
# #190: ningún texto público promete «encuentra a quien decide» sin condición (el buscador lo halla en ~34 % de las empresas)
for nombre, doc in (("index.html", idx), ("terminos.html", TER), ("privacidad.html", PRI)):
    if _re.search(r"encuentra (a )?quien(es)? decid", doc, _re.I): mal.append(f"{nombre}: promete «encuentra a quien decide» sin condición (#190)")
FAQ_190 = "verifica cada correo, busca a quien decide y, cuando su nombre es público, te dice quién es. Redacta el correo, con la fuente de cada dato."
if idx.count(FAQ_190) != 2: mal.append("la pregunta de la prueba gratis debe decir «busca a quien decide y, cuando su nombre es público, te dice quién es» en el HTML y en el JSON-LD (#190)")
print("TEXTOS_ACTUALES_OK" if not mal else "\n".join(mal))
sys.exit(1 if mal else 0)
PY
