"""Génère l'icône SombaTeka 1024×1024 pour les stores."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icon" / "app_icon.png"
OUT.parent.mkdir(parents=True, exist_ok=True)

SIZE = 1024
BG = (13, 27, 75)  # #0D1B4B
BAG = (255, 255, 255)
STAR = (255, 215, 0)  # gold
ACCENT = (37, 99, 235)  # primary blue

img = Image.new("RGB", (SIZE, SIZE), BG)
draw = ImageDraw.Draw(img)

# Sac shopping (forme simplifiée)
cx, cy = SIZE // 2, SIZE // 2 + 40
bag_w, bag_h = 420, 480
left = cx - bag_w // 2
top = cy - bag_h // 2
draw.rounded_rectangle(
    [left, top + 80, left + bag_w, top + bag_h],
    radius=48,
    fill=BAG,
)
# Anses
draw.arc([left + 60, top - 20, left + bag_w - 60, top + 160], 200, 340, fill=BAG, width=36)

# Étoile
star_cx, star_cy = cx + 130, cy - 120
r_outer, r_inner = 72, 32
points = []
import math

for i in range(10):
    angle = math.pi / 2 + i * math.pi / 5
    r = r_outer if i % 2 == 0 else r_inner
    points.append((star_cx + r * math.cos(angle), star_cy - r * math.sin(angle)))
draw.polygon(points, fill=STAR)

# Bande accent en bas
draw.rectangle([0, SIZE - 120, SIZE, SIZE], fill=ACCENT)

img.save(OUT, "PNG", optimize=True)
print(f"Icon saved: {OUT}")
