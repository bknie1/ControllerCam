"""Draws the ControllerCam logo (512x512) with Pillow, in the style of the InputSwap logo."""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 4                      # drawing scale (supersampling), the result is shrunk to 512
W = 512 * S
NAVY = (36, 50, 102, 255)
OUT = 7 * S                # outline width

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# ---------------------------------------------------------------- background: sky, horizon, ground
HORIZON = 290
grad = Image.new("RGBA", (W, W))
gp = grad.load()
sky_top, sky_low = (126, 200, 248), (208, 228, 232)
gr_far, gr_near = (190, 216, 152), (240, 214, 154)
for y in range(W):
    yy = y / S
    if yy < HORIZON:
        k = yy / HORIZON
        c = tuple(int(sky_top[i] + (sky_low[i] - sky_top[i]) * k) for i in range(3))
    else:
        k = (yy - HORIZON) / (512 - HORIZON)
        c = tuple(int(gr_far[i] + (gr_near[i] - gr_far[i]) * k) for i in range(3))
    for x in range(W):
        gp[x, y] = c + (255,)
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, W - 1], radius=112 * S, fill=255)
img.paste(grad, (0, 0), mask)

layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)


def P(pts):
    return [(x * S, y * S) for x, y in pts]


def circle(cx, cy, r, fill):
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=fill)


# bubbles and sparkles (soft, like the InputSwap logo)
for cx, cy, r, a in [(62, 72, 26, 90), (266, 46, 15, 90), (440, 88, 46, 70), (84, 446, 44, 70), (470, 330, 12, 70)]:
    circle(cx, cy, r, (255, 255, 255, a))


def sparkle(cx, cy, r, a=230):
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(P(pts), fill=(255, 255, 255, a))


for cx, cy, r in [(412, 52, 11), (44, 268, 8), (284, 478, 10), (482, 246, 7), (205, 70, 7)]:
    sparkle(cx, cy, r)


# ---------------------------------------------------------------- helpers
def spline(pts, closed=True, per=24):
    """Catmull-Rom curve through the points (smooth cartoon blobs)."""
    n = len(pts)
    out = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[i]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else pts[(i + 1) % n]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    if not closed:
        out.append(pts[-1])
    return out


def dense(pp, step):
    out = []
    for i in range(len(pp) - 1):
        (x0, y0), (x1, y1) = pp[i], pp[i + 1]
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for k in range(n):
            t = k / n
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    out.append(pp[-1])
    return out


