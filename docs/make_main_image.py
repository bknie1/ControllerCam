"""Builds the ControllerCam main image from an in-game screenshot: grade, title, reticle and callouts."""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageChops

SRC, LOGO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
S = 2                                   # overlay supersampling
BW, BH = 2000, 1125
FONTS = r"C:\Windows\Fonts"
NAVY = (36, 50, 102)
RED = (234, 84, 96)
GOLD = (250, 196, 78)

base = Image.open(SRC).convert("RGB").resize((BW, BH), Image.LANCZOS)

# ---- grade: slightly richer, warm highlights, vignette, and a dark gradient on the left for the title
base = ImageEnhance.Contrast(base).enhance(1.08)
base = ImageEnhance.Color(base).enhance(1.12)
vig = Image.new("L", (BW, BH), 0)
vp = vig.load()
cx, cy = BW / 2, BH / 2
for y in range(BH):
    for x in range(BW):
        dx, dy = (x - cx) / cx, (y - cy) / cy
        r = math.sqrt(dx * dx * 0.8 + dy * dy)
        vp[x, y] = int(max(0, min(1, (r - 0.55) / 0.9)) ** 1.6 * 150)
base = Image.composite(Image.new("RGB", (BW, BH), (12, 16, 36)), base, vig)

left = Image.new("L", (BW, BH), 0)
lp = left.load()
for y in range(BH):
    for x in range(BW):
        k = max(0.0, 1 - x / 1150)
        t = max(0.0, 1 - y / 520)
        lp[x, y] = int(min(1.0, k * 0.85 + t * 0.35) * 170)
base = Image.composite(Image.new("RGB", (BW, BH), (14, 20, 46)), base, left)
bottom = Image.new("L", (BW, BH), 0)
bp = bottom.load()
for y in range(BH):
    v = int(max(0.0, (y - 900) / 225) * 150)
    for x in range(BW):
        bp[x, y] = v
base = Image.composite(Image.new("RGB", (BW, BH), (14, 20, 46)), base, bottom)

# ---- overlay at 2x
W, H = BW * S, BH * S
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(ov)


def f(name, size):
    return ImageFont.truetype(f"{FONTS}\\{name}", int(size * S))


def text_shadow(xy, s, font, fill, anchor="la", glow=(14, 20, 46, 255), off=3):
    x, y = xy
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.text((x * S + off * S, y * S + off * S), s, font=font, fill=(10, 14, 34, 200), anchor=anchor)
    sh = sh.filter(ImageFilter.GaussianBlur(5 * S))
    ov.alpha_composite(sh)
    dd = ImageDraw.Draw(ov)
    dd.text((x * S, y * S), s, font=font, fill=fill, anchor=anchor, stroke_width=int(2 * S), stroke_fill=glow)
    dd.text((x * S, y * S), s, font=font, fill=fill, anchor=anchor)


def ring(cx_, cy_, r, width, color):
    box = [(cx_ - r) * S, (cy_ - r) * S, (cx_ + r) * S, (cy_ + r) * S]
    d.ellipse(box, outline=color, width=int(width * S))


def line(p, q, color, width, dash=0):
    (x0, y0), (x1, y1) = p, q
    if not dash:
        d.line([(x0 * S, y0 * S), (x1 * S, y1 * S)], fill=color, width=int(width * S))
        return
    L = math.hypot(x1 - x0, y1 - y0)
    n = int(L / (dash * 2))
    for i in range(n + 1):
        a = i * dash * 2 / L
        b = min(1.0, (i * dash * 2 + dash) / L)
        d.line([((x0 + (x1 - x0) * a) * S, (y0 + (y1 - y0) * a) * S),
                ((x0 + (x1 - x0) * b) * S, (y0 + (y1 - y0) * b) * S)], fill=color, width=int(width * S))


def arrow_head(tip, frm, color, size=16):
    ang = math.atan2(tip[1] - frm[1], tip[0] - frm[0])
    pts = [tip,
           (tip[0] - size * math.cos(ang - 0.45), tip[1] - size * math.sin(ang - 0.45)),
           (tip[0] - size * math.cos(ang + 0.45), tip[1] - size * math.sin(ang + 0.45))]
    d.polygon([(x * S, y * S) for x, y in pts], fill=color)


def chip(x, y, label, font, fg=(255, 255, 255, 255), bg=(24, 34, 78, 205), edge=(255, 255, 255, 90), padx=22, h=52):
    tw = d.textlength(label, font=font) / S
    w = tw + padx * 2
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S], radius=(h / 2) * S, fill=bg, outline=edge, width=int(2 * S))
    d.text(((x + padx) * S, (y + h / 2) * S), label, font=font, fill=fg, anchor="lm")
    return w


