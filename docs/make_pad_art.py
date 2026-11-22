"""Draws the controller button icons the HUD writes into its own prompts (32-bit TGA, 64x64) with Pillow: a disc
with the button's mark, by the kind of controller. The letters and shapes are drawn from strokes here, no font.

    python docs/make_pad_art.py ControllerCam_HUD/Media

  pad_steam_<a|b|x|y>   white letters on a black disc (the Steam Controller's own look)
  pad_xbox_<a|b|x|y>    the letters in their colours (green A, red B, blue X, yellow Y) on a dark disc
  pad_ps_<cross|circle|square|triangle>   the shapes in their colours on a dark disc
"""
import math
import os
import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
N, S = 64, 4                 # size, supersampling
W = N * S


def disc(fill, rim):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 2 * S
    d.ellipse([pad, pad, W - pad, W - pad], fill=rim)
    inner = pad + 3 * S
    d.ellipse([inner, inner, W - inner, W - inner], fill=fill)
    return img, d


def line(d, pts, color, width):
    pts = [(x * W, y * W) for x, y in pts]
    d.line(pts, fill=color, width=int(width * S), joint="curve")
    r = width * S / 2
    for x, y in pts:                                   # round ends
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


STROKE = 6.5
LETTERS = {
    "a": [[(0.32, 0.72), (0.50, 0.28), (0.68, 0.72)], [(0.39, 0.57), (0.61, 0.57)]],
    "x": [[(0.33, 0.30), (0.67, 0.70)], [(0.67, 0.30), (0.33, 0.70)]],
    "y": [[(0.33, 0.29), (0.50, 0.50)], [(0.67, 0.29), (0.50, 0.50)], [(0.50, 0.50), (0.50, 0.71)]],
}


def letter(d, which, color):
    if which == "b":                                   # a stem and two bowls
        line(d, [(0.37, 0.28), (0.37, 0.72)], color, STROKE)
        for top, bottom, reach in ((0.28, 0.50, 0.60), (0.50, 0.72, 0.64)):
            mid = (top + bottom) / 2
            rad = (bottom - top) / 2
            pts = [(0.37, top)]
            for i in range(0, 13):
                a = -math.pi / 2 + math.pi * i / 12
                pts.append((reach - rad + rad * math.cos(a) * 1.15, mid + rad * math.sin(a)))
            pts.append((0.37, bottom))
            line(d, pts, color, STROKE)
        return
    for stroke in LETTERS[which]:
        line(d, stroke, color, STROKE)


def shape(d, which, color):
    if which == "cross":
        line(d, [(0.33, 0.33), (0.67, 0.67)], color, 6)
        line(d, [(0.67, 0.33), (0.33, 0.67)], color, 6)
    elif which == "circle":
        r = 0.19 * W
        c = W / 2
        d.ellipse([c - r, c - r, c + r, c + r], outline=color, width=int(6 * S))
    elif which == "square":
        a, b = 0.33 * W, 0.67 * W
        d.rectangle([a, a, b, b], outline=color, width=int(6 * S))
    elif which == "triangle":
        pts = [(0.50, 0.30), (0.70, 0.66), (0.30, 0.66), (0.50, 0.30)]
        line(d, pts, color, 5.5)


def save(img, name):
    img.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, "pad_" + name + ".tga"))
    print(name)


BLACK, RIM = (12, 12, 14, 255), (150, 150, 160, 255)
DARK, DRIM = (22, 24, 30, 255), (95, 100, 115, 255)
for k in "abxy":
    img, d = disc(BLACK, RIM)
    letter(d, k, (250, 250, 250, 255))
    save(img, "steam_" + k)
XBOX = {"a": (108, 194, 74, 255), "b": (226, 69, 60, 255), "x": (47, 134, 246, 255), "y": (244, 196, 48, 255)}
for k, color in XBOX.items():
    img, d = disc(DARK, DRIM)
    letter(d, k, color)
    save(img, "xbox_" + k)
PS = {"cross": (125, 166, 232, 255), "circle": (232, 106, 106, 255), "square": (211, 139, 200, 255),
      "triangle": (95, 201, 163, 255)}
for k, color in PS.items():
    img, d = disc(DARK, DRIM)
    shape(d, k, color)
    save(img, "ps_" + k)
