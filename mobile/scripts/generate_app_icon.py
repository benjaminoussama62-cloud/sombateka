"""Génère l'icône SombaTeka (sac plein + étoile centrée) pour les stores et le web.

Rendu 4x puis downscale LANCZOS pour l'anti-aliasing.
La marque tient dans la zone sûre adaptive icon (~66% centrée).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon" / "app_icon.png"
WEB_ICONS = ROOT / "web" / "icons"
SITE_ASSETS = ROOT.parent / "website" / "assets"

SIZE = 1024
SS = 4  # supersampling
BG = (13, 27, 75)  # #0D1B4B
BAG = (255, 255, 255)
STAR = (251, 191, 36)  # #FBBF24 gold

img = Image.new("RGB", (SIZE * SS, SIZE * SS), BG)
mark = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(mark)


def pt(fx, fy):
    return fx * SIZE * SS, fy * SIZE * SS


def box(fx0, fy0, fx1, fy1):
    return [pt(fx0, fy0)[0], pt(fx0, fy0)[1], pt(fx1, fy1)[0], pt(fx1, fy1)[1]]


# Anse — demi-ellipse épaisse au-dessus du corps du sac
d.arc(box(0.32, 0.16, 0.68, 0.56), 180, 360, fill=BAG, width=int(0.058 * SIZE * SS))

# Corps du sac — rectangle arrondi plein, massif
d.rounded_rectangle(box(0.19, 0.35, 0.81, 0.83), radius=int(0.12 * SIZE * SS), fill=BAG)

# Étoile centrée dans le sac — grande (≈40% de la largeur du sac)
scx, scy = pt(0.5, 0.575)
r_out, r_in = 0.16 * SIZE * SS, 0.065 * SIZE * SS
points = []
for i in range(10):
    angle = -math.pi / 2 + i * math.pi / 5
    r = r_out if i % 2 == 0 else r_in
    points.append((scx + r * math.cos(angle), scy + r * math.sin(angle)))
d.polygon(points, fill=STAR)

# Légère rotation — dynamisme comme le visuel promo
mark = mark.rotate(6, resample=Image.BICUBIC, center=pt(0.5, 0.52))
img.paste(mark, (0, 0), mark)

img = img.resize((SIZE, SIZE), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, "PNG", optimize=True)
print(f"Icon saved: {OUT}")

# Icônes PWA / web
for name, size in {
    "Icon-192.png": 192,
    "Icon-512.png": 512,
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
}.items():
    p = WEB_ICONS / name
    img.resize((size, size), Image.LANCZOS).save(p, "PNG", optimize=True)
    print(f"Saved: {p}")

# Favicons du site marketing
SITE_ASSETS.mkdir(parents=True, exist_ok=True)
for name, size in {"favicon-192.png": 192, "favicon-32.png": 32}.items():
    p = SITE_ASSETS / name
    img.resize((size, size), Image.LANCZOS).save(p, "PNG", optimize=True)
    print(f"Saved: {p}")
