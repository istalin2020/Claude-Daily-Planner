"""The hero App Store screenshot: headline, five features down the left, the
landing page on a tilted iPhone, and a banner along the bottom.

Usage: python hero.py <landing_screenshot> <out_dir>
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from make_shots import phone, font, SIZES

SHOT, OUT_DIR = sys.argv[1], sys.argv[2]

NAVY = (14, 30, 91)
FEATURES = [
    ("Stay Organized", "Tasks, priorities and\nlists in one place.", (40, 110, 245), "list"),
    ("Stay Healthy", "Steps, water, meals,\nsleep and habits.", (240, 70, 110), "heart"),
    ("Manage Finances", "Track spending and see\nwhere it goes.", (30, 175, 100), "dollar"),
    ("Plan Your Day", "Schedule, appointments\nand renewals.", (120, 80, 235), "calendar"),
    ("Capture Thoughts", "Notes, prompts and\ndaily reflection.", (245, 150, 30), "pencil"),
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(W, H, stops=None, sparkles=None):
    stops = stops or [(0.0, (226, 236, 255)), (0.22, (170, 198, 252)), (0.45, (74, 124, 236)),
             (0.75, (34, 76, 196)), (1.0, (16, 38, 120))]
    col = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                col.putpixel((0, y), lerp(c0, c1, (t - t0) / (t1 - t0)))
                break
    bg = col.resize((W, H)).convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse([0.35 * W, -0.10 * H, 1.25 * W, 0.32 * H], fill=(255, 255, 255, 120))
    g.ellipse([-0.4 * W, 0.55 * H, 0.5 * W, 0.95 * H], fill=(120, 170, 255, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.12))
    bg = Image.alpha_composite(bg, glow)
    d = ImageDraw.Draw(bg)
    for (x, y, r, a) in sparkles if sparkles is not None else [(0.83, 0.115, 0.022, 230), (0.91, 0.085, 0.012, 200), (0.94, 0.17, 0.010, 170),
                         (0.30, 0.255, 0.012, 150), (0.07, 0.42, 0.008, 120), (0.88, 0.30, 0.008, 140)]:
        sparkle(d, x * W, y * H, r * W, a)
    return bg


def sparkle(d, cx, cy, r, alpha):
    """A four-point star."""
    k = r * 0.22
    d.polygon([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k),
               (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)],
              fill=(255, 255, 255, alpha))


def icon(kind, size, color):
    """A coloured circle with a simple white glyph."""
    s = size * 4
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, s - 1, s - 1], fill=color + (255,))
    w = (255, 255, 255, 255)
    lw = int(s * 0.07)
    if kind == "list":
        for i, y in enumerate([0.38, 0.62]):
            cy = s * y
            d.ellipse([s * 0.25, cy - s * 0.07, s * 0.39, cy + s * 0.07], outline=w, width=lw)
            d.rounded_rectangle([s * 0.46, cy - lw / 2, s * 0.76, cy + lw / 2], lw / 2, fill=w)
    elif kind == "heart":
        r = s * 0.13
        d.ellipse([s * 0.5 - 2 * r, s * 0.32, s * 0.5, s * 0.32 + 2 * r], fill=w)
        d.ellipse([s * 0.5, s * 0.32, s * 0.5 + 2 * r, s * 0.32 + 2 * r], fill=w)
        d.polygon([(s * 0.5 - 2 * r + s * 0.01, s * 0.32 + r * 1.3), (s * 0.5 + 2 * r - s * 0.01, s * 0.32 + r * 1.3),
                   (s * 0.5, s * 0.74)], fill=w)
    elif kind == "dollar":
        d.text((s / 2, s / 2), "$", font=font("Inter-ExtraBold.otf", s * 0.52), fill=w, anchor="mm")
    elif kind == "calendar":
        d.rounded_rectangle([s * 0.26, s * 0.28, s * 0.74, s * 0.72], s * 0.07, outline=w, width=lw)
        d.rectangle([s * 0.26, s * 0.28, s * 0.74, s * 0.40], fill=w)
        for row in range(2):
            for c in range(3):
                x, y = s * (0.34 + c * 0.12), s * (0.49 + row * 0.11)
                d.rectangle([x, y, x + s * 0.06, y + s * 0.05], fill=w)
    elif kind == "pencil":
        body = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        b = ImageDraw.Draw(body)
        b.rounded_rectangle([s * 0.44, s * 0.18, s * 0.56, s * 0.66], s * 0.02, fill=w)
        b.polygon([(s * 0.44, s * 0.69), (s * 0.56, s * 0.69), (s * 0.5, s * 0.82)], fill=w)
        body = body.rotate(-40, resample=Image.BICUBIC, center=(s / 2, s / 2))
        im.alpha_composite(body)
    return im.resize((size, size), Image.LANCZOS)


def laurel(height, flip=False):
    """A laurel branch: a curved stem with leaves on its outer side."""
    S = 4
    w, h = int(height * 0.55) * S, height * S
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Stem: an arc bowing to the left, from bottom-right up to top.
    cx, cy, r = w * 1.05, h * 0.52, h * 0.47
    d.arc([cx - r, cy - r, cx + r, cy + r], 128, 232, fill=(255, 255, 255, 240), width=int(h * 0.018))
    lw, lh = int(h * 0.085), int(h * 0.20)
    leaf = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    ImageDraw.Draw(leaf).ellipse([0, 0, lw - 1, lh - 1], fill=(255, 255, 255, 240))
    for i in range(7):
        ang = 132 + i * 15                      # along the stem, bottom to top
        a = math.radians(ang)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        # Leaf points outward-upward from the stem.
        rot = leaf.rotate((180 - ang) + 38, expand=True, resample=Image.BICUBIC)
        ox = x + math.cos(a) * lh * 0.30
        oy = y + math.sin(a) * lh * 0.30 - lh * 0.22
        im.alpha_composite(rot, (int(ox - rot.size[0] / 2), int(oy - rot.size[1] / 2)))
    im = im.resize((w // S, h // S), Image.LANCZOS)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def compose(W, H):
    img = background(W, H)
    d = ImageDraw.Draw(img)
    x0 = W * 0.075

    # Headline
    fh = font("InterDisplay-Bold.otf", W * 0.118)
    d.text((x0, H * 0.045), "Plan. Track.", font=fh, fill=NAVY)
    d.text((x0, H * 0.045 + W * 0.125), "Achieve.", font=fh, fill=NAVY)
    fs = font("Inter-Medium.otf", W * 0.043)
    ys = H * 0.045 + W * 0.27
    d.text((x0, ys), "Your all-in-one daily", font=fs, fill=(22, 34, 80))
    part = "planner for a "
    d.text((x0, ys + W * 0.058), part, font=fs, fill=(22, 34, 80))
    fb = font("Inter-Bold.otf", W * 0.043)
    d.text((x0 + d.textlength(part, font=fs), ys + W * 0.058), "better you.", font=fb, fill=(31, 100, 245))

    # Phone with the landing page, tilted slightly, on the right
    shot = Image.open(SHOT).convert("RGB")
    sw = int(W * 0.50)
    ph = phone(shot, sw).rotate(3, expand=True, resample=Image.BICUBIC)
    px, py = int(W * 0.975 - ph.size[0]), int(H * 0.262)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((5, 15, 60, 255), (px + int(W * 0.02), py + int(W * 0.035)),
                 ph.split()[3].point(lambda v: 110 if v > 0 else 0))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(W * 0.03)))
    img.alpha_composite(ph, (px, py))
    d = ImageDraw.Draw(img)

    # Features down the left: icon, title, two-line description, divider.
    isz = int(W * 0.074)
    ft = font("Inter-Bold.otf", W * 0.034)
    fd = font("Inter-Medium.otf", W * 0.0255)
    y = H * 0.300
    step = H * 0.112
    for i, (title, desc, color, kind) in enumerate(FEATURES):
        pad = int(isz * 0.45)
        halo = Image.new("RGBA", (isz + 2 * pad, isz + 2 * pad), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([pad * 0.6, pad * 0.6, isz + pad * 1.4, isz + pad * 1.4], fill=color + (110,))
        img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(pad * 0.35)), (int(x0 - pad), int(y - pad + 4)))
        img.alpha_composite(icon(kind, isz, color), (int(x0), int(y)))
        d = ImageDraw.Draw(img)
        ty = y + isz + W * 0.016
        d.text((x0, ty), title, font=ft, fill=(255, 255, 255))
        dy = ty + W * 0.048
        for line in desc.split("\n"):
            d.text((x0, dy), line, font=fd, fill=(225, 234, 255))
            dy += W * 0.034
        if i < len(FEATURES) - 1:
            ly = dy + (y + step - dy) * 0.45
            d.line([(x0, ly), (x0 + W * 0.15, ly)], fill=(255, 255, 255, 80), width=2)
        y += step

    # Bottom banner
    by = H * 0.885
    band = Image.new("RGBA", (W, H - int(by)), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.ellipse([-0.2 * W, 0, 1.2 * W, 2.4 * band.size[1]], fill=(12, 28, 92, 235))
    img.alpha_composite(band.filter(ImageFilter.GaussianBlur(6)), (0, int(by)))
    d = ImageDraw.Draw(img)
    fbn = font("Inter-Bold.otf", W * 0.050)
    a, b = "All You Need. In ", "One Place."
    total = d.textlength(a, font=fbn) + d.textlength(b, font=fbn)
    tx = (W - total) / 2
    ty = H * 0.918
    d.text((tx, ty), a, font=fbn, fill=(255, 255, 255))
    d.text((tx + d.textlength(a, font=fbn), ty), b, font=fbn, fill=(120, 175, 255))
    d.text((W / 2, ty + W * 0.078), "Plan better. Do more. Live healthier.",
           font=font("Inter-Medium.otf", W * 0.033), fill=(225, 234, 255), anchor="mt")
    lh = int(W * 0.15)
    img.alpha_composite(laurel(lh), (int(tx - lh * 0.62), int(ty - lh * 0.12)))
    img.alpha_composite(laurel(lh, flip=True), (int(tx + total + lh * 0.02), int(ty - lh * 0.12)))
    return img.convert("RGB")


if __name__ == "__main__":
  os.makedirs(OUT_DIR, exist_ok=True)
  for label, (W, H) in SIZES.items():
    out = compose(W, H)
    assert out.size == (W, H) and out.mode == "RGB"
    path = os.path.join(OUT_DIR, f"{label}_00.png")
    out.save(path, "PNG", optimize=True)
    print(path, out.size)
