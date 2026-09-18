// Lista y comportamiento del selector de países, COMPARTIDO entre index.html (la
// muestra gratis) y onboarding.html (activación, tras el pago) -- 17-sep-2026.
// Antes cada página tenía su propia copia de GEO_OPCIONES y su propia versión del
// toggle de chips: si mañana se agrega un país, o cambia el estilo del chip
// marcado, había que tocar los dos archivos y podían divergir sin que nadie lo
// notara. Ahora un solo lugar -- las dos páginas cargan este script (ver
// geo-paises-compartidos-check.sh, que falla si alguna deja de citarlo o si
// alguna vuelve a traer su propia lista hardcodeada).
//
// Orden: los mercados más grandes del ICP primero (México, Colombia, Argentina,
// Chile, Perú, España), después alfabético -- no alfabético puro.
window.GEO_PAISES = [
  'México', 'Colombia', 'Argentina', 'Chile', 'Perú', 'España',
  'Bolivia', 'Costa Rica', 'Ecuador', 'El Salvador', 'Guatemala', 'Honduras',
  'Nicaragua', 'Panamá', 'Paraguay', 'Puerto Rico', 'República Dominicana',
  'Uruguay', 'Venezuela',
];

// Normaliza para comparar (minúsculas, sin acentos) -- mismo criterio que
// app.prospecting.pipeline._norm_pais en outreach-engine, para que "Perú"/"peru"
// matcheen igual en los dos lados.
window.geoNorm = function (s) {
  return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
};

// Arma el HTML de los chips: "Toda Latinoamérica" (atajo, NUNCA se manda como
// valor propio -- ver geoInitChips) + un chip por país de GEO_PAISES. Si se pasa
// `sugerenciaCruda` (el texto que infirió el análisis de onboarding), marca con
// una etiqueta "sugerido" los países que aparecen ahí -- la muestra no tiene
// sugerencia, pasa '' y ningún chip la lleva.
window.geoChipsHTML = function (idTodas, sugerenciaCruda) {
  var nv = window.geoNorm(sugerenciaCruda || '');
  var opts = window.GEO_PAISES.map(function (pais) {
    var sugerido = nv && nv.indexOf(window.geoNorm(pais)) !== -1;
    return '<label class="geo-chip"><input type="checkbox" class="geo-chk" value="' + pais + '">' +
      pais + (sugerido ? '<span class="geo-chip-sug">sugerido</span>' : '') + '</label>';
  }).join('');
  return '<div class="geo-chips">' +
    '<label class="geo-chip geo-chip-todas"><input type="checkbox" id="' + idTodas + '">Toda Latinoamérica</label>' +
    opts + '</div>';
};

// Conecta, sobre chips YA en el DOM (después de insertar geoChipsHTML): el toggle
// visual (.geo-chip-on) y el sync del atajo "todas" (marca los 19 / se destilda
// sola si se destilda un país a mano). `onCambio(seleccionados)` es opcional -- se
// llama con la lista de valores marcados en cada cambio; si el caller ya relee
// `.geo-chk:checked` en otro momento (p.ej. al enviar el form), puede omitirse.
window.geoInitChips = function (idTodas, onCambio) {
  var todas = document.getElementById(idTodas);
  if (!todas) return;
  var chks = function () { return Array.prototype.slice.call(document.querySelectorAll('.geo-chk')); };
  var pintar = function (c) { c.parentElement.classList.toggle('geo-chip-on', c.checked); };
  var avisar = function () {
    if (onCambio) onCambio(chks().filter(function (c) { return c.checked; }).map(function (c) { return c.value; }));
  };
  todas.addEventListener('change', function () {
    chks().forEach(function (c) { c.checked = todas.checked; pintar(c); });
    pintar(todas);
    avisar();
  });
  chks().forEach(function (c) {
    c.addEventListener('change', function () {
      pintar(c);
      todas.checked = chks().every(function (x) { return x.checked; });
      pintar(todas);
      avisar();
    });
  });
};
