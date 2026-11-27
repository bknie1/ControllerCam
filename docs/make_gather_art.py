"""Draws map pins for herbs, ore, fish, treasure and other finds (32-bit TGA, 32x32) with Pillow, in the look of the HUD's small art:
a dark line around every shape, a few flat tones (a lit side, a body, a shaded side). They are shown a dozen
to two dozen pixels wide, so every feature is chunky. Drawn in colour and not tinted in the game.

    python docs/make_gather_art.py docs/art/gather

Kept from the Gather addon that was dropped; nothing ships them at the moment.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
S = 8           # supersampling
Q = 64          # the side of a piece, in the units the shapes below are given in
SIDE = 32       # the side of the finished texture


def save(img, name):
    img.resize((SIDE, SIDE), Image.LANCZOS).save(os.path.join(OUT, name + ".tga"))
    print(name, (SIDE, SIDE))


def sheet():
    return Image.new("L", (Q * S, Q * S), 0)


def layer():
    return Image.new("RGBA", (Q * S, Q * S), (0, 0, 0, 0))


def pts(points):
    return [(x * S, y * S) for x, y in points]


def poly(mask, points, fill=255):
    ImageDraw.Draw(mask).polygon(pts(points), fill=fill)
    return mask


def blob(mask, box, fill=255):
    ImageDraw.Draw(mask).ellipse([v * S for v in box], fill=fill)
    return mask


def rope(mask, points, w0, w1=None, fill=255):
    """A line through these points, w0 wide at its start and w1 at its end, with round ends and joints."""
    w1 = w0 if w1 is None else w1
    d = ImageDraw.Draw(mask)
    n = max(1, len(points) - 1)
    for i, (x, y) in enumerate(points):
        r = (w0 + (w1 - w0) * i / n) * S / 2
        d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=fill)
        if i < len(points) - 1:
            x2, y2 = points[i + 1]
            d.line([(x * S, y * S), (x2 * S, y2 * S)], fill=fill, width=max(1, int(r * 2)))
    return mask


def fatter(mask, r):
    """The shape grown by r on every side, with round corners."""
    return mask.filter(ImageFilter.GaussianBlur(r * S / 1.2)).point(lambda v: 255 if v >= 29 else 0)


def thinner(mask, r):
    return ImageChops.invert(fatter(ImageChops.invert(mask), r))


def moved(mask, dx, dy):
    out = Image.new("L", mask.size, 0)
    out.paste(mask, (int(dx * S), int(dy * S)))
    return out


def ink(img, color, mask):
    img.paste(tuple(color) + (255,), mask=mask)
    return img


def paint(mask, base, dark, light, line, edge=3.4, depth=3.6, rim=1.6):
    """A shape in three flat tones with a dark line around it. The light comes from the upper left."""
    img = layer()
    ink(img, line, fatter(mask, edge))
    ink(img, base, mask)
    ink(img, dark, ImageChops.subtract(mask, moved(mask, -depth, -depth)))
    inner = thinner(mask, rim)
    ink(img, light, ImageChops.subtract(inner, moved(inner, depth, depth)))
    return img


def over(*layers):
    out = layers[0]
    for top in layers[1:]:
        out = Image.alpha_composite(out, top)
    return out


def leaf(cx, cy, angle, long, wide):
    """A pointed leaf: its foot at (cx, cy), growing along angle."""
    out = []
    for i in range(40):
        t = i / 39
        along = t * long
        half = math.sin(t * math.pi) ** 0.8 * wide
        out.append((along, half))
    edge = out + [(a, -h) for a, h in reversed(out)]
    return [(cx + a * math.cos(angle) - h * math.sin(angle), cy + a * math.sin(angle) + h * math.cos(angle))
            for a, h in edge]


GREEN = dict(base=(104, 190, 96), dark=(48, 126, 70), light=(190, 238, 150), line=(18, 52, 30))
LINE = (26, 24, 34)

# herb: three leaves fanning up from one foot, and a pale bloom at their heart
img = layer()
for angle, long, wide in ((-math.pi / 2 - 0.9, 36, 11.5), (-math.pi / 2 + 0.9, 36, 11.5), (-math.pi / 2, 46, 12.5)):
    img = over(img, paint(poly(sheet(), leaf(32, 59, angle, long, wide)), **GREEN))
bloom = paint(blob(sheet(), [23, 31, 41, 49]), base=(255, 224, 120), dark=(232, 150, 60), light=(255, 248, 200),
              line=(96, 52, 16), edge=2.8, depth=2.6, rim=1.2)
save(over(img, bloom), "herb")

# ore: a lump of rock with two bright nuggets in it
ROCK = [(10, 44), (15, 24), (30, 11), (47, 15), (56, 34), (50, 52), (22, 55)]
rock = paint(poly(sheet(), ROCK), base=(140, 132, 148), dark=(88, 80, 104), light=(206, 200, 214), line=LINE)
GOLD = dict(base=(255, 196, 70), dark=(214, 126, 34), light=(255, 240, 170), line=(92, 50, 14), edge=2.4, depth=2.2,
            rim=1.0)
nugget1 = paint(poly(sheet(), [(21, 34), (28, 25), (36, 30), (33, 41), (24, 42)]), **GOLD)
nugget2 = paint(poly(sheet(), [(38, 42), (44, 35), (50, 40), (46, 48), (40, 48)]), **GOLD)
save(over(rock, nugget1, nugget2), "ore")

# fish: a plump fish swimming left
body = blob(sheet(), [8, 20, 46, 46])
tail = poly(sheet(), [(40, 33), (57, 19), (54, 33), (57, 47)])
fin = poly(sheet(), [(24, 22), (32, 11), (36, 22)])
shape = ImageChops.lighter(ImageChops.lighter(body, tail), fin)
fish = paint(shape, base=(96, 170, 232), dark=(44, 104, 178), light=(196, 232, 255), line=(14, 34, 70))
eye = ink(layer(), (16, 26, 50), blob(sheet(), [15, 27, 22, 34]))
save(over(fish, eye), "fish")

# treasure: a chest with a rounded lid, a gold band and a lock
WOOD = dict(base=(166, 104, 54), dark=(110, 62, 30), light=(220, 160, 96), line=(44, 24, 12))
lid = ImageChops.lighter(blob(sheet(), [9, 12, 55, 46]), poly(sheet(), [(9, 29), (55, 29), (55, 34), (9, 34)]))
lid = ImageChops.subtract(lid, poly(sheet(), [(0, 34), (64, 34), (64, 64), (0, 64)]))
box = poly(sheet(), [(9, 32), (55, 32), (55, 54), (9, 54)])
chest = paint(ImageChops.lighter(lid, box), **WOOD)
band = ink(layer(), (255, 204, 84), poly(sheet(), [(9, 31), (55, 31), (55, 36), (9, 36)]))
band = ink(band, (92, 50, 14), poly(sheet(), [(9, 36), (55, 36), (55, 37.6), (9, 37.6)]))
lock = paint(poly(sheet(), [(27, 29), (37, 29), (37, 42), (27, 42)]), base=(255, 212, 96), dark=(214, 136, 40),
             light=(255, 244, 180), line=(92, 50, 14), edge=2.2, depth=2.0, rim=1.0)
save(over(chest, band, lock), "treasure")

# other: a cut gem, point down
gem = paint(poly(sheet(), [(20, 14), (44, 14), (56, 28), (32, 54), (8, 28)]), base=(176, 132, 240),
            dark=(104, 68, 184), light=(232, 212, 255), line=(40, 22, 78))
facet = ink(layer(), (232, 212, 255), rope(sheet(), [(14, 28), (50, 28)], 2.2))
save(over(gem, facet), "other")
