"""Génère tous les assets store + site web (icône, feature graphic, favicons, OG)."""
from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WEBSITE = ROOT.parent / "website" / "assets"

BG = (13, 27, 75)
BAG = (255, 255, 255)
STAR = (255, 215, 0)
ACCENT = (37, 99, 235)


def _draw_brand_mark(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float = 1.0) -> None:
    bag_w, bag_h = int(420 * scale), int(480 * scale)
    left = cx - bag_w // 2
    top = cy - bag_h // 2
    r = max(8, int(48 * scale))
    draw.rounded_rectangle(
        [left, top + int(80 * scale), left + bag_w, top + bag_h],
        radius=r,
        fill=BAG,
    )
    draw.arc(
        [left + int(60 * scale), top - int(20 * scale), left + bag_w - int(60 * scale), top + int(160 * scale)],
        200,
        340,
        fill=BAG,
        width=max(4, int(36 * scale)),
    )
    star_cx, star_cy = cx + int(130 * scale), cy - int(120 * scale)
    r_outer, r_inner = int(72 * scale), int(32 * scale)
    points = []
    for i in range(10):
        angle = math.pi / 2 + i * math.pi / 5
        r = r_outer if i % 2 == 0 else r_inner
        points.append((star_cx + r * math.cos(angle), star_cy - r * math.sin(angle)))
    draw.polygon(points, fill=STAR)


def generate_app_icon() -> Path:
    out = ROOT / "assets" / "icon" / "app_icon.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    size = 1024
    img = Image.new("RGB", (size, size), BG)
    draw = ImageDraw.Draw(img)
    _draw_brand_mark(draw, size // 2, size // 2 + 40)
    draw.rectangle([0, size - 120, size, size], fill=ACCENT)
    img.save(out, "PNG", optimize=True)
    print(f"[OK] App icon: {out}")
    return out


def generate_feature_graphic() -> Path:
    out_dir = ROOT / "store" / "play" / "graphics"
    out = out_dir / "feature_graphic.png"
    out_dir.mkdir(parents=True, exist_ok=True)
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, h - 8, w, h], fill=STAR)
    draw.ellipse([-60, 300, 200, 560], fill=STAR)
    draw.ellipse([720, -80, 980, 180], fill=ACCENT)
    try:
        title_font = ImageFont.truetype("arialbd.ttf", 72)
        sub_font = ImageFont.truetype("arial.ttf", 28)
    except OSError:
        title_font = sub_font = ImageFont.load_default()
    draw.text((48, 160), "SombaTeka", fill=BAG, font=title_font)
    draw.text((52, 260), "La marketplace premium de la RDC", fill=STAR, font=sub_font)
    draw.text((52, 310), "Achetez · Vendez · Mobile Money", fill=(200, 210, 230), font=sub_font)
    _draw_brand_mark(draw, 820, 250, scale=0.35)
    img.save(out, "PNG", optimize=True)
    print(f"[OK] Feature graphic: {out}")
    return out


def _icon_from_master(master: Path, size: int, out: Path) -> None:
    img = Image.open(master).convert("RGB")
    img = img.resize((size, size), Image.Resampling.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, "PNG", optimize=True)
    print(f"[OK] Favicon {size}px: {out}")


def generate_web_assets(master: Path) -> None:
    WEBSITE.mkdir(parents=True, exist_ok=True)
    _icon_from_master(master, 32, WEBSITE / "favicon-32.png")
    _icon_from_master(master, 192, WEBSITE / "favicon-192.png")
    og = Image.open(master).convert("RGB")
    og = og.resize((1200, 630), Image.Resampling.LANCZOS)
    og.save(WEBSITE / "og-image.png", "PNG", optimize=True)
    print(f"[OK] OG image: {WEBSITE / 'og-image.png'}")


def main() -> int:
    icon = generate_app_icon()
    generate_feature_graphic()
    generate_web_assets(icon)
    print("\n[OK] Tous les assets store generes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
