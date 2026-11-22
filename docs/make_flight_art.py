"""Draws the flight game's textures (FlightGame.lua): a treetop, a zeppelin and a cloud (32-bit TGA, power-of-two
sizes) with Pillow, in the flat three-tone look of the HUD's other drawings.

    python docs/make_flight_art.py ControllerCam_HUD/Media
"""
import os
import sys
from PIL import ImageChops, Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
S = 4  # supersampling


def save(img, name):
    img.save(os.path.join(OUT, name + ".tga"))
    print(name, img.size)


def sheet(w, h):
    return Image.new("L", (w * S, h * S), 0)


def layer(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def pts(points):
    return [(x * S, y * S) for x, y in points]


def poly(mask, points):
    ImageDraw.Draw(mask).polygon(pts(points), fill=255)
    return mask


def blob(mask, box):
    ImageDraw.Draw(mask).ellipse([v * S for v in box], fill=255)
    return mask


def box(mask, b, radius=0):
    ImageDraw.Draw(mask).rounded_rectangle([v * S for v in b], radius=radius * S, fill=255)
    return mask


def fatter(mask, r):
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


def paint(mask, base, dark, light, line, edge=2.2, depth=3.0, rim=1.4):
    """A shape in three flat tones inside a dark line; the light from the upper left."""
    img = layer(mask.width // S, mask.height // S)
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


WOOD = dict(base=(150, 98, 54), dark=(98, 60, 32), light=(200, 146, 88), line=(40, 24, 12))
LEAF = dict(base=(74, 150, 70), dark=(40, 98, 52), light=(132, 196, 96), line=(18, 44, 26))
CLOTH = dict(base=(204, 96, 62), dark=(146, 58, 42), light=(238, 150, 104), line=(52, 22, 18))
BAND = dict(base=(232, 196, 110), dark=(176, 136, 66), light=(250, 228, 160), line=(52, 22, 18))
STEEL = dict(base=(170, 184, 206), dark=(104, 118, 150), light=(238, 244, 252), line=(30, 34, 50))

# treetop: a round, leafy tree on its trunk, the trunk's foot at the bottom edge (it rises from below the lane).
# 64 x 128: drawn as tall as it is shown, so a taller tree is a larger one, not a stretched one.
W, H = 64, 128
trunk = box(sheet(W, H), (27, 66, 37, 128), 2)
poly(trunk, [(27, 120), (20, 128), (44, 128), (37, 120)])                   # roots spreading at the foot
crown = sheet(W, H)
for b in ((6, 44, 58, 92), (10, 22, 54, 66), (18, 4, 46, 40), (2, 58, 30, 88), (34, 58, 62, 88)):
    blob(crown, b)
tree = over(paint(trunk, **WOOD), paint(crown, **LEAF))
spots = layer(W, H)                                                          # a few rounder leaf clumps
for b in ((14, 50, 26, 60), (36, 34, 48, 44), (26, 14, 36, 22), (40, 66, 52, 76)):
    ink(spots, LEAF["light"], blob(sheet(W, H), b))
tree = over(tree, spots)
save(tree.resize((W, H), Image.LANCZOS), "treetop")

# zeppelin: a patched cloth envelope with a band round it, tail fins, a wooden gondola on ropes and a propeller.
# Facing left: it drifts towards you. 128 x 64.
W, H = 128, 64
envelope = blob(sheet(W, H), (6, 4, 110, 42))
fins = poly(sheet(W, H), [(96, 12), (124, 2), (120, 22), (100, 20)])
poly(fins, [(96, 34), (124, 46), (120, 28), (100, 28)])
band = ImageChops.multiply(envelope, box(sheet(W, H), (54, 0, 66, 64)))
ropes = sheet(W, H)
d = ImageDraw.Draw(ropes)
for a, b in (((46, 40), (52, 50)), ((74, 40), (68, 50))):
    d.line(pts([a, b]), fill=255, width=int(1.4 * S))
gondola = box(sheet(W, H), (42, 48, 78, 58), 3)
prop = blob(sheet(W, H), (82, 44, 88, 62))
hub = blob(sheet(W, H), (78, 51, 84, 55))
zep = over(paint(fins, **CLOTH), paint(envelope, **CLOTH), paint(band, **BAND, edge=1.2, depth=2.0),
           paint(ropes, **WOOD, edge=0.8, depth=0.5, rim=0.3), paint(gondola, **WOOD), paint(prop, **STEEL, edge=1.2),
           paint(hub, **STEEL, edge=1.0))
shine = layer(W, H)
ink(shine, (255, 220, 190), blob(sheet(W, H), (22, 10, 46, 18)))            # a shine on the cloth
zep = over(zep, shine)
save(zep.resize((W, H), Image.LANCZOS), "zeppelin")

# cloud: soft and white (tinted in the game), only scenery behind the game. 128 x 64.
W, H = 128, 64
puff = sheet(W, H)
for b in ((8, 28, 52, 58), (30, 12, 76, 54), (60, 18, 102, 56), (86, 30, 122, 58), (20, 40, 110, 60)):
    blob(puff, b)
a = puff.filter(ImageFilter.GaussianBlur(2.5 * S)).resize((W, H), Image.LANCZOS)
white = Image.new("L", (W, H), 255)
save(Image.merge("RGBA", (white, white, white, a)), "cloud")
