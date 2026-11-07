"""App Store screenshots: app screen in an iPhone frame under a caption.

Usage: python make_shots.py <images_dir> <out_dir>
"""
import sys, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

IMG_DIR, OUT_DIR = sys.argv[1], sys.argv[2]
FONT = "/usr/share/fonts/opentype/inter/"
def font(name, size): return ImageFont.truetype(FONT + name, int(size))

SLIDES = [
    ("7.webp",  "YOUR DAY, ORGANISED", "Everything that matters,\nat a glance",
     "Tasks, health, money and plans in one calm view", (61, 120, 255), (150, 110, 255)),
    ("16.webp", "HEALTH TRACKER", "Small habits,\na healthier you",
     "Steps, water, meals, sleep, medicines and habits", (240, 80, 130), (150, 110, 255)),
    ("13.webp", "FOOD TRACKER", "Eat smart,\nstay strong",
     "Snap a meal and see calories, protein and more", (245, 140, 30), (240, 80, 130)),
    ("12.webp", "FINANCE TRACKER", "Know where your\nmoney goes",
     "Income, expenses and balance, month by month", (30, 170, 100), (61, 120, 255)),
    ("15.webp", "SUBSCRIPTIONS", "Never miss\na renewal",
     "Every subscription found from Gmail and sorted", (120, 80, 235), (245, 140, 30)),
    ("8.webp",  "TO-DO LIST", "Plan it. Do it.\nTick it off.",
     "Priorities, lists, calls and personal to-dos, sorted", (40, 120, 245), (40, 190, 210)),
    ("14.webp", "NOTES & JOURNAL", "Reflect on\nwhat matters",
     "Rate your day and capture its best moments", (240, 70, 120), (250, 150, 60)),
    ("10.webp", "HEALTH & FITNESS", "Every step\nmoves you forward",
     "Syncs with Apple Health for workouts and goals", (235, 70, 110), (250, 150, 60)),
]

SIZES = {"6.1in_1206x2622": (1206, 2622), "6.9in_1320x2868": (1320, 2868)}


def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], r, fill=255)
    return m


def background(W, H, a, b):
    top, bot = (232, 240, 255), (246, 243, 255)
    col = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / H
        col.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    bg = col.resize((W, H))
    # soft colour glows
    # Soft colour glows painted over the page colour itself, so the edges
    # blend into the gradient instead of greying out.
    glow = bg.copy()
    g = ImageDraw.Draw(glow)
    g.ellipse([-0.35 * W, -0.10 * H, 0.65 * W, 0.40 * H], fill=a)
    g.ellipse([0.45 * W, 0.30 * H, 1.40 * W, 0.85 * H], fill=b)
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.18))
    return Image.blend(bg, glow, 0.28)


def clean_status_bar(shot):
    """Replaces the captured status bar with a tidy 9:41, full-signal one."""
    w, h = shot.size
    bar = int(h * 0.056)
    px = shot.load()
    for y in range(bar):
        l, r = px[4, y], px[w - 5, y]
        for x in range(w):
            t = x / (w - 1)
            px[x, y] = tuple(int(l[i] + (r[i] - l[i]) * t) for i in range(3))
    d = ImageDraw.Draw(shot)
    cy = h * 0.034
    f = font("Inter-SemiBold.otf", h * 0.0215)
    d.text((w * 0.205, cy), "9:41", font=f, fill=(0, 0, 0), anchor="mm")
    # signal bars
    x0, base, bw = w * 0.685, cy + h * 0.008, w * 0.0095
    for i in range(4):
        bh = h * (0.0045 + 0.0028 * i)
        d.rounded_rectangle([x0 + i * bw * 1.55, base - bh, x0 + i * bw * 1.55 + bw, base], bw * 0.3, fill=(0, 0, 0))
    # wifi
    wx, wy = w * 0.785, cy + h * 0.007
    for k, rr in enumerate([h * 0.0115, h * 0.0078, h * 0.0041]):
        d.pieslice([wx - rr, wy - rr, wx + rr, wy + rr], 225, 315, fill=(0, 0, 0) if k % 2 == 0 else None)
        if k % 2 == 1:
            d.pieslice([wx - rr, wy - rr, wx + rr, wy + rr], 225, 315, fill=tuple(px[int(wx), int(cy)]))
    # battery
    bx, by, bwid, bht = w * 0.835, cy - h * 0.0072, w * 0.062, h * 0.0144
    d.rounded_rectangle([bx, by, bx + bwid, by + bht], bht * 0.3, outline=(0, 0, 0), width=max(2, int(h * 0.0012)))
    inset = h * 0.0024
    d.rounded_rectangle([bx + inset, by + inset, bx + bwid - inset, by + bht - inset], bht * 0.22, fill=(0, 0, 0))
    d.rounded_rectangle([bx + bwid + h * 0.001, cy - h * 0.0028, bx + bwid + h * 0.0035, cy + h * 0.0028], 2, fill=(0, 0, 0))
    return shot


