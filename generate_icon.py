#!/usr/bin/env python3
"""
Daily Planner App Icon Generator
Design: "Cosmic Planner" — a glowing central orb surrounded by
orbiting colour-coded planet dots (one per app section) on a
deep-space purple gradient, with a bold checkmark at the core.
"""

import math, numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE   = 1024
CX, CY = SIZE // 2, SIZE // 2

# ─────────────────────────────────────────────────────────────────────────────
# 1.  BACKGROUND  — deep-space radial gradient
# ─────────────────────────────────────────────────────────────────────────────
yy, xx = np.mgrid[0:SIZE, 0:SIZE]
dist    = np.sqrt((xx - CX) ** 2 + (yy - CY) ** 2)
max_d   = math.hypot(CX, CY)
t       = np.clip(dist / max_d, 0.0, 1.0)

R = (72  * (1 - t) + 10 * t).astype(np.uint8)
G = (28  * (1 - t) +  4 * t).astype(np.uint8)
B = (180 * (1 - t) + 28 * t).astype(np.uint8)

img = Image.fromarray(np.stack([R, G, B], axis=2), 'RGB').convert('RGBA')

# ─────────────────────────────────────────────────────────────────────────────
# 2.  STAR-FIELD  — tiny white dots at varying opacity
# ─────────────────────────────────────────────────────────────────────────────
rng = np.random.default_rng(7)
stars = rng.integers(0, SIZE, size=(180, 2))
s_r   = rng.choice([1, 2, 3], size=180, p=[0.60, 0.30, 0.10])
s_a   = rng.integers(80, 210, size=180)

star_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(star_layer)
for (sy, sx), sr, sa in zip(stars, s_r, s_a):
    sd.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(255, 255, 255, sa))
img = Image.alpha_composite(img, star_layer)

# ─────────────────────────────────────────────────────────────────────────────
# 3.  ORBIT RING  — faint dashed circle
# ─────────────────────────────────────────────────────────────────────────────
ORBIT_R = 320
orbit_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
od = ImageDraw.Draw(orbit_layer)
od.ellipse([CX - ORBIT_R, CY - ORBIT_R, CX + ORBIT_R, CY + ORBIT_R],
           outline=(255, 255, 255, 35), width=2)
img = Image.alpha_composite(img, orbit_layer)

# ─────────────────────────────────────────────────────────────────────────────
# 4.  PLANET DOTS  — one per app section, evenly spaced on the orbit ring
# ─────────────────────────────────────────────────────────────────────────────
PLANETS = [
    ((255, 140,   0), 32),  # Top Priorities  — orange
    (( 38, 200,  90), 28),  # Calls & Emails  — green
    (( 60, 130, 255), 30),  # Personal To-Do  — blue
    ((230,  51,  77), 26),  # Health          — red
    (( 13, 190, 255), 32),  # Water           — cyan
    ((245, 185,  25), 26),  # Food            — gold
    ((100,  78, 220), 28),  # Schedule        — indigo
    (( 20, 170, 185), 24),  # Appointments    — teal
    ((230,  75, 145), 30),  # Rate Your Day   — pink
]

