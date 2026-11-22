"""Draws the ControllerCam HUD textures (32-bit TGA, power-of-two sizes) with Pillow.

    python docs/make_hud_art.py ControllerCam_HUD/Media
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


# bar: the fill of every bar. White, tinted in the game: bright top edge, soft falloff to the bottom.
w, h = 256, 32
bar = Image.new("RGBA", (w, h))
px = bar.load()
for y in range(h):
    t = y / (h - 1)
    v = 255 - int(70 * t ** 1.4)           # 255 at the top, 185 at the bottom
    if y < 5:
        v = 255
    for x in range(w):
        px[x, y] = (v, v, v, 255)
save(bar, "bar")

# mask: a parallelogram, so bars get slanted ends ( /====/ ). The alpha channel is what masks.
w, h, run = 512, 32, 14
big = Image.new("L", (w * S, h * S), 0)
ImageDraw.Draw(big).polygon([(run * S, 0), (w * S, 0), ((w - run) * S, h * S), (0, h * S)], fill=255)
a = big.resize((w, h), Image.LANCZOS)
mask = Image.merge("RGBA", (a, a, a, a))
save(mask, "mask")

# soft: a blurred slab, white. Tinted black it is the drop shadow, tinted red the low-health glow.
w, h = 256, 64
big = Image.new("L", (w * S, h * S), 0)
ImageDraw.Draw(big).rounded_rectangle([26 * S, 22 * S, (w - 26) * S, (h - 22) * S], radius=8 * S, fill=255)
a = big.filter(ImageFilter.GaussianBlur(9 * S)).resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "soft")

# spark: the bright edge that rides the front of a cast bar.
w, h = 32, 32
big = Image.new("L", (w * S, h * S), 0)
ImageDraw.Draw(big).rounded_rectangle([14 * S, 2 * S, 18 * S, 30 * S], radius=2 * S, fill=255)
a = big.filter(ImageFilter.GaussianBlur(2.2 * S)).resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "spark")

# bobber: a classic red-and-white fishing float, drawn in colour (not tinted in the game).
w = h = 32
big = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.line([(16 * S, 2 * S), (16 * S, 9 * S)], fill=(60, 45, 30, 255), width=2 * S)            # the quill
d.ellipse([7 * S, 8 * S, 25 * S, 26 * S], fill=(250, 250, 245, 255), outline=(30, 30, 40, 255), width=2 * S)
d.pieslice([7 * S, 8 * S, 25 * S, 26 * S], 180, 360, fill=(220, 40, 45, 255), outline=(30, 30, 40, 255), width=2 * S)
d.line([(8 * S, 17 * S), (24 * S, 17 * S)], fill=(30, 30, 40, 255), width=2 * S)
d.ellipse([11 * S, 11 * S, 15 * S, 14 * S], fill=(255, 255, 255, 170))                       # a shine
save(big.resize((w, h), Image.LANCZOS), "bobber")

# skull: white (tinted red in the game), for bosses and units far above your level.
w = h = 32
big = Image.new("L", (w * S, h * S), 0)
d = ImageDraw.Draw(big)
d.ellipse([5 * S, 3 * S, 27 * S, 23 * S], fill=255)                     # the cranium
d.rounded_rectangle([10 * S, 18 * S, 22 * S, 28 * S], radius=2 * S, fill=255)   # the jaw
d.ellipse([9 * S, 10 * S, 15 * S, 17 * S], fill=0)                       # eyes
d.ellipse([17 * S, 10 * S, 23 * S, 17 * S], fill=0)
d.polygon([(16 * S, 17 * S), (14 * S, 21 * S), (18 * S, 21 * S)], fill=0)       # nose
for x in (13, 16, 19):                                                   # teeth
    d.line([(x * S, 23 * S), (x * S, 28 * S)], fill=0, width=1 * S)
a = big.resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "skull")

# wing: a swept, feathered flourish for the left of a name (mirrored on the right), tinted gold or silver in
# the game, after the classic dragon frames of elite and rare units.
w, h = 64, 32
big = Image.new("L", (w * S, h * S), 0)
d = ImageDraw.Draw(big)
# four tapered feathers fanning back and up from the name (right edge), with gaps between them
for i in range(4):
    base = 9 + i * 5.5                   # where the feather leaves the spine
    tipx = 4 + i * 9                     # how far back it reaches
    tipy = 2 + i * 6.5                   # and how high its tip curls
    thick = 2.6 - i * 0.35
    pts = [(60, base - thick), (40, base - thick - 3 - i), (24 + i * 4, tipy + 3), (tipx, tipy),
           (26 + i * 4, tipy + 5.5), (42, base + thick - 2 - i), (60, base + thick)]
    d.polygon([(x * S, y * S) for x, y in pts], fill=255)
d.rounded_rectangle([58 * S, 5 * S, 62 * S, 29 * S], radius=2 * S, fill=255)    # the spine against the name
a = big.filter(ImageFilter.GaussianBlur(0.6 * S)).resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "wing")

# quest: a gold disc with a dark exclamation mark, for units your quests need.
w = h = 32
big = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.ellipse([3 * S, 3 * S, 29 * S, 29 * S], fill=(250, 196, 70, 255), outline=(60, 40, 10, 255), width=2 * S)
d.rounded_rectangle([14 * S, 8 * S, 18 * S, 19 * S], radius=2 * S, fill=(50, 32, 8, 255))
d.ellipse([14 * S, 21 * S, 18 * S, 25 * S], fill=(50, 32, 8, 255))
save(big.resize((w, h), Image.LANCZOS), "quest")

# mark: a diamond with a hollow centre, for elite / rare / boss targets.
w = h = 32
big = Image.new("L", (w * S, h * S), 0)
d = ImageDraw.Draw(big)
c = w * S / 2
d.polygon([(c, 2 * S), (30 * S, c), (c, 30 * S), (2 * S, c)], fill=255)
d.polygon([(c, 10 * S), (22 * S, c), (c, 22 * S), (10 * S, c)], fill=0)
d.polygon([(c, 13 * S), (19 * S, c), (c, 19 * S), (13 * S, c)], fill=255)
a = big.resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "mark")

# threat: four shields side by side (128x32), white (tinted in the game), picked by texture coordinates:
#   max      a solid shield with an exclamation mark: it is on you
#   gaining  an outlined shield with an arrow up: you are about to pull it
#   losing   an outlined shield with an arrow down: someone is about to take it from you
#   calm     an outlined shield, empty: it is not on you
w, h = 128, 32
big = Image.new("L", (w * S, h * S), 0)
d = ImageDraw.Draw(big)
SHIELD = [(5, 3), (27, 3), (27, 15), (24, 22), (16, 30), (8, 22), (5, 15)]
INNER = [(9, 7), (23, 7), (23, 15), (21, 20), (16, 25), (11, 20), (9, 15)]


def poly(points, ox, fill):
    d.polygon([((x + ox) * S, y * S) for x, y in points], fill=fill)


for i in range(4):
    ox = i * 32
    poly(SHIELD, ox, 255)
    if i == 0:                                                           # max: an exclamation mark cut out
        d.rounded_rectangle([(ox + 14.5) * S, 7 * S, (ox + 17.5) * S, 18 * S], radius=1 * S, fill=0)
        d.ellipse([(ox + 14.5) * S, 20.5 * S, (ox + 17.5) * S, 23.5 * S], fill=0)
    else:
        poly(INNER, ox, 0)
    if i == 1:
        poly([(16, 9.5), (21.5, 15.5), (19.3, 17.7), (16, 14.4), (12.7, 17.7), (10.5, 15.5)], ox, 255)
    elif i == 2:
        poly([(16, 21.5), (21.5, 15.5), (19.3, 13.3), (16, 16.6), (12.7, 13.3), (10.5, 15.5)], ox, 255)
a = big.resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "threat")

# ring: a thin circle with a soft inner shadow, white (tinted in the game): the edge of a round gamepad button
# or of the minimap, in place of the game's gold rims.
w = h = 64
big = Image.new("L", (w * S, h * S), 0)
d = ImageDraw.Draw(big)
d.ellipse([2 * S, 2 * S, 62 * S, 62 * S], fill=255)
d.ellipse([5 * S, 5 * S, 59 * S, 59 * S], fill=0)
ring = big.resize((w, h), Image.LANCZOS)
shadow = Image.new("L", (w * S, h * S), 0)
ImageDraw.Draw(shadow).ellipse([4 * S, 4 * S, 60 * S, 60 * S], fill=90)
ImageDraw.Draw(shadow).ellipse([10 * S, 10 * S, 54 * S, 54 * S], fill=0)
shadow = shadow.filter(ImageFilter.GaussianBlur(3 * S)).resize((w, h), Image.LANCZOS)
a = ImageChops.lighter(ring, shadow)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "ring")

# disc: a filled circle with a soft edge, white (tinted in the game): the dark pool behind a round button, a
# cluster of gamepad buttons, or the minimap.
w = h = 64
big = Image.new("L", (w * S, h * S), 0)
ImageDraw.Draw(big).ellipse([6 * S, 6 * S, 58 * S, 58 * S], fill=255)
a = big.filter(ImageFilter.GaussianBlur(3 * S)).resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "disc")

# mapring: the minimap's edge, drawn large (512) so it stays a clean thin line at the minimap's size: a crisp
# ring with a faint inner shadow. The small "ring" above is for buttons.
w = h = 512
k = 2
line = Image.new("L", (w * k, h * k), 0)
d = ImageDraw.Draw(line)
d.ellipse([6 * k, 6 * k, 506 * k, 506 * k], fill=255)
d.ellipse([14 * k, 14 * k, 498 * k, 498 * k], fill=0)
line = line.resize((w, h), Image.LANCZOS)
shade = Image.new("L", (w, h), 0)
ImageDraw.Draw(shade).ellipse([12, 12, 500, 500], fill=70)
ImageDraw.Draw(shade).ellipse([34, 34, 478, 478], fill=0)
shade = shade.filter(ImageFilter.GaussianBlur(10))
a = ImageChops.lighter(line, shade)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "mapring")

# halo: a large soft disc for the dark glow behind the minimap (smooth at that size)
w = h = 256
big = Image.new("L", (w, h), 0)
ImageDraw.Draw(big).ellipse([28, 28, 228, 228], fill=255)
a = big.filter(ImageFilter.GaussianBlur(14))
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "halo")

# vines: a strip of growth along a bar (256x64), white (tinted: nature's green-brown, holy's gold): a wavy stem
# along the middle with curling branches above and below, and leaves. It grows over a bar with a heal over time.
import math
w, h = 256, 64
big = Image.new("L", (w * S, h * S), 0)
d = ImageDraw.Draw(big)


def stem(points, width):
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        d.line([(x1 * S, y1 * S), (x2 * S, y2 * S)], fill=255, width=max(1, int(width * S)))


def leaf(x, y, angle, size):
    pts = []
    for i in range(16):
        t = i / 15 * math.pi * 2
        px, py = math.cos(t) * size, math.sin(t) * size * 0.42
        ca, sa = math.cos(angle), math.sin(angle)
        pts.append(((x + px * ca - py * sa) * S, (y + px * sa + py * ca) * S))
    d.polygon(pts, fill=255)


main = [(x, 32 + math.sin(x / 19.0) * 6) for x in range(0, 257, 2)]
stem(main, 2.2)
for i, bx in enumerate(range(14, 250, 26)):
    up = (i % 2 == 0)
    by = 32 + math.sin(bx / 19.0) * 6
    sign = -1 if up else 1
    branch = []
    for k in range(12):
        t = k / 11
        branch.append((bx + t * 16, by + sign * (t * 20) - sign * math.sin(t * 3.1) * 4))
    stem(branch, 1.3)
    tip = branch[-1]
    leaf(tip[0] + 2, tip[1], sign * 0.6, 5.5)
    mid = branch[5]
    leaf(mid[0] - 3, mid[1] + sign * 2, sign * -0.9, 3.8)
a = big.filter(ImageFilter.GaussianBlur(0.35 * S)).resize((w, h), Image.LANCZOS)
white = Image.new("L", (w, h), 255)
save(Image.merge("RGBA", (white, white, white, a)), "vines")

# ---------------------------------------------------------------------------
# Cast bar art: the small things that work on a cast bar while it fills.
#
# Painted the way the game paints its own small things, so they sit beside its icons without looking pasted
# on: a dark line around every shape, a few flat tones (a lit side, a body, a shaded side) and one bright
# glint. They are shown small (a dozen to two dozen pixels), so every feature is chunky and nothing is finer
# than the line. Drawn in colour and not tinted in the game, except the runes (white, tinted by the school).
# ---------------------------------------------------------------------------
import math  # noqa: E402

Q = 64          # the side of a piece, in the units the shapes below are given in


def tinted(alpha):
    """A white texture with this alpha (tinted in the game)."""
    white = Image.new("L", alpha.size, 255)
    return Image.merge("RGBA", (white, white, white, alpha))


def sheet(w=Q, h=Q):
    return Image.new("L", (w * S, h * S), 0)


def layer(w=Q, h=Q):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


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


def paint(mask, base, dark, light, line, edge=2.6, depth=3.0, rim=1.4):
    """A shape in three flat tones with a dark line around it. The light comes from the upper left: the tone
    on that side sits just inside the line, the shaded tone on the side away from it."""
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


def small(img, w=Q, h=Q):
    return img.resize((w, h), Image.LANCZOS)


WOOD = dict(base=(156, 100, 52), dark=(104, 60, 30), light=(208, 150, 88), line=(44, 24, 12))
STEEL = dict(base=(170, 184, 206), dark=(104, 118, 150), light=(238, 244, 252), line=(30, 34, 50))
LEATHER = (96, 52, 34)


def handle(a, b, wide=7.5):
    """A wooden handle from a (the grip end) to b, with a leather wrap on the grip."""
    img = paint(rope(sheet(), [a, b], wide), **WOOD)
    wrap = sheet()
    for t in (0.10, 0.22, 0.34):
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        dx, dy = (b[1] - a[1]), -(b[0] - a[0])
        n = math.hypot(dx, dy)
        dx, dy = dx / n * wide / 2, dy / n * wide / 2
        rope(wrap, [(x - dx, y - dy), (x + dx, y + dy)], 2.6)
    ink(img, LEATHER, ImageChops.multiply(wrap, rope(sheet(), [a, b], wide)))
    return img


# pick: a miner's pick, its head up and to the right (it pecks at the bar from above).
def pick_head(grow=0.0):
    """The head: a crescent across the top of the handle, thick in the middle, a point at each end."""
    top, along, across = (43, 20), (0.644, -0.765), (0.765, 0.644)
    tips = [(top[0] - across[0] * (21 + grow), top[1] - across[1] * (21 + grow)),
            (top[0] + across[0] * (21 + grow), top[1] + across[1] * (21 + grow))]

    def curve(bulge):
        c = (top[0] + along[0] * bulge, top[1] + along[1] * bulge)
        return [((1 - t) ** 2 * tips[0][0] + 2 * t * (1 - t) * c[0] + t * t * tips[1][0],
                 (1 - t) ** 2 * tips[0][1] + 2 * t * (1 - t) * c[1] + t * t * tips[1][1])
                for t in [i / 32 for i in range(33)]]
    return curve(21) + curve(3)[::-1]


head = paint(poly(sheet(), pick_head()), depth=2.4, **STEEL)
collar = paint(blob(sheet(), [37, 14, 49, 26]), depth=2.0, edge=2.0, **STEEL)      # where the head sits on the handle
glint = rope(sheet(), [(33, 9), (38, 8)], 2.2)
save(small(over(handle((12, 57), (41, 22)), head, collar, ink(layer(), (255, 255, 255), glint))), "pick")

# hammer: a smith's hammer for crafting, a heavy block of a head with a band at each face.
h_dir, a_dir, c = (0.631, -0.776), (0.776, 0.631), (42, 21)


def block(half_long, half_thick, shift=0.0):
    out = []
    for sl, st in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
        out.append((c[0] + a_dir[0] * (sl * half_long + shift) + h_dir[0] * st * half_thick,
                    c[1] + a_dir[1] * (sl * half_long + shift) + h_dir[1] * st * half_thick))
    return out


head = paint(poly(sheet(), block(15, 9.5)), depth=2.6, **STEEL)
bands = poly(poly(sheet(), block(2.2, 9.5, 11.5)), block(2.2, 9.5, -11.5))
ink(head, STEEL["dark"], bands)
glint = rope(sheet(), [(33, 9), (37, 6.5)], 2.4)
save(small(over(handle((14, 57), (38, 27)), head, ink(layer(), (255, 255, 255), glint))), "hammer")


# flame: a tongue of fire with a small one licking up beside it: deep red at the edge, orange, a yellow heart.
def tongue(cx, foot, tall, half, lean, scale=1.0):
    """The outline of one tongue: round at the foot, leaning and curling to a point."""
    tall, half = tall * scale, half * scale
    left, right = [], []
    for i in range(49):
        t = i / 48
        w = half * (math.sin(min(1.0, t * 1.9) * math.pi / 2) ** 0.8) * (1 - t) ** 0.62
        mid = cx + lean * math.sin(t * 2.6) * t * scale
        y = foot - t * tall
        left.append((mid - w, y))
        right.append((mid + w, y))
    return left + right[::-1]


def fire(scale, drop=0.0):
    m = poly(sheet(), tongue(35, 60 - drop, 55, 21, 7, scale))
    poly(m, tongue(15, 60 - drop, 30, 10, -4, scale))                 # the small tongue
    blob(m, [35 - 21 * scale, 60 - drop - 13 * scale, 35 + 21 * scale, 62 - drop + 2 * scale])
    return m


img = layer()
ink(img, (112, 20, 6), fatter(fire(1.0), 1.5))
ink(img, (226, 62, 16), fire(1.0))
ink(img, (255, 138, 24), fire(0.76, 1))
ink(img, (255, 214, 84), fire(0.50, 2))
ink(img, (255, 250, 214), fire(0.24, 4))
save(small(img), "flame")

# crystal: a cluster of three shards of ice, each cut in facets: a lit face, a body, a shaded face.
ICE_LINE, ICE_LIT, ICE_PALE, ICE_MID, ICE_DEEP = (26, 58, 112), (240, 250, 255), (184, 226, 252), (118, 184, 240), (62, 120, 200)


def shard(img, tip, left, right, foot_l, foot_r):
    """One shard: the ridge runs from the tip down the middle to the foot."""
    ridge_top = ((left[0] + right[0]) / 2 + 1, (left[1] + right[1]) / 2 - 3)
    ridge_foot = ((foot_l[0] + foot_r[0]) / 2 + 1, foot_l[1])
    ink(img, ICE_LIT, poly(sheet(), [tip, left, ridge_top]))
    ink(img, ICE_MID, poly(sheet(), [tip, right, ridge_top]))
    ink(img, ICE_PALE, poly(sheet(), [left, ridge_top, ridge_foot, foot_l]))
    ink(img, ICE_DEEP, poly(sheet(), [right, ridge_top, ridge_foot, foot_r]))


shards = [((49, 25), (43, 40), (56, 41), (42, 60), (55, 60)),          # the two small ones behind
          ((14, 31), (8, 45), (21, 44), (10, 60), (22, 60)),
          ((32, 3), (20, 25), (44, 24), (24, 60), (40, 60))]           # the tall one in front
whole = sheet()
for tip, left, right, foot_l, foot_r in shards:
    poly(whole, [tip, right, foot_r, foot_l, left])
img = layer()
ink(img, ICE_LINE, fatter(whole, 2.6))
for parts in shards:
    solid = poly(sheet(), [parts[0], parts[2], parts[4], parts[3], parts[1]])
    ink(img, ICE_LINE, fatter(solid, 1.3))                             # a thin line between the shards
    shard(img, *parts)
ink(img, (255, 255, 255), rope(sheet(), [(27, 20), (30, 12)], 2.0))    # the glint
save(small(img), "crystal")

# ghost: a shade out of a bad dream. A pale skull of a face in a dark hood, sockets that sag at their outer
# corners with a cold light far back in each, a jaw hanging open much too wide, a shroud in tatters. It
# faces you.
shroud = blob(sheet(), [13, 3, 51, 41])
poly(shroud, [(15, 20), (6, 34), (8, 46), (13, 61), (19, 48), (25, 62), (31, 51), (38, 62), (44, 49), (51, 61),
              (56, 45), (58, 33), (49, 20)])
img = paint(shroud, base=(58, 32, 96), dark=(28, 12, 56), light=(116, 80, 166), line=(12, 4, 26), depth=3.2)
face = blob(sheet(), [20, 9, 44, 37])
poly(face, [(21, 26), (43, 26), (39.5, 45), (34, 52.5), (30, 52.5), (24.5, 45)])
skull = paint(face, base=(204, 198, 222), dark=(140, 126, 174), light=(246, 242, 254), line=(18, 6, 38),
              edge=1.6, depth=2.4, rim=1.0)
holes = sheet()
poly(holes, [(21.5, 17.5), (30, 20), (30.5, 27), (25.5, 32), (21, 27.5)])        # the sockets
poly(holes, [(42.5, 17.5), (34, 20), (33.5, 27), (38.5, 32), (43, 27.5)])
poly(holes, [(31, 30), (33, 30), (33.8, 34.5), (30.2, 34.5)])                    # where a nose was
poly(holes, [(26.5, 37), (37.5, 37), (36.5, 46), (33.8, 51), (30.2, 51), (27.5, 46)])   # the jaw
ink(skull, (10, 2, 22), ImageChops.multiply(holes, face))
teeth = sheet()
for x in (28.4, 30.8, 33.2, 35.6):
    poly(teeth, [(x - 1.1, 37), (x + 1.1, 37), (x, 40.4)])
ink(skull, (236, 232, 246), teeth)
ink(skull, (176, 255, 136), blob(blob(sheet(), [25, 23.4, 27.8, 26.2]), [36.2, 23.4, 39, 26.2]))
save(small(over(img, skull)), "ghost")
# leaf: one broad leaf with a pale midrib, its stalk at the bottom.
def leaf_edge(sign):
    out = []
    for i in range(41):
        t = i / 40
        half = 19 * math.sin(math.pi * t) ** 0.85 * (1 - 0.3 * t)
        out.append((32 + 2.5 * math.sin(math.pi * t) + sign * half, 54 - t * 50))
    return out


blade = poly(sheet(), leaf_edge(-1) + leaf_edge(1)[::-1])
img = paint(blade, base=(92, 186, 58), dark=(46, 124, 40), light=(174, 238, 98), line=(20, 56, 18), depth=3.6)
stalk = paint(rope(sheet(), [(31, 58.5), (32, 51)], 3.0), base=(92, 150, 50), dark=(60, 110, 40), light=(150, 210, 90),
              line=(20, 56, 18), edge=2.0, depth=1.2, rim=0.8)
ribs = sheet()
rib = [(32 + 2.5 * math.sin(math.pi * t), 54 - t * 50) for t in [i / 20 for i in range(18)]]
rope(ribs, rib, 2.4, 1.0)
for t, reach in ((0.26, 10), (0.46, 10), (0.66, 7)):
    x, y = 32 + 2.5 * math.sin(math.pi * t), 54 - t * 50
    rope(ribs, [(x, y), (x - reach, y - reach * 0.75)], 1.6, 0.9)
    rope(ribs, [(x, y), (x + reach, y - reach * 0.75)], 1.6, 0.9)
ink(img, (214, 250, 150), ImageChops.multiply(ribs, thinner(blade, 2.4)))
save(small(over(stalk, img)), "leaf")

# runes: four signs side by side (256x64), white (tinted by the school of the spell), picked by texture
# coordinates. Each is a few heavy strokes with pointed ends inside a thin ring, in a soft glow: shapes of
# our own, not letters of any alphabet.
big = sheet(Q * 4, Q)


def stroke(ox, points, width=5.0):
    rope(big, [(x + ox, y) for x, y in points], width)
    for (x, y), (x2, y2) in ((points[0], points[1]), (points[-1], points[-2])):       # a point at each end
        dx, dy = x - x2, y - y2
        n = math.hypot(dx, dy) or 1
        dx, dy = dx / n, dy / n
        poly(big, [(x + ox + dx * 5, y + dy * 5), (x + ox - dy * 3.6, y + dx * 3.6), (x + ox + dy * 3.6, y - dx * 3.6)])


def ring(ox):
    d = ImageDraw.Draw(big)
    d.ellipse([(ox + 3) * S, 3 * S, (ox + 61) * S, 61 * S], outline=150, width=int(1.6 * S))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        x, y = ox + 32 + math.cos(a) * 29, 32 + math.sin(a) * 29
        blob(big, [x - 2.4, y - 2.4, x + 2.4, y + 2.4])


for g in range(4):
    ring(g * Q)
stroke(0, [(32, 14), (32, 50)])                                      # a stave with two branches
stroke(0, [(32, 26), (45, 16)])
stroke(0, [(32, 38), (19, 28)])
stroke(Q, [(32, 13), (46, 32), (32, 51), (18, 32), (32, 13)], 4.4)   # a diamond with a heart
blob(big, [Q + 27.5, 27.5, Q + 36.5, 36.5])
stroke(2 * Q, [(20, 16), (44, 16)])                                  # a bolt under a roof
stroke(2 * Q, [(41, 16), (24, 31), (41, 34), (25, 50)])
ImageDraw.Draw(big).arc([(3 * Q + 17) * S, 17 * S, (3 * Q + 47) * S, 47 * S], 40, 320, fill=255, width=int(5 * S))
stroke(3 * Q, [(32, 12), (32, 52)])                                  # an open ring, crossed
stroke(3 * Q, [(24, 32), (40, 32)], 4.4)
glow = big.filter(ImageFilter.GaussianBlur(2.6 * S))
a = ImageChops.lighter(small(big, Q * 4, Q), small(glow, Q * 4, Q).point(lambda v: int(v * 0.6)))
save(tinted(a), "runes")

# roots: a strip of roots creeping along a bar (512x64): a thick strand of bark that wanders along the middle
# and thins towards the tip, a thinner one twisting by, rootlets feeling up and down from them, a knot here
# and there.
w, h = 512, 64


def mid(x):
    return 32 + math.sin(x / 46.0) * 9 + math.sin(x / 18.0) * 3.2


bark = sheet(w, h)
rope(bark, [(x, mid(x + 80) + 3) for x in range(-4, 517, 4)], 5.0, 3.0)        # the thinner one, behind
rope(bark, [(x, mid(x)) for x in range(-4, 517, 4)], 10.5, 5.5)
knots = sheet(w, h)
for i, bx in enumerate(range(20, 500, 34)):
    sign = -1 if i % 2 == 0 else 1
    reach = 17 + (i * 7) % 8
    run = [(bx + (k / 8) * (16 + (i * 3) % 12), mid(bx) + sign * ((k / 8) ** 0.8) * reach + math.sin(k / 8 * 5 + i) * 2.4)
           for k in range(9)]
    rope(bark, run, 4.6, 2.0)
    if i % 3 == 0:                                                              # some fork again
        fx, fy = run[5]
        rope(bark, [(fx + t * 12, fy + sign * t * 8 - sign) for t in (0, 0.5, 1)], 3.0, 1.8)
    if i % 4 == 1:
        blob(knots, [bx + 9, mid(bx + 12) - 2.4, bx + 15, mid(bx + 12) + 2.4])
img = paint(bark, base=(128, 86, 48), dark=(82, 50, 28), light=(188, 140, 84), line=(36, 22, 10),
            edge=2.2, depth=2.6, rim=1.1)
ink(img, (70, 42, 22), ImageChops.multiply(knots, bark))
save(small(img, w, h), "roots")

# bolt: a stroke of lightning running left to right (128x64), white (tinted in the game: green for nature,
# pale blue for lightning), with a fork up and a fork down, in its own glow. It is stretched along a bar and
# flipped, so no two strokes look the same.
w, h = 128, 64
core = sheet(w, h)
rope(core, [(2, 30), (16, 21), (27, 37), (43, 25), (56, 41), (71, 27), (85, 39), (100, 23), (113, 35), (126, 30)], 4.4, 2.8)
rope(core, [(43, 25), (53, 13), (64, 17), (75, 7)], 2.8, 1.0)
rope(core, [(85, 39), (94, 51), (105, 48), (114, 58)], 2.6, 1.0)
glow = core.filter(ImageFilter.GaussianBlur(3.4 * S))
a = ImageChops.lighter(small(core, w, h), small(glow, w, h).point(lambda v: int(v * 0.6)))
save(tinted(a), "bolt")


# flower: a bloom seen from above, five pale petals blushing pink around a golden heart. Pale on purpose: a
# heal of another school tints it (holy turns it to gold).
def petal(angle, far=15.5, long=12.5, wide=9.5):
    cx, cy = 32 + math.cos(angle) * far, 32 + math.sin(angle) * far
    out = []
    for i in range(36):
        t = i / 36 * 2 * math.pi
        px, py = math.cos(t) * long, math.sin(t) * wide * (1 - 0.25 * math.cos(t))
        out.append((cx + px * math.cos(angle) - py * math.sin(angle), cy + px * math.sin(angle) + py * math.cos(angle)))
    return out


img = layer()
for k in (1, 3, 0, 2, 4):
    one = paint(poly(sheet(), petal(-math.pi / 2 + k * 2 * math.pi / 5)), base=(255, 226, 238), dark=(238, 150, 192),
                light=(255, 252, 254), line=(118, 38, 84), edge=2.2, depth=2.4, rim=1.2)
    img = over(img, one)
heart = paint(blob(sheet(), [25, 25, 39, 39]), base=(255, 204, 62), dark=(224, 136, 28), light=(255, 244, 160),
              line=(118, 58, 18), edge=1.8, depth=2.0, rim=1.0)
save(small(over(img, heart)), "flower")


# vine: a strip of living vine winding along a bar (512x64), with a leaf at every turn and a curl of tendril
# here and there: the stem of the flowers that open on a heal.
def lens(cx, cy, angle, long, wide):
    out = []
    for i in range(25):
        t = i / 24
        out.append((t * long, math.sin(t * math.pi) ** 0.8 * wide))
    out += [(x, -y) for x, y in out[::-1]]
    return [(cx + x * math.cos(angle) - y * math.sin(angle), cy + x * math.sin(angle) + y * math.cos(angle)) for x, y in out]


w, h = 512, 64


def wind(x):
    return 32 + math.sin(x / 30.0) * 8


stem = sheet(w, h)
rope(stem, [(x, wind(x)) for x in range(-4, 517, 4)], 6.4, 4.0)
leaves = layer(w, h)
for i, bx in enumerate(range(18, 500, 47)):
    up = i % 2 == 0
    angle = (-1 if up else 1) * (0.9 + 0.25 * math.sin(i * 1.7))
    one = paint(poly(sheet(w, h), lens(bx, wind(bx), angle, 19 + (i * 5) % 6, 6.5)), base=(98, 190, 60), dark=(48, 126, 40),
                light=(176, 238, 100), line=(16, 48, 16), edge=2.0, depth=2.2, rim=1.0)
    leaves = over(leaves, one)
    if i % 2 == 1:                                                   # a tendril curling off the other way
        curl = [(bx + 22 + math.cos(t) * (7 - t), wind(bx + 22) - 11 + math.sin(t) * (7 - t)) for t in
                [k / 6 * 4.6 for k in range(7)]]
        rope(stem, [(bx + 14, wind(bx + 14))] + curl, 2.8, 1.4)
img = paint(stem, base=(72, 152, 52), dark=(38, 98, 36), light=(146, 214, 92), line=(16, 48, 16), edge=2.0, depth=2.2, rim=1.0)
save(small(over(img, leaves), w, h), "vine")

# fish: one plump fish seen from the side, swimming to the right (the game beside the fishing interface;
# mirrored in the game when it swims the other way)
def fish_edge(sign):
    out = []
    for i in range(41):
        t = i / 40
        half = 12.5 * math.sin(math.pi * t) ** 0.7 * (1 - 0.18 * t)
        out.append((17 + t * 35, 32 + sign * half))
    return out


body = poly(sheet(), fish_edge(-1) + fish_edge(1)[::-1])
tail = poly(sheet(), [(20, 32), (6, 20), (9.5, 32), (6, 44)])
fins = poly(poly(sheet(), [(29, 22), (37, 13.5), (43, 22.5)]), [(31, 41.5), (36, 49), (40, 41)])
img = over(paint(tail, base=(232, 126, 44), dark=(170, 78, 28), light=(255, 186, 96), line=(58, 24, 10), depth=2.4),
           paint(fins, base=(232, 126, 44), dark=(170, 78, 28), light=(255, 186, 96), line=(58, 24, 10), depth=2.0),
           paint(body, base=(246, 160, 58), dark=(188, 96, 32), light=(255, 216, 128), line=(58, 24, 10), depth=3.4))
belly = ImageChops.multiply(blob(sheet(), [22, 33, 48, 47]), thinner(body, 2.2))
ink(img, (255, 232, 176), belly)
ink(img, (58, 24, 10), rope(sheet(), [(40.5, 26), (39.5, 31), (40.5, 37)], 1.3))        # the gill
ink(img, (255, 255, 255), blob(sheet(), [43, 25.5, 48.6, 31.1]))
ink(img, (24, 14, 10), blob(sheet(), [45, 27.2, 48, 30.2]))
save(small(img), "fish")
