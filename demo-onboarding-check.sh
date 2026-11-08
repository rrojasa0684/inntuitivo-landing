#!/usr/bin/env bash
# Demo del agente (#157 a #160), tramo D2: onboarding.html muestra la franja Demo y el buzón de ejemplo SOLO si el motor
# dice demo:true; nunca pide credenciales en el demo; sigue noindex; el flujo real queda intacto.
set -euo pipefail
f=onboarding.html
fail(){ echo "::error::demo-onboarding-check: $1" >&2; exit 1; }
[ "$(grep -c '<meta name="robots" content="noindex' $f)" = "1" ] || fail "debe haber exactamente un meta robots noindex"
grep -q 'd.demo===true' $f || fail "la rama demo debe depender de estado.demo===true"
[ "$(grep -c 'activarDemo(d);' $f)" = "1" ] || fail "activarDemo debe llamarse una sola vez, bajo d.demo===true"
grep -q 'if(d.demo===true)activarDemo(d)' $f || fail "activarDemo no está condicionada a demo===true"
grep -q 'Demo — así ve un cliente su agente. No se cobra ni se envía nada.' $f || fail "falta el texto de la franja"
grep -q "setAttribute('role','status')" $f || fail "la franja necesita role=status"
grep -q 'En el demo no conectamos tu correo.' $f || fail "falta el aviso del buzón de ejemplo"
grep -q 'buzon.demo.correo' $f || fail "falta mostrar buzon.demo.correo"
grep -q "llamar('probar',{})" $f || fail "el demo debe llamar a conectar/probar con cuerpo vacío"
grep -q "remove();});   // sin campos de contraseña" $f || fail "el demo debe quitar el formulario real (contraseña/Microsoft) del DOM"
# la franja no se renderiza en el markup estático (solo la crea el JS en demo)
grep -q 'id="demo-franja"' <(sed -n '/<body>/,/<script>/p' $f) && fail "la franja no puede estar en el HTML estático"
# el flujo real sigue: probar con email y password
grep -q 'const cuerpo={email,password}' $f || fail "regresión: el flujo real de conexión cambió"
# el demo nunca envía credenciales: el bloque activarDemo no lee password ni email
blk=$(sed -n '/^function activarDemo/,/^}/p' $f)
echo "$blk" | grep -qi "password\|\$('email')\|microsoft/inicio" && fail "activarDemo no puede tocar credenciales ni OAuth"
# el token del demo viaja en el fragmento (#token=) y sale de la barra apenas se lee; el del flujo real sigue en la query
grep -q "new URLSearchParams(location.search).get('token')" $f || fail "regresión: el flujo real lee el token de la query"
grep -q "new URLSearchParams(location.hash.slice(1)).get('token')" $f || fail "el demo debe leer el token del fragmento"
grep -q "history.replaceState(null,'',location.pathname);return f;" $f || fail "el token del fragmento debe salir de la barra al leerse"
# 8-nov: «Lo hago después» de la prueba vive fuera de #bloque-conectar (ese bloque se oculta con el bloqueo de Microsoft y el botón desaparecía)
grep -q "b.parentNode.insertBefore(s,b);" $f || fail "«Lo hago después» (btn-saltar) debe insertarse fuera de #bloque-conectar"
grep -q "d0.parentNode.insertBefore(s,d0)" $f && fail "«Lo hago después» no puede ir dentro de #bloque-conectar (junto a btn-despues)"
echo DEMO_ONBOARDING_OK
