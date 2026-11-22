"""Genera el sitio estático para GitHub Pages en site/, con cada app como app web instalable (PWA).

Uso:  python3 tools/build_site.py

site/index.html, site/prototipo.html   página principal con las dos opciones
site/futdata/                           app FutData      (index.html, manifest, service worker, íconos)
site/familia/                           app FutData Familia
site/_plano/                            las tres páginas sin instalación, para abrirlas como archivos sueltos

Cada app vive en su carpeta con su propio manifest y service worker: se instalan por separado
y ninguna comparte código, caché ni datos con la otra.
"""
import hashlib
import json
import pathlib
import shutil

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DISENO, SITIO = RAIZ / "design", RAIZ / "site"
FONDO = "#f3f6f1"

APPS = {
    "futdata": {"fuente": "futdata.html", "nombre": "FutData", "corto": "FutData", "color": "#13924d",
                "desc": "Partidos, convocatorias, alineaciones, competiciones y análisis para entrenadores y su equipo."},
    "familia": {"fuente": "familia.html", "nombre": "FutData Familia", "corto": "Familia", "color": "#e08a2e",
                "desc": "Minutos de juego, captura en vivo y progreso de tus hijos, capturado por mamá y papá."},
}

BASE_CSS = """:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
html,body{height:100%}
body{margin:0;font:14px/1.4 system-ui,-apple-system,"Segoe UI",sans-serif}
img{max-width:100%}
[hidden]{display:none!important}"""

# En el celular (o instalada) la app ocupa toda la pantalla, sin el marco de teléfono ni el panel lateral.
APP_CSS = """
html{-webkit-text-size-adjust:100%}
button,a,[role=button],label{touch-action:manipulation;-webkit-tap-highlight-color:transparent}
@media (display-mode: standalone), (max-width: 900px) and (pointer: coarse), (max-width: 560px){
  html,body{overscroll-behavior:none}
  .info{display:none!important}
  .stage{padding:0!important;min-height:0}
  .device{position:fixed!important;inset:0!important;width:auto!important;height:auto!important;min-height:0!important;border:0!important;border-radius:0!important;box-shadow:none!important}
  .top{padding-top:calc(14px + env(safe-area-inset-top,0px));padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
  main{padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
  nav.tabs{padding-bottom:calc(8px + env(safe-area-inset-bottom,0px))}
  .fab{bottom:calc(84px + env(safe-area-inset-bottom,0px))}
  .toast{bottom:calc(92px + env(safe-area-inset-bottom,0px))}
  .sheet{padding-bottom:calc(22px + env(safe-area-inset-bottom,0px))}
  .fm-livetop{margin-top:calc(-14px - env(safe-area-inset-top,0px));padding-top:calc(14px + env(safe-area-inset-top,0px))}
  .main-noselect nav.tabs,.main-noselect .fm-pad{-webkit-user-select:none;user-select:none}
}
.pwa-banner{position:fixed;left:max(12px,env(safe-area-inset-left,0px));right:max(12px,env(safe-area-inset-right,0px));bottom:calc(84px + env(safe-area-inset-bottom,0px));z-index:60;
  display:grid;grid-template-columns:auto 1fr auto;gap:10px;align-items:center;background:#13251a;color:#fff;border-radius:16px;padding:10px 12px;box-shadow:0 14px 30px -12px rgba(0,0,0,.5);font:600 13px/1.35 system-ui,-apple-system,sans-serif}
.pwa-banner img{width:38px;height:38px;border-radius:10px}
.pwa-banner b{display:block;font-size:13.5px}
.pwa-banner .acc{display:flex;gap:6px;align-items:center}
.pwa-banner button{font:800 12.5px system-ui,sans-serif;border:0;border-radius:10px;padding:8px 11px;cursor:pointer}
.pwa-banner .ok{background:#fff;color:#13251a}
.pwa-banner .x{background:transparent;color:#cfd9cf;font-size:16px;padding:6px}"""

# Registro del service worker y aviso para instalar (Android: botón; iPhone: instrucciones).
APP_JS = r"""(function(){
  if ('serviceWorker' in navigator && (location.protocol === 'https:' || /^(localhost|127\.0\.0\.1)$/.test(location.hostname))) navigator.serviceWorker.register('sw.js').catch(function(){});
  var instalada = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  if (instalada) { document.documentElement.classList.add('main-noselect'); return; }
  var CLAVE = 'pwa-aviso-cerrado-' + __APP__, cerrado = false;
  try { cerrado = localStorage.getItem(CLAVE) === '1'; } catch (e) {}
  var movil = matchMedia('(max-width: 900px) and (pointer: coarse)').matches;
  if (cerrado || !movil) return;
  var ios = /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var pendiente = null;
  function mostrar(texto, conBoton){
    if (document.querySelector('.pwa-banner')) return;
    var b = document.createElement('div'); b.className = 'pwa-banner'; b.setAttribute('role', 'region'); b.setAttribute('aria-label', 'Instalar app');
    b.innerHTML = '<img alt="" src="icons/icon-192.png"><div><b>Instala ' + __NOMBRE__ + '</b>' + texto + '</div><div class="acc">' + (conBoton ? '<button type="button" class="ok">Instalar</button>' : '') + '<button type="button" class="x" aria-label="Cerrar">✕</button></div>';
    b.querySelector('.x').onclick = function(){ b.remove(); try { localStorage.setItem(CLAVE, '1'); } catch (e) {} };
    var ok = b.querySelector('.ok');
    if (ok) ok.onclick = function(){ if (!pendiente) return; pendiente.prompt(); pendiente.userChoice.then(function(){ b.remove(); }); pendiente = null; };
    document.body.appendChild(b);
  }
  window.addEventListener('beforeinstallprompt', function(e){ e.preventDefault(); pendiente = e; mostrar('Ábrela como app, a pantalla completa y sin internet.', true); });
  window.addEventListener('appinstalled', function(){ var b = document.querySelector('.pwa-banner'); if (b) b.remove(); });
  setTimeout(function(){
    if (pendiente) return;
    if (ios) mostrar('Toca <b style="display:inline">Compartir</b> y luego <b style="display:inline">“Agregar a inicio”</b>.', false);
    else mostrar('Abre el menú ⋮ del navegador y elige <b style="display:inline">“Instalar app”</b>.', false);
  }, 2500);
})();"""

