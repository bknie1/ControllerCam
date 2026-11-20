"""Builds the ControllerCam HUD gallery image from an in-game screenshot: grade, title and callouts.

    python docs/make_hud_image.py <screenshot> docs/logo.png docs/hud-image.png
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

SRC, LOGO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
S = 2                                   # overlay supersampling
BW, BH = 2000, 1125
FONTS = r"C:\Windows\Fonts"
NAVY = (24, 34, 78)
RED = (234, 84, 96)
GOLD = (250, 196, 78)

base = Image.open(SRC).convert("RGB").resize((BW, BH), Image.LANCZOS)

# ---- grade: a little richer, a vignette, and a dark wash top left for the title and bottom left for the chips
base = ImageEnhance.Contrast(base).enhance(1.08)
base = ImageEnhance.Color(base).enhance(1.10)
base = ImageEnhance.Brightness(base).enhance(1.06)
wash = Image.new("L", (BW, BH), 0)
wp = wash.load()
cx, cy = BW / 2, BH / 2
for y in range(BH):
    for x in range(BW):
        dx, dy = (x - cx) / cx, (y - cy) / cy
        vig = max(0.0, min(1.0, (math.sqrt(dx * dx * 0.8 + dy * dy) - 0.62) / 0.9)) ** 1.6 * 0.55
        title = max(0.0, 1 - x / 900) * max(0.0, 1 - y / 330) * 0.8
        foot = max(0.0, 1 - x / 760) * max(0.0, (y - 930) / 195) * 0.95
        wp[x, y] = int(min(1.0, vig + title + foot) * 215)
base = Image.composite(Image.new("RGB", (BW, BH), (14, 18, 40)), base, wash)
# the chat line under the chips names another player: painted out
patch = Image.new("L", (BW, BH), 0)
ImageDraw.Draw(patch).rounded_rectangle([30, 1004, 340, 1052], radius=18, fill=255)
base = Image.composite(Image.new("RGB", (BW, BH), (15, 19, 41)), base, patch.filter(ImageFilter.GaussianBlur(6)))

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
    return dd.textlength(s, font=font) / S


def callout(point, pill, label, side="left"):
    """A ringed dot on the thing, a line, and a labelled pill. pill: the pill's top left; side: where the line leaves it."""
    lf = f("segoeuib.ttf", 26)
    tw = d.textlength(label, font=lf) / S
    w, h = tw + 40, 50
    px, py = pill
    start = (px, py + h / 2) if side == "left" else ((px + w, py + h / 2) if side == "right" else
                                                     ((px + w / 2, py) if side == "top" else (px + w / 2, py + h)))
    x, y = point
    d.line([(start[0] * S, start[1] * S), (x * S, y * S)], fill=(255, 255, 255, 235), width=int(3.5 * S))
    d.ellipse([(x - 6) * S, (y - 6) * S, (x + 6) * S, (y + 6) * S], fill=(255, 255, 255, 255))
    d.ellipse([(x - 15) * S, (y - 15) * S, (x + 15) * S, (y + 15) * S], outline=GOLD + (255,), width=int(3.5 * S))
    d.rounded_rectangle([px * S, py * S, (px + w) * S, (py + h) * S], radius=(h / 2) * S, fill=NAVY + (232,),
                        outline=(255, 255, 255, 130), width=2 * S)
    d.text(((px + 20) * S, (py + h / 2) * S), label, font=lf, fill=(255, 255, 255, 255), anchor="lm")


def chip(x, y, label, font, fg=(255, 255, 255, 255), bg=NAVY + (215,), edge=(255, 255, 255, 90), padx=20, h=48):
    tw = d.textlength(label, font=font) / S
    w = tw + padx * 2
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S], radius=(h / 2) * S, fill=bg, outline=edge, width=int(2 * S))
    d.text(((x + padx) * S, (y + h / 2) * S), label, font=font, fill=fg, anchor="lm")
    return w


# ---- what is on the screen
callout((1200, 139), (1262, 176), "TARGET, WHERE YOU LOOK", side="left")
callout((378, 620), (118, 452), "HEALTH AND POWER BESIDE YOU", side="bottom")
callout((1172, 823), (1262, 846), "CAST BARS THAT SHOW THE SPELL", side="left")
callout((826, 962), (392, 880), "STANCE WHEEL ABOVE THE BARS", side="right")
callout((1312, 668), (1440, 720), "NAMEPLATES IN THE SAME LOOK", side="left")

# ---- title block
logo = Image.open(LOGO).convert("RGBA").resize((118 * S, 118 * S), Image.LANCZOS)
ov.alpha_composite(logo, (70 * S, 44 * S))
tf = f("bahnschrift.ttf", 68)
w = text_shadow((208, 40), "ControllerCam", tf, (255, 255, 255, 255), glow=(30, 42, 96, 255), off=4)
text_shadow((208 + w + 18, 40), "HUD", tf, GOLD + (255,), glow=(30, 42, 96, 255), off=4)
text_shadow((212, 122), "The controller interface for the Gamepad UI", f("segoeuib.ttf", 27), (232, 240, 255, 255),
            glow=(24, 34, 84, 255), off=3)
d.rounded_rectangle([74 * S, 176 * S, 330 * S, 183 * S], radius=4 * S, fill=GOLD + (255,))
d.rounded_rectangle([342 * S, 176 * S, 392 * S, 183 * S], radius=4 * S, fill=RED + (255,))

# ---- what else it does, bottom left (over the chat), and where it runs, bottom right
cf = f("segoeuib.ttf", 26)
x = 44
for label in ("Unit frames", "Nameplates", "Cast bar", "Chat", "Vendor"):
    x += chip(x, 1010, label, cf) + 10
chip(44, 1064, "Fades out of combat, wakes on a trigger press", f("segoeui.ttf", 24), bg=NAVY + (170,), h=44)
chip(1560, 1064, "WoW: Forever  ·  Gamepad UI", f("segoeui.ttf", 24), bg=NAVY + (180,), h=44)

ov = ov.resize((BW, BH), Image.LANCZOS)
out = base.convert("RGBA")
out.alpha_composite(ov)
out.convert("RGB").save(OUT, optimize=True)
if OUT.lower().endswith(".png"):
    out.convert("RGB").save(OUT[:-4] + ".jpg", quality=90, optimize=True)
print("saved", OUT, out.size)