def phone(shot, sw):
    """The screenshot inside an iPhone body with a Dynamic Island."""
    sh = int(sw * shot.size[1] / shot.size[0])
    screen = shot.resize((sw, sh), Image.LANCZOS)
    screen = clean_status_bar(screen)
    bezel = int(sw * 0.034)
    frame_w, frame_h = sw + 2 * bezel, sh + 2 * bezel
    r_out, r_in = int(frame_w * 0.155), int(sw * 0.135)
    pad = int(sw * 0.03)                      # room for side buttons and shadow
    canvas = Image.new("RGBA", (frame_w + 2 * pad, frame_h + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    ox, oy = pad, pad
    # side buttons
    btn = (60, 62, 68, 255)
    bwid = int(sw * 0.012)
    for (yy, hh) in [(0.19, 0.045), (0.255, 0.075), (0.345, 0.075)]:
        d.rounded_rectangle([ox - bwid, oy + frame_h * yy, ox + 4, oy + frame_h * (yy + hh)], bwid, fill=btn)
    d.rounded_rectangle([ox + frame_w - 4, oy + frame_h * 0.27, ox + frame_w + bwid, oy + frame_h * 0.37], bwid, fill=btn)
    # titanium edge and black body
    d.rounded_rectangle([ox, oy, ox + frame_w, oy + frame_h], r_out, fill=(118, 121, 130, 255))
    e = int(sw * 0.006)
    d.rounded_rectangle([ox + e, oy + e, ox + frame_w - e, oy + frame_h - e], r_out - e, fill=(12, 12, 14, 255))
    # screen
    canvas.paste(screen, (ox + bezel, oy + bezel), rounded_mask((sw, sh), r_in))
    # dynamic island
    iw, ih = sw * 0.29, sh * 0.0175 * 2.1
    ix, iy = ox + bezel + (sw - iw) / 2, oy + bezel + sh * 0.0118
    d.rounded_rectangle([ix, iy, ix + iw, iy + ih], ih / 2, fill=(0, 0, 0, 255))
    return canvas


def compose(slide, W, H):
    fname, eyebrow, title, sub, a, b = slide
    img = background(W, H, a, b)
    d = ImageDraw.Draw(img)
    # caption
    y = H * 0.052
    fe = font("Inter-Bold.otf", W * 0.030)
    d.text((W / 2, y), "  ".join(eyebrow) if False else eyebrow, font=fe, fill=a, anchor="mt")
    y += W * 0.062
    ft = font("InterDisplay-Bold.otf", W * 0.081)
    for line in title.split("\n"):
        d.text((W / 2, y), line, font=ft, fill=(18, 20, 33), anchor="mt")
        y += W * 0.094
    y += W * 0.012
    fs = font("Inter-Medium.otf", W * 0.034)
    words, line, lines = sub.split(), "", []
    for wd in words:
        test = (line + " " + wd).strip()
        if d.textlength(test, font=fs) > W * 0.88 and line:
            lines.append(line); line = wd
        else:
            line = test
    lines.append(line)
    for ln in lines:
        d.text((W / 2, y), ln, font=fs, fill=(92, 98, 118), anchor="mt")
        y += W * 0.050
    # phone, sized to the space left
    top = y + H * 0.025
    avail_h = H - top - H * 0.035
    shot = Image.open(os.path.join(IMG_DIR, fname)).convert("RGB")
    ratio = shot.size[1] / shot.size[0]
    sw = int(min(W * 0.70, (avail_h / 1.075) / ratio))
    ph = phone(shot, sw)
    # soft shadow
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sx, sy = int((W - ph.size[0]) / 2), int(top)
    alpha = ph.split()[3].point(lambda v: 70 if v > 0 else 0)
    shadow.paste((40, 40, 80, 255), (sx, sy + int(W * 0.025)), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(W * 0.03))
    base = img.convert("RGBA")
    base = Image.alpha_composite(base, shadow)
    base.alpha_composite(ph, (sx, sy))
    return base.convert("RGB")          # App Store: no alpha channel


os.makedirs(OUT_DIR, exist_ok=True)
for label, (W, H) in SIZES.items():
    for i, slide in enumerate(SLIDES, 1):
        out = compose(slide, W, H)
        assert out.size == (W, H) and out.mode == "RGB"
        path = os.path.join(OUT_DIR, f"{label}_{i:02d}.png")
        out.save(path, "PNG", optimize=True)
        print(path, out.size, out.mode)