SW_JS = """// Service worker de __NOMBRE__: guarda la app para abrirla sin internet.
const CACHE = '__APP__-__VERSION__';
const BASICOS = ['./', './index.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png', './icons/maskable-512.png', './icons/apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(BASICOS)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('__APP__-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (req.mode === 'navigate') {   // la página: primero red (para recibir actualizaciones), si no hay, la guardada
    e.respondWith(fetch(req).then(r => { const copia = r.clone(); caches.open(CACHE).then(c => c.put('./index.html', copia)); return r; }).catch(() => caches.match('./index.html')));
    return;
  }
  const externo = /fonts\\.(googleapis|gstatic)\\.com$|cdnjs\\.cloudflare\\.com$/.test(url.hostname);
  if (url.origin === location.origin || externo) {   // íconos, fuentes y librerías: lo guardado primero
    e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => { if (r.ok || r.type === 'opaque') { const copia = r.clone(); caches.open(CACHE).then(c => c.put(req, copia)); } return r; })));
  }
});
"""


def cabeza(extra=""):
    return f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>
{BASE_CSS}
</style>
{extra}</head>
<body>
"""


def construir_app(clave, cfg):
    destino = SITIO / clave
    (destino / "icons").mkdir(parents=True, exist_ok=True)
    iconos = DISENO / "iconos"
    for origen, nombre in [("192", "icon-192"), ("512", "icon-512"), ("maskable-512", "maskable-512"), ("apple-180", "apple-touch-icon"), ("favicon-64", "favicon-64")]:
        shutil.copy(iconos / f"{clave}-{origen}.png", destino / "icons" / f"{nombre}.png")
    contenido = (DISENO / cfg["fuente"]).read_text(encoding="utf-8")
    version = hashlib.sha256(contenido.encode()).hexdigest()[:10]
    manifest = {
        "name": cfg["nombre"], "short_name": cfg["corto"], "description": cfg["desc"], "lang": "es-MX",
        "id": "./", "start_url": "./", "scope": "./", "display": "standalone", "orientation": "portrait",
        "background_color": FONDO, "theme_color": FONDO, "categories": ["sports"],
        "icons": [{"src": "icons/icon-192.png", "sizes": "192x192", "type": "image/png"},
                  {"src": "icons/icon-512.png", "sizes": "512x512", "type": "image/png"},
                  {"src": "icons/maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"}],
    }
    (destino / "manifest.webmanifest").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (destino / "sw.js").write_text(SW_JS.replace("__APP__", clave).replace("__VERSION__", version).replace("__NOMBRE__", cfg["nombre"]), encoding="utf-8")
    extra = f"""<meta name="theme-color" content="{FONDO}">
<meta name="description" content="{cfg['desc']}">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/png" href="icons/favicon-64.png">
<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="{cfg['corto']}">
<meta name="format-detection" content="telephone=no">
<style>{APP_CSS}</style>
"""
    js = APP_JS.replace("__APP__", json.dumps(clave)).replace("__NOMBRE__", json.dumps(cfg["nombre"]))
    pagina = cabeza(extra) + contenido + f"\n<script>\n{js}\n</script>\n</body>\n</html>\n"
    (destino / "index.html").write_text(pagina, encoding="utf-8")
    print(f"site/{clave}/  ({len(pagina)//1024} KB, versión {version})")


def construir_portada():
    contenido = (DISENO / "prototipo.html").read_text(encoding="utf-8")
    contenido = contenido.replace('href="futdata.html"', 'href="futdata/"').replace('href="familia.html"', 'href="familia/"')
    (SITIO / "icons").mkdir(parents=True, exist_ok=True)
    shutil.copy(DISENO / "iconos" / "portada-favicon-64.png", SITIO / "icons" / "favicon-64.png")
    extra = f'<meta name="theme-color" content="{FONDO}">\n<link rel="icon" type="image/png" href="icons/favicon-64.png">\n'
    pagina = cabeza(extra) + contenido + "\n</body>\n</html>\n"
    for nombre in ("index.html", "prototipo.html"):
        (SITIO / nombre).write_text(pagina, encoding="utf-8")
    print("site/index.html y site/prototipo.html")


def main():
    if SITIO.exists():
        shutil.rmtree(SITIO)
    SITIO.mkdir()
    construir_portada()
    for clave, cfg in APPS.items():
        construir_app(clave, cfg)
    # Versión plana (sin instalación) para abrir los archivos sueltos o en la vista previa:
    # site/_plano/prototipo.html enlaza a futdata.html y familia.html en la misma carpeta.
    plano = SITIO / "_plano"; plano.mkdir()
    (plano / "prototipo.html").write_text(cabeza() + (DISENO / "prototipo.html").read_text(encoding="utf-8") + "\n</body>\n</html>\n", encoding="utf-8")
    for clave, cfg in APPS.items():
        (plano / f"{clave}.html").write_text(cabeza(f"<style>{APP_CSS}</style>\n") + (DISENO / cfg["fuente"]).read_text(encoding="utf-8") + "\n</body>\n</html>\n", encoding="utf-8")
    (SITIO / ".nojekyll").write_text("", encoding="utf-8")


if __name__ == "__main__":
    main()
