#!/usr/bin/env python3
"""Renders Porter's app icon.

    python3 scripts/make-icon.py        # needs Pillow (pip install pillow)

Writes Resources/AppIcon.png (1024 px preview) and Resources/AppIcon.icns, which
scripts/build-app.sh copies into the app bundle.

The motif: a globe (the web) inside two arrows chasing each other (switching between
browsers), on the macOS icon grid (an 824 px rounded square on a 1024 px canvas).
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
SS = 4  # supersampling factor for smooth edges
S = SIZE * SS

TOP = (76, 110, 245)  # indigo-blue
BOTTOM = (21, 170, 191)  # teal
WHITE = (255, 255, 255, 255)


def px(v):
    return int(round(v * SS))


def rounded_square_mask():
    """macOS icon body: 824x824, ~185 px corner radius, centred."""
    mask = Image.new("L", (S, S), 0)
    inset = px(100)
    ImageDraw.Draw(mask).rounded_rectangle((inset, inset, S - inset, S - inset), radius=px(185), fill=255)
    return mask


def gradient():
    column = Image.new("RGBA", (1, S))
    for y in range(S):
        t = y / (S - 1)
        column.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,))
    return column.resize((S, S))


def arrow_arc(draw, cx, cy, r, start, end, width):
    """Clockwise arc from `start` to `end` degrees (0 = 3 o'clock) with an arrowhead at `end`.

    `r` is the stroke's centre line. Pillow strokes arcs inward from the box edge, so the box
    is widened by half the stroke.
    """
    outer = r + width / 2
    draw.arc((cx - outer, cy - outer, cx + outer, cy + outer), start, end, fill=WHITE, width=int(width))

    def point(angle, radius=r):
        a = math.radians(angle)
        return cx + radius * math.cos(a), cy + radius * math.sin(a)

    # Round cap at the tail.
    tx, ty = point(start)
    draw.ellipse((tx - width / 2, ty - width / 2, tx + width / 2, ty + width / 2), fill=WHITE)
    # Arrowhead: base across the stroke where the arc stops, tip further along the circle.
    half = width * 1.15
    draw.polygon([point(end + 17), point(end, r + half), point(end, r - half)], fill=WHITE)


def globe(r, stroke):
    """Globe on its own layer, clipped to its outline so no grid line pokes out."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    c = S / 2
    draw.ellipse((c - r * 0.45, c - r, c + r * 0.45, c + r), outline=WHITE, width=stroke)
    draw.line((c - r, c, c + r, c), fill=WHITE, width=stroke)
    for k in (-0.5, 0.5):
        draw.line((c - r, c + r * k, c + r, c + r * k), fill=WHITE, width=stroke)
    clip = Image.new("L", (S, S), 0)
    ImageDraw.Draw(clip).ellipse((c - r, c - r, c + r, c + r), fill=255)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    ImageDraw.Draw(layer).ellipse((c - r, c - r, c + r, c + r), outline=WHITE, width=stroke)
    return layer


def render():
    mask = rounded_square_mask()

    # Soft shadow under the body, as on other macOS icons.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow_alpha = mask.point(lambda v: v * 0.35)
    shadow.putalpha(ImageChops.offset(shadow_alpha, 0, px(12)).filter(ImageFilter.GaussianBlur(px(18))))

    body = gradient()
    # Subtle top highlight.
    highlight = Image.new("L", (S, S), 0)
    ImageDraw.Draw(highlight).ellipse((px(-200), px(-620), px(1224), px(420)), fill=40)
    body = Image.composite(Image.new("RGBA", (S, S), WHITE), body, highlight.filter(ImageFilter.GaussianBlur(px(60))))

    motif = globe(px(150), px(22))
    draw = ImageDraw.Draw(motif)
    c = S / 2
    arrow_arc(draw, c, c, px(262), 205, 325, px(50))
    arrow_arc(draw, c, c, px(262), 25, 145, px(50))

    # Slight depth on the white motif.
    motif_shadow = Image.new("RGBA", (S, S), (10, 30, 90, 0))
    motif_shadow.putalpha(motif.getchannel("A").point(lambda v: v * 0.25).filter(ImageFilter.GaussianBlur(px(10))))
    motif_shadow = ImageChops.offset(motif_shadow, 0, px(8))

    body = Image.alpha_composite(body, motif_shadow)
    body = Image.alpha_composite(body, motif)
    body.putalpha(mask)

    icon = Image.alpha_composite(shadow, body)
    return icon.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    icon = render()
    out = ROOT / "Resources"
    icon.save(out / "AppIcon.png")
    sizes = [16, 32, 64, 128, 256, 512]
    icon.save(out / "AppIcon.icns", append_images=[icon.resize((s, s), Image.LANCZOS) for s in sizes])
    print(f"Wrote {out / 'AppIcon.png'} and {out / 'AppIcon.icns'}")


if __name__ == "__main__":
    main()
