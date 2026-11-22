"""Genera los íconos de las apps (Android, iPhone y navegador) en design/iconos/.

Uso:  python3 tools/make_icons.py   (requiere Pillow; los PNG generados se guardan en el repositorio)
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "design" / "iconos"
FUENTES = ["/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf", "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf",
           "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
APPS = {"futdata": ("FD", (19, 146, 77)), "familia": ("FF", (224, 138, 46))}


def fuente(tam):
    for f in FUENTES:
        if pathlib.Path(f).exists():
            return ImageFont.truetype(f, tam)
    return ImageFont.load_default()


def icono(texto, color, tam, *, redondo, zona=1.0):
    """zona < 1 deja margen seguro para íconos 'maskable' (Android recorta en círculo o gota)."""
    im = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if redondo:
        d.rounded_rectangle([0, 0, tam - 1, tam - 1], radius=int(tam * .22), fill=color)
    else:
        d.rectangle([0, 0, tam, tam], fill=color)
    # balón estilizado detrás de las letras
    r = tam * .30 * zona
    cx, cy = tam * .5, tam * .5
    d.ellipse([cx - r * 1.45, cy - r * 1.45, cx + r * 1.45, cy + r * 1.45], outline=(255, 255, 255, 46), width=max(2, int(tam * .018)))
    f = fuente(int(tam * .36 * zona))
    caja = d.textbbox((0, 0), texto, font=f)
    w, h = caja[2] - caja[0], caja[3] - caja[1]
    d.text((cx - w / 2 - caja[0], cy - h / 2 - caja[1]), texto, font=f, fill=(255, 255, 255))
    return im


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    for app, (texto, color) in APPS.items():
        icono(texto, color, 192, redondo=True).save(SALIDA / f"{app}-192.png")
        icono(texto, color, 512, redondo=True).save(SALIDA / f"{app}-512.png")
        icono(texto, color, 512, redondo=False, zona=.8).save(SALIDA / f"{app}-maskable-512.png")
        icono(texto, color, 180, redondo=False).convert("RGB").save(SALIDA / f"{app}-apple-180.png")   # iOS redondea solo
        icono(texto, color, 64, redondo=True).save(SALIDA / f"{app}-favicon-64.png")
    icono("F", (19, 146, 77), 64, redondo=True).save(SALIDA / "portada-favicon-64.png")
    print("\n".join(sorted(p.name for p in SALIDA.iterdir())))


if __name__ == "__main__":
    main()
