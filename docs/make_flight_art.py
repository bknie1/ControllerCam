"""Draws the flight game's textures (FlightGame.lua): a treetop, zeppelins in three liveries, a drake and a cloud (32-bit TGA, power-of-two
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

# zeppelins: a cloth envelope with a band round it, tail fins, a wooden gondola on ropes and a propeller. Facing
# left: they drift towards you. 128 x 64. Three liveries: the goblins' (neutral: olive with brass), the Horde's
# (red with bone) and the Alliance's (blue with gold). The faction's own badge is the game's, put on in play.
OLIVE = dict(base=(118, 132, 70), dark=(78, 90, 44), light=(166, 180, 108), line=(32, 36, 16))
BRASS = dict(base=(196, 156, 74), dark=(142, 104, 42), light=(232, 204, 130), line=(52, 36, 14))
RED = CLOTH
BONE = dict(base=(226, 212, 180), dark=(170, 152, 120), light=(246, 238, 216), line=(52, 22, 18))
BLUE = dict(base=(62, 104, 186), dark=(38, 66, 132), light=(122, 162, 228), line=(16, 24, 52))
GOLD = dict(base=(232, 196, 92), dark=(176, 136, 48), light=(250, 228, 150), line=(16, 24, 52))


def zeppelin(cloth, band, shine):
    W, H = 128, 64
    envelope = blob(sheet(W, H), (6, 4, 110, 42))
    fins = poly(sheet(W, H), [(96, 12), (124, 2), (120, 22), (100, 20)])
    poly(fins, [(96, 34), (124, 46), (120, 28), (100, 28)])
    stripe = ImageChops.multiply(envelope, box(sheet(W, H), (54, 0, 66, 64)))
    ropes = sheet(W, H)
    d = ImageDraw.Draw(ropes)
    for a, b in (((46, 40), (52, 50)), ((74, 40), (68, 50))):
        d.line(pts([a, b]), fill=255, width=int(1.4 * S))
    gondola = box(sheet(W, H), (42, 48, 78, 58), 3)
    prop = blob(sheet(W, H), (82, 44, 88, 62))
    hub = blob(sheet(W, H), (78, 51, 84, 55))
    img = over(paint(fins, **cloth), paint(envelope, **cloth), paint(stripe, **band, edge=1.2, depth=2.0),
               paint(ropes, **WOOD, edge=0.8, depth=0.5, rim=0.3), paint(gondola, **WOOD),
               paint(prop, **STEEL, edge=1.2), paint(hub, **STEEL, edge=1.0))
    gleam = layer(W, H)
    ink(gleam, shine, blob(sheet(W, H), (22, 10, 46, 18)))                    # a shine on the cloth
    return over(img, gleam).resize((W, H), Image.LANCZOS)


save(zeppelin(OLIVE, BRASS, (220, 232, 180)), "zeppelin")
save(zeppelin(RED, BONE, (255, 220, 190)), "zeppelin_horde")
save(zeppelin(BLUE, GOLD, (200, 222, 255)), "zeppelin_alliance")

# dragon: a drake in flight, facing left (it comes the other way): wings raised, a long neck to a horned head
# with its jaw open (its fire is drawn in play), a curling tail. 128 x 64. Our own cartoon, not anyone's dragon.
SCALE = dict(base=(176, 62, 46), dark=(118, 36, 30), light=(222, 112, 78), line=(44, 14, 12))
WING = dict(base=(138, 48, 46), dark=(92, 28, 30), light=(186, 84, 70), line=(44, 14, 12))
BELLY = dict(base=(236, 196, 128), dark=(190, 146, 86), light=(250, 226, 170), line=(44, 14, 12))
HORN = dict(base=(232, 220, 190), dark=(176, 160, 126), light=(250, 246, 230), line=(44, 14, 12))
W, H = 128, 64
far = poly(sheet(W, H), [(62, 30), (78, 2), (88, 8), (96, 4), (100, 16), (108, 14), (84, 34)])   # the far wing
body = blob(sheet(W, H), (40, 24, 92, 48))
poly(body, [(46, 30), (30, 24), (20, 22), (24, 32), (40, 40)])                # the neck, up to the head
poly(body, [(86, 32), (106, 40), (118, 34), (124, 38), (112, 46), (90, 46)])  # the tail, curling up
poly(body, [(118, 34), (126, 28), (124, 40)])                                 # its spade
head = blob(sheet(W, H), (8, 16, 30, 30))
poly(head, [(10, 22), (2, 24), (4, 28), (12, 28)])                             # the snout
jaw = poly(sheet(W, H), [(12, 28), (2, 32), (6, 34), (20, 30)])                # the jaw, open
belly = ImageChops.multiply(body, blob(sheet(W, H), (36, 36, 90, 56)))
legs = poly(sheet(W, H), [(52, 44), (50, 54), (56, 54), (58, 44)])
poly(legs, [(74, 44), (76, 54), (82, 54), (80, 44)])
near = poly(sheet(W, H), [(52, 32), (60, 2), (70, 10), (78, 4), (82, 16), (92, 14), (70, 38)])   # the near wing
horns = poly(sheet(W, H), [(22, 18), (30, 6), (26, 20)])
poly(horns, [(18, 18), (22, 8), (21, 19)])
spines = sheet(W, H)
for x in (44, 52, 60, 68, 76):
    poly(spines, [(x, 27), (x + 3, 21), (x + 6, 27)])
dragon = over(paint(far, **WING), paint(spines, **HORN, edge=1.0, depth=1.0, rim=0.5), paint(body, **SCALE),
              paint(belly, **BELLY, edge=0.8, depth=1.5), paint(legs, **SCALE), paint(jaw, **SCALE),
              paint(head, **SCALE), paint(horns, **HORN, edge=1.0, depth=1.0, rim=0.5), paint(near, **WING))
eye = layer(W, H)
ink(eye, (255, 226, 96), blob(sheet(W, H), (14, 19, 19, 23)))
ink(eye, (30, 10, 8), blob(sheet(W, H), (15, 20, 17, 22)))
for a, b in (((62, 30), (64, 6)), ((66, 32), (76, 8)), ((70, 34), (86, 16))):   # the near wing's bones
    ImageDraw.Draw(eye).line(pts([a, b]), fill=WING["dark"] + (255,), width=int(1.2 * S))
dragon = over(dragon, eye)
save(dragon.resize((W, H), Image.LANCZOS), "dragon")

# cloud: soft and white (tinted in the game), only scenery behind the game. 128 x 64.
W, H = 128, 64
puff = sheet(W, H)
for b in ((8, 28, 52, 58), (30, 12, 76, 54), (60, 18, 102, 56), (86, 30, 122, 58), (20, 40, 110, 60)):
    blob(puff, b)
a = puff.filter(ImageFilter.GaussianBlur(2.5 * S)).resize((W, H), Image.LANCZOS)
white = Image.new("L", (W, H), 255)
save(Image.merge("RGBA", (white, white, white, a)), "cloud")