def stroke(pp, width, color):
    """A smooth stroke: round stamps close together along the path (width in canvas pixels)."""
    r = width / 2
    for x, y in dense(pp, max(1.0, width / 6)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def shape(pts, fill, smooth=True, width=OUT):
    pts = spline(pts) if smooth else pts
    pp = P(pts)
    stroke(pp + [pp[0]], width * 2, NAVY)           # the outer half stays visible
    d.polygon(pp, fill=fill)


def thick(pts, color, width, outline=True, smooth=False):
    """A line with a navy edge: navy wide, then the colour narrower."""
    pp = P(spline(pts, closed=False) if smooth else pts)
    if outline:
        stroke(pp, (width + 7) * S, NAVY)
    stroke(pp, width * S, color)


GREEN = (124, 205, 140, 255)
GREEN_L = (162, 228, 170, 255)
BLUE = (84, 150, 232, 255)
PURPLE = (160, 124, 216, 255)
DPURPLE = (112, 96, 196, 255)
YELLOW = (250, 184, 56, 255)
RED = (234, 84, 96, 255)
WHITE = (252, 252, 252, 255)

# soft hills on the horizon and a sandy path running to the vanishing point
def blob_flat(pts, color):
    d.polygon(P(spline(pts)), fill=color)

blob_flat([(250, 296), (300, 262), (360, 250), (420, 262), (470, 276), (540, 296)], (170, 206, 170, 255))
blob_flat([(120, 296), (180, 268), (250, 262), (320, 280), (360, 296)], (150, 192, 164, 255))
d.polygon(P([(296, HORIZON), (314, HORIZON), (470, 520), (200, 520)]), fill=(246, 228, 180, 190))
for cx, cy, r in [(350, 232, 0)]:
    pass

# ---------------------------------------------------------------- the target: a boar inside the reticle
BX, BY = 440, 292
def boar():
    # legs
    for lx in (424, 436, 452, 464):
        shape([(lx - 5, BY + 12), (lx + 5, BY + 12), (lx + 4, BY + 27), (lx - 4, BY + 27)], (170, 110, 78, 255), smooth=False, width=4 * S)
    shape([(BX - 34, BY - 2), (BX - 14, BY - 20), (BX + 20, BY - 22), (BX + 38, BY - 6), (BX + 34, BY + 14), (BX + 4, BY + 20), (BX - 26, BY + 16)], (206, 150, 104, 255), width=5 * S)
    # head, snout, ear, tusk
    shape([(BX - 40, BY - 4), (BX - 28, BY - 16), (BX - 12, BY - 10), (BX - 10, BY + 8), (BX - 28, BY + 16), (BX - 42, BY + 8)], (206, 150, 104, 255), width=5 * S)
    shape([(BX - 52, BY + 2), (BX - 42, BY - 3), (BX - 38, BY + 9), (BX - 50, BY + 10)], (244, 168, 170, 255), width=4 * S)
    shape([(BX - 30, BY - 14), (BX - 22, BY - 30), (BX - 14, BY - 12)], (170, 110, 78, 255), smooth=False, width=4 * S)
    shape([(BX - 40, BY + 8), (BX - 34, BY + 0), (BX - 30, BY + 10)], WHITE, smooth=False, width=3 * S)
    circle(BX - 26, BY - 4, 3, NAVY)
boar()
RX, RY, RR = 434, 288, 50
ring = [(RX + RR * math.cos(a / 40 * 2 * math.pi), RY + RR * math.sin(a / 40 * 2 * math.pi)) for a in range(41)]
thick(ring, RED, 9)
for ang in (0, 90, 180, 270):
    c, s_ = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    thick([(RX + 34 * c, RY + 34 * s_), (RX + 64 * c, RY + 64 * s_)], RED, 8)

# ---------------------------------------------------------------- arrow in flight and speed lines
thick([(362, 300), (384, 296)], WHITE, 6)
shape([(401, 294), (382, 284), (383, 305)], (206, 216, 236, 255), smooth=False, width=4 * S)
shape([(362, 300), (350, 286), (364, 287), (372, 299)], RED, smooth=False, width=4 * S)
shape([(362, 300), (352, 314), (366, 313), (372, 299)], RED, smooth=False, width=4 * S)
thick([(370, 272), (392, 266)], WHITE, 3, outline=False)
thick([(368, 326), (392, 320)], WHITE, 3, outline=False)

# ---------------------------------------------------------------- the troll hunter, seen from behind his shoulder
# torso
top = spline([(0, 440), (8, 392), (50, 340), (120, 318), (196, 332), (244, 372), (264, 430), (270, 520)], closed=False)
shape(top + [(270, 530), (0, 530)], BLUE, smooth=False)
shape([(176, 326), (214, 344), (108, 530), (52, 530)], YELLOW, smooth=False, width=5 * S)             # strap
# quiver with arrows
for ax, ay, bx, by in [(44, 352, 22, 312), (60, 344, 48, 298)]:
    thick([(ax, ay), (bx, by)], WHITE, 5)
    shape([(bx - 9, by - 4), (bx + 3, by - 13), (bx + 9, by + 2)], RED, smooth=False, width=4 * S)
shape([(34, 366), (74, 340), (156, 470), (116, 496)], DPURPLE, smooth=False)

# bow arm reaching into the scene, hand on the grip
thick([(212, 366), (262, 344), (322, 314)], GREEN, 26, smooth=True)
# bow (in front of the hand), string
bow = [(318, 214), (336, 262), (346, 308), (336, 354), (318, 402)]
thick(bow, YELLOW, 14, smooth=True)
thick([(318, 214), (318, 402)], WHITE, 3)
shape([(338, 292), (354, 292), (354, 324), (338, 324)], BLUE, smooth=False, width=4 * S)
circle(330, 312, 17, NAVY)
circle(330, 312, 13, GREEN)

# head from behind, ear sticking out, nose and tusk peeking past the cheek
shape([(86, 244), (38, 234), (10, 184), (64, 206), (92, 226)], GREEN, smooth=False)                  # ear
shape([(190, 252), (216, 262), (214, 280), (194, 288)], GREEN, width=6 * S)                          # nose
shape([(196, 292), (210, 280), (214, 300), (202, 308)], WHITE, smooth=False, width=4 * S)            # tusk
shape([(78, 238), (90, 196), (130, 180), (172, 194), (192, 232), (198, 264), (188, 298), (150, 318), (108, 314), (82, 284)], GREEN)
thick([(74, 226), (50, 220)], NAVY, 4, outline=False)                                              # ear fold
# mohawk down the middle of the head
for base_a, tip, base_b in [((186, 202), (186, 138), (164, 192)), ((168, 192), (148, 124), (138, 186)),
                            ((142, 186), (110, 128), (112, 188)), ((116, 188), (80, 148), (90, 200))]:
    shape([base_a, tip, base_b], RED, smooth=False, width=6 * S)
thick([(176, 214), (152, 230)], GREEN_L, 5, outline=False)                                         # highlight

img.alpha_composite(layer)
final = Image.new("RGBA", (W, W), (0, 0, 0, 0))
final.paste(img, (0, 0), mask)
final = final.resize((512, 512), Image.LANCZOS)
out = sys.argv[1]
final.save(out)
print("saved", out, final.size)