n = len(PLANETS)
for i, (color, pr) in enumerate(PLANETS):
    angle = math.radians(-90 + (360 / n) * i)
    px = int(CX + ORBIT_R * math.cos(angle))
    py = int(CY + ORBIT_R * math.sin(angle))

    # Soft glow
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd   = ImageDraw.Draw(glow)
    for gr, ga in [(pr + 22, 35), (pr + 12, 60)]:
        gd.ellipse([px - gr, py - gr, px + gr, py + gr], fill=(*color, ga))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=10))
    img  = Image.alpha_composite(img, glow)

    # Planet body
    pl_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    pd       = ImageDraw.Draw(pl_layer)
    pd.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(*color, 255))
    # specular highlight
    hw = max(4, pr // 3)
    pd.ellipse([px - hw, py - pr + 4, px + hw // 2, py - pr // 2],
               fill=(255, 255, 255, 130))
    img = Image.alpha_composite(img, pl_layer)

draw = ImageDraw.Draw(img)

# ─────────────────────────────────────────────────────────────────────────────
# 5.  CENTRAL SUN / ORB  — radial gradient + outer glow
# ─────────────────────────────────────────────────────────────────────────────
SUN_R = 175

# Multi-pass glow
sun_glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
sg = ImageDraw.Draw(sun_glow)
for gr, ga in [(SUN_R + 90, 25), (SUN_R + 60, 40), (SUN_R + 35, 55), (SUN_R + 18, 70)]:
    sg.ellipse([CX - gr, CY - gr, CX + gr, CY + gr], fill=(190, 140, 255, ga))
sun_glow = sun_glow.filter(ImageFilter.GaussianBlur(radius=30))
img = Image.alpha_composite(img, sun_glow)

# Orb body via numpy
yy2, xx2 = np.mgrid[0:SIZE, 0:SIZE]
d2        = np.sqrt((xx2 - CX) ** 2 + (yy2 - CY) ** 2)
ts        = np.clip(d2 / SUN_R, 0.0, 1.0)
in_sun    = d2 <= SUN_R

orb_arr       = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
orb_arr[..., 0] = np.where(in_sun, (255 * (1 - ts) + 150 * ts).astype(np.uint8), 0)
orb_arr[..., 1] = np.where(in_sun, (248 * (1 - ts) +  70 * ts).astype(np.uint8), 0)
orb_arr[..., 2] = np.where(in_sun, (230 * (1 - ts) + 240 * ts).astype(np.uint8), 0)
orb_arr[..., 3] = np.where(in_sun, 255, 0)

img = Image.alpha_composite(img, Image.fromarray(orb_arr, 'RGBA'))

# ─────────────────────────────────────────────────────────────────────────────
# 6.  CALENDAR GRID  — subtle lines in the lower half of the orb
# ─────────────────────────────────────────────────────────────────────────────
grid_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
gld        = ImageDraw.Draw(grid_layer)

GRID_COLOR = (80, 30, 160, 55)
step = 38

# Horizontal lines
for row in range(CY - SUN_R + 20, CY + SUN_R, step):
    # Clip to circle
    dy = row - CY
    if abs(dy) > SUN_R:
        continue
    dx = int(math.sqrt(SUN_R ** 2 - dy ** 2)) - 12
    gld.line([(CX - dx, row), (CX + dx, row)], fill=GRID_COLOR, width=1)

# Vertical lines
for col in range(CX - SUN_R + 20, CX + SUN_R, step):
    dx = col - CX
    if abs(dx) > SUN_R:
        continue
    dy = int(math.sqrt(SUN_R ** 2 - dx ** 2)) - 12
    gld.line([(col, CY - dy), (col, CY + dy)], fill=GRID_COLOR, width=1)

img = Image.alpha_composite(img, grid_layer)
draw = ImageDraw.Draw(img)

# ─────────────────────────────────────────────────────────────────────────────
# 7.  INNER PURPLE DISC  — sits on top of the orb, under the checkmark
# ─────────────────────────────────────────────────────────────────────────────
DISC_R = 110
disc_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
dd = ImageDraw.Draw(disc_layer)
dd.ellipse([CX - DISC_R, CY - DISC_R, CX + DISC_R, CY + DISC_R],
           fill=(80, 30, 180, 230))
img = Image.alpha_composite(img, disc_layer)
draw = ImageDraw.Draw(img)

# ─────────────────────────────────────────────────────────────────────────────
# 8.  CHECKMARK  — bold white, centred on the disc
# ─────────────────────────────────────────────────────────────────────────────
LW    = 20                    # line width
WHITE = (255, 255, 255, 255)

# Pivot point for the check-mark
px1, py1 = CX - 52, CY + 8   # left tip
px2, py2 = CX - 16, CY + 50  # bottom valley
px3, py3 = CX + 60, CY - 50  # right tip

# Draw twice for nice rounded caps (draw thick then thin overlay)
draw.line([(px1, py1), (px2, py2)], fill=WHITE, width=LW)
draw.line([(px2, py2), (px3, py3)], fill=WHITE, width=LW)

# ─────────────────────────────────────────────────────────────────────────────
# 9.  SAVE
# ─────────────────────────────────────────────────────────────────────────────
OUT = "DailyPlanner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
img.convert('RGB').save(OUT, format='PNG', optimize=True)
print(f"✓ Icon saved → {OUT}  ({SIZE}x{SIZE}px)")