# ---- target reticle on the village hall (same style as the logo)
RX, RY = 1335, 470
for r, wd, col in [(58, 11, (36, 50, 102, 230)), (58, 6, RED + (255,))]:
    ring(RX, RY, r, wd, col)
for ang in (0, 90, 180, 270):
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    line((RX + 40 * c, RY + 40 * s), (RX + 82 * c, RY + 82 * s), (36, 50, 102, 230), 11)
    line((RX + 40 * c, RY + 40 * s), (RX + 82 * c, RY + 82 * s), RED + (255,), 6)
d.ellipse([(RX - 11) * S, (RY - 11) * S, (RX + 11) * S, (RY + 11) * S], fill=(36, 50, 102, 255))
d.ellipse([(RX - 7) * S, (RY - 7) * S, (RX + 7) * S, (RY + 7) * S], fill=RED + (255,))

# ---- shoulder offset: dashed screen centre, bracket from the character to the centre
CX = BW // 2
line((CX, 430), (CX, 1000), (255, 255, 255, 150), 3, dash=14)
chx = 690                                     # the character's centre line
line((chx, 1040), (chx, 985), GOLD + (255,), 4)
line((CX, 1040), (CX, 985), GOLD + (255,), 4)
line((chx + 4, 1012), (CX - 4, 1012), GOLD + (255,), 5)
arrow_head((CX - 2, 1012), (chx, 1012), GOLD + (255,), 20)
arrow_head((chx + 2, 1012), (CX, 1012), GOLD + (255,), 20)
text_shadow(((chx + CX) / 2 - 8, 970), "+2 SHOULDER OFFSET", f("segoeuib.ttf", 27), GOLD + (255,), anchor="ms")

# ---- head tracking callout pointing at the mohawk
HX, HY = 690, 585
line((HX + 40, HY - 40), (905, 365), (255, 255, 255, 235), 4)
d.ellipse([(HX + 40 - 7) * S, (HY - 40 - 7) * S, (HX + 40 + 7) * S, (HY - 40 + 7) * S], fill=(255, 255, 255, 255))
ring(HX + 40, HY - 40, 18, 4, (255, 255, 255, 255))
lab = "HEAD TRACKING"
lf = f("segoeuib.ttf", 30)
tw = d.textlength(lab, font=lf) / S
d.rounded_rectangle([905 * S, 335 * S, (905 + tw + 44) * S, 395 * S], radius=30 * S, fill=(24, 34, 78, 225), outline=(255, 255, 255, 120), width=2 * S)
d.text((927 * S, 365 * S), lab, font=lf, fill=(255, 255, 255, 255), anchor="lm")

# ---- title block
logo = Image.open(LOGO).convert("RGBA").resize((150 * S, 150 * S), Image.LANCZOS)
ov.alpha_composite(logo, (88 * S, 84 * S))
text_shadow((262, 70), "ControllerCam", f("bahnschrift.ttf", 118), (255, 255, 255, 255), glow=(30, 42, 96, 255), off=4)
text_shadow((268, 206), "Action camera for controller play", f("segoeuib.ttf", 42), (232, 240, 255, 255), glow=(24, 34, 84, 255), off=3)
# accent bar
d.rounded_rectangle([92 * S, 262 * S, 392 * S, 270 * S], radius=4 * S, fill=GOLD + (255,))
d.rounded_rectangle([404 * S, 262 * S, 460 * S, 270 * S], radius=4 * S, fill=RED + (255,))

# ---- profile chips, bottom right
cf = f("segoeuib.ttf", 30)
x = 1080
x += chip(x, 1034, "Action", cf, bg=(36, 50, 102, 235)) + 14
x += chip(x, 1034, "Hybrid", cf) + 14
x += chip(x, 1034, "Classic", cf) + 14
chip(x, 1034, "+8 more", f("segoeui.ttf", 30), fg=(220, 230, 255, 255))
chip(1080, 970, "WoW: Forever  ·  Gamepad UI", f("segoeui.ttf", 26), fg=(255, 255, 255, 255), bg=(24, 34, 78, 180), h=46)

ov = ov.resize((BW, BH), Image.LANCZOS)
out = base.convert("RGBA")
out.alpha_composite(ov)
out.convert("RGB").save(OUT, optimize=True)
print("saved", OUT, out.size)
