#!/usr/bin/env bash
# Textos vigentes del sitio (#107, 30-oct-2026): (1) los textos bloqueados siguen literales; (2) ninguna página dice que el agente envía
# desde inntuitivo.com / la infraestructura de Inntuitivo, que hay un tope de 300 al mes, "modo plataforma" o que se escribe "a mano";
# (3) todo JSON-LD parsea y cada pregunta del FAQ coincide con su <details> visible.
set -euo pipefail
python3 - <<'PY'
import glob, html, json, re, sys
mal = []
idx = open("index.html", encoding="utf-8").read()
BLOQUEADOS = [
 "🎯 Para pymes y startups que venden a empresas",
 "Un agente de IA que <em>consigue clientes</em> mientras tú trabajas&nbsp;🚀",
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
if "Conecta tu correo y tu agente arranca solo: prospecta, escribe y envía en tu nombre. Lo haces una vez — no tienes que volver a tocarlo." not in idx:
    mal.append("el párrafo del hero cambió fuera de su última frase")
PROHIBIDAS = ["desde inntuitivo.com", "300 al mes", "modo plataforma", "infraestructura de Inntuitivo", "infraestructura de inntuitivo", "a mano"]
# usos legítimos de "a mano" que no hablan del agente (no se tocan: fuera de lo aprobado)
PERMITIDAS = ["Prospectar a mano", "selector armado a mano", "te ayudamos a mano", "Te escribo porque trabajo con despachos"]
for f in sorted(glob.glob("*.html")):
    t = open(f, encoding="utf-8").read()
    for linea in t.splitlines():
        low = linea.lower()
        for p in PROHIBIDAS:
            if p.lower() not in low: continue
            if p == "a mano" and any(x in linea for x in PERMITIDAS): continue
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
    elif det[q] != norm(a) and not det[q].startswith(norm(a)): mal.append(f"respuesta distinta entre JSON-LD y HTML: {q}")
if not any(q == "¿Qué es un agente SDR y qué hace el mío?" for q, _ in faq): mal.append("falta la pregunta del SDR")
if any("a mano" in a for _, a in faq): mal.append("el FAQ dice 'a mano'")
print("TEXTOS_ACTUALES_OK" if not mal else "\n".join(mal))
sys.exit(1 if mal else 0)
PY
