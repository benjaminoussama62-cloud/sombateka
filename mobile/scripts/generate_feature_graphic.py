"""Génère la bannière Play Store 1024×500 (feature graphic)."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "store" / "play" / "graphics"
OUT = OUT_DIR / "feature_graphic.png"
OUT_DIR.mkdir(parents=True, exist_ok=True)

W, H = 1024, 500
BG = (13, 27, 75)
GOLD = (255, 215, 0)
WHITE = (255, 255, 255)
BLUE = (37, 99, 235)

img = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# Bande accent
draw.rectangle([0, H - 8, W, H], fill=GOLD)

# Orbes décoratifs
draw.ellipse([720, -80, 980, 180], fill=(37, 99, 235, 80) if hasattr(Image, "RGBA") else BLUE)
draw.ellipse([-60, 300, 200, 560], fill=(255, 215, 0))

try:
    title_font = ImageFont.truetype("arialbd.ttf", 72)
    sub_font = ImageFont.truetype("arial.ttf", 28)
except OSError:
    title_font = ImageFont.load_default()
    sub_font = ImageFont.load_default()

draw.text((48, 160), "SombaTeka", fill=WHITE, font=title_font)
draw.text((52, 260), "La marketplace premium de la RDC", fill=GOLD, font=sub_font)
draw.text((52, 310), "Achetez · Vendez · Mobile Money", fill=(200, 210, 230), font=sub_font)

# Sac simplifié à droite
cx, cy = 820, 250
draw.rounded_rectangle([cx - 70, cy - 20, cx + 70, cy + 100], radius=16, fill=WHITE)
draw.arc([cx - 45, cy - 70, cx + 45, cy + 30], 200, 340, fill=WHITE, width=10)

img.save(OUT, "PNG", optimize=True)
print(f"Feature graphic saved: {OUT}")
