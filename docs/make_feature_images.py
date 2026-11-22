"""Builds the gallery images of single features from in-game screenshots, in the look of hud-image.png: graded,
the logo and a title top left, ringed callouts on the feature, chips of what it does at the bottom. Other players'
names (party frames, chat) are painted out.

    python docs/make_feature_images.py <screenshots folder> docs/logo.png <out folder>
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

SHOTS, LOGO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
S = 2
BW, BH = 2000, 1125
FONTS = r"C:\Windows\Fonts"
NAVY = (24, 34, 78)
RED = (234, 84, 96)
GOLD = (250, 196, 78)
PAINT = (15, 19, 41)

# Each image: the screenshot, title, line under it, callouts (point, pill top left, label, side), chips, and the
# places painted out (other players' names: the party frames on the left, the chat at the bottom left)
PARTY = (60, 420, 290, 615)
CHAT = (38, 830, 630, 1050)
FEATURES = [
    {"file": "WoWScrnShot_112226_115646.jpg", "out": "feature-flights",
     "title": "Flights", "sub": "Your mount glides to where you land",
     "callouts": [((990, 130), (1060, 380), "YOUR MOUNT ON THE WAY", "top"),
                  ((1214, 131), (1250, 175), "LEARNED PER ROUTE", "left"),
                  ((806, 193), (300, 228), "A GAME ON THE WAY", "right")],
     "chips": ["Flights", "Gryphon, wind rider or bat", "A game on the way"],
     "paint": [(4, 38, 345, 68), (60, 412, 290, 660)]},
    {"file": "WoWScrnShot_112226_093310.jpg", "out": "feature-fishing",
     "title": "Fishing", "sub": "One button casts and hooks, your catches beside it",
     "callouts": [((870, 812), (276, 690), "ONE BUTTON CASTS AND HOOKS", "right"),
                  ((1112, 975), (1250, 880), "YOUR FISH, SKILL AND CATCHES", "left")],
     "chips": ["One-button fishing", "Bait on a double press", "Fish journal"],
     "paint": [PARTY, CHAT]},
    {"file": "WoWScrnShot_112226_094844.jpg", "out": "feature-camera",
     "title": "Action camera", "sub": "Roam far out, fight up close over the shoulder",
     "callouts": [((760, 760), (1050, 860), "CLOSE OVER THE SHOULDER IN A FIGHT", "left"),
                  ((1050, 138), (1270, 220), "YOUR TARGET, WHERE YOU LOOK", "left")],
     "chips": ["Camera per situation", "Closer on an enemy", "Controller turning"],
     "paint": [PARTY, CHAT]},
    {"file": "WoWScrnShot_112226_110244.jpg", "out": "feature-fight",
     "title": "In the fight", "sub": "Cooldowns call out as they come back, wounds as it weakens",
     "callouts": [((1352, 578), (1060, 700), "COOLDOWNS CALL OUT AS THEY COME BACK", "top"),
                  ((790, 346), (250, 262), "WOUNDS AS IT WEAKENS", "right")],
     "chips": ["Cooldown callouts", "Big moments", "Hit effects"],
     "paint": [PARTY, CHAT]},
    {"file": "WoWScrnShot_112226_110935.jpg", "out": "feature-control",
     "title": "Crowd control", "sub": "Stuns and roots on your target and its nameplate",
     "callouts": [((1222, 138), (1300, 220), "ON YOUR TARGET", "left"),
                  ((1077, 520), (1200, 440), "AND ON ITS NAMEPLATE", "left")],
     "chips": ["Auras that matter", "Execute glow", "Quest list"],
     "paint": [PARTY, CHAT, (880, 155, 1112, 210)]},
]


def f(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), int(size * S))


def build(spec):
    base = Image.open(os.path.join(SHOTS, spec["file"])).convert("RGB").resize((BW, BH), Image.LANCZOS)
    base = ImageEnhance.Contrast(base).enhance(1.08)
    base = ImageEnhance.Color(base).enhance(1.10)
    base = ImageEnhance.Brightness(base).enhance(1.05)
    wash = Image.new("L", (BW, BH), 0)
    wp = wash.load()
    cx, cy = BW / 2, BH / 2
    for y in range(0, BH):
        for x in range(0, BW):
            dx, dy = (x - cx) / cx, (y - cy) / cy
            vig = max(0.0, min(1.0, (math.sqrt(dx * dx * 0.8 + dy * dy) - 0.62) / 0.9)) ** 1.6 * 0.55
            title = max(0.0, 1 - x / 1000) * max(0.0, 1 - y / 300) * 0.8
            foot = max(0.0, 1 - x / 900) * max(0.0, (y - 930) / 195) * 0.95
            wp[x, y] = int(min(1.0, vig + title + foot) * 215)
    base = Image.composite(Image.new("RGB", (BW, BH), (14, 18, 40)), base, wash)
    patch = Image.new("L", (BW, BH), 0)
    pd = ImageDraw.Draw(patch)
    for box in spec["paint"]:
        pd.rounded_rectangle(box, radius=18, fill=255)
    # blurred past reading and a little darker, so the scene still shows through
    hidden = ImageEnhance.Brightness(base.filter(ImageFilter.GaussianBlur(16))).enhance(0.8)
    base = Image.composite(hidden, base, patch.filter(ImageFilter.GaussianBlur(8)))

    W, H = BW * S, BH * S
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)

    def text_shadow(xy, s, font, fill, glow=(14, 20, 46, 255), off=3):
        x, y = xy
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((x * S + off * S, y * S + off * S), s, font=font, fill=(10, 14, 34, 200))
        ov.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5 * S)))
        dd = ImageDraw.Draw(ov)
        dd.text((x * S, y * S), s, font=font, fill=fill, stroke_width=int(2 * S), stroke_fill=glow)
        dd.text((x * S, y * S), s, font=font, fill=fill)
        return dd.textlength(s, font=font) / S

    def callout(point, pill, label, side):
        dd = ImageDraw.Draw(ov)
        lf = f("segoeuib.ttf", 26)
        w, h = dd.textlength(label, font=lf) / S + 40, 50
        px, py = pill
        start = {"left": (px, py + h / 2), "right": (px + w, py + h / 2), "top": (px + w / 2, py),
                 "bottom": (px + w / 2, py + h)}[side]
        x, y = point
        dd.line([(start[0] * S, start[1] * S), (x * S, y * S)], fill=(255, 255, 255, 235), width=int(3.5 * S))
        dd.ellipse([(x - 6) * S, (y - 6) * S, (x + 6) * S, (y + 6) * S], fill=(255, 255, 255, 255))
        dd.ellipse([(x - 15) * S, (y - 15) * S, (x + 15) * S, (y + 15) * S], outline=GOLD + (255,), width=int(3.5 * S))
        dd.rounded_rectangle([px * S, py * S, (px + w) * S, (py + h) * S], radius=(h / 2) * S, fill=NAVY + (232,),
                             outline=(255, 255, 255, 130), width=2 * S)
        dd.text(((px + 20) * S, (py + h / 2) * S), label, font=lf, fill=(255, 255, 255, 255), anchor="lm")

    def chip(x, y, label, font, bg=NAVY + (215,), h=48):
        dd = ImageDraw.Draw(ov)
        w = dd.textlength(label, font=font) / S + 40
        dd.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S], radius=(h / 2) * S, fill=bg,
                             outline=(255, 255, 255, 90), width=int(2 * S))
        dd.text(((x + 20) * S, (y + h / 2) * S), label, font=font, fill=(255, 255, 255, 255), anchor="lm")
        return w

    for c in spec["callouts"]:
        callout(*c)
    logo = Image.open(LOGO).convert("RGBA").resize((118 * S, 118 * S), Image.LANCZOS)
    ov.alpha_composite(logo, (70 * S, 44 * S))
    tf = f("bahnschrift.ttf", 68)
    text_shadow((208, 40), spec["title"], tf, (255, 255, 255, 255), glow=(30, 42, 96, 255), off=4)
    text_shadow((212, 122), spec["sub"], f("segoeuib.ttf", 27), (232, 240, 255, 255), glow=(24, 34, 84, 255))
    d = ImageDraw.Draw(ov)
    d.rounded_rectangle([74 * S, 176 * S, 330 * S, 183 * S], radius=4 * S, fill=GOLD + (255,))
    d.rounded_rectangle([342 * S, 176 * S, 392 * S, 183 * S], radius=4 * S, fill=RED + (255,))
    cf = f("segoeuib.ttf", 26)
    x = 44
    for label in spec["chips"]:
        x += chip(x, 1010, label, cf) + 10
    chip(44, 1064, "ControllerCam + HUD for Gamepad", f("segoeui.ttf", 24), bg=NAVY + (170,), h=44)
    chip(1560, 1064, "WoW: Forever  ·  Gamepad UI", f("segoeui.ttf", 24), bg=NAVY + (180,), h=44)

    ov = ov.resize((BW, BH), Image.LANCZOS)
    out = base.convert("RGBA")
    out.alpha_composite(ov)
    path = os.path.join(OUT, spec["out"] + ".jpg")
    out.convert("RGB").save(path, quality=90, optimize=True)
    print("saved", path)


for spec in FEATURES:
    build(spec)
