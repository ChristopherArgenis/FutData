"""Genera el sitio estático para GitHub Pages en la carpeta site/.

Uso:  python3 tools/build_site.py

design/prototipo.html  -> site/index.html y site/prototipo.html  (página principal con las dos opciones)
design/futdata.html    -> site/futdata.html                        (app FutData)
design/familia.html    -> site/familia.html                        (app FutData Familia)

Los archivos de design/ no traen <!doctype>/<head>/<body>; aquí se agregan.
"""
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIGEN, DESTINO = RAIZ / "design", RAIZ / "site"
BASE = """<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>
:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}
html,body{height:100%}
body{margin:0;font:14px/1.4 system-ui,-apple-system,"Segoe UI",sans-serif}
img{max-width:100%}
[hidden]{display:none!important}
</style>
</head>
<body>
"""
PAGINAS = {"prototipo.html": ["index.html", "prototipo.html"], "futdata.html": ["futdata.html"], "familia.html": ["familia.html"]}


def main():
    DESTINO.mkdir(exist_ok=True)
    for origen, destinos in PAGINAS.items():
        contenido = (ORIGEN / origen).read_text(encoding="utf-8")
        pagina = BASE + contenido + "\n</body>\n</html>\n"
        for d in destinos:
            (DESTINO / d).write_text(pagina, encoding="utf-8")
            print(f"site/{d}  ({len(pagina)//1024} KB)")
    (DESTINO / ".nojekyll").write_text("", encoding="utf-8")


if __name__ == "__main__":
    main()
