"""iPad 13" App Store screenshots (2064x2752): caption and highlights on the
left, the app screen as a rounded card on the right. No device frame, so the
iPad set never shows an iPhone.

Usage: python ipad.py <images_dir> <out_dir>
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from make_shots import font, background, clean_status_bar, rounded_mask, SLIDES
import hero

IMG, OUT = sys.argv[1], sys.argv[2]
W, H = 2064, 2752
NAVY = (14, 30, 91)

POINTS = {
    "20.webp": ["Tasks, health, money and plans", "Today's progress at a glance", "Tap any tile to dive in"],
    "16.webp": ["Steps from Apple Health", "Tap a glass to log water", "Sleep, medicines and habits"],
    "13.webp": ["Snap a photo of your meal", "Calories, protein, carbs and fat", "Breakfast, lunch, dinner, snacks"],
    "12.webp": ["Income, expenses and balance", "Add an expense in seconds", "Spending trends by month"],
    "17.webp": ["Time blocks in time order", "Appointments with reminder tones", "Upcoming renewals"],
    "15.webp": ["Found automatically from Gmail", "Renewal dates and amounts", "Monthly total at a glance"],
    "18.webp": ["Top priorities first", "To-do lists and personal tasks", "Add tasks with Siri"],
    "14.webp": ["Rate your day with stars", "Notes for today", "Writing prompts to get started"],
    "19.webp": ["Workouts, steps and calories", "Syncs with Apple Health", "Daily goals and rings"],
}


def wrap(d, text, f, width):
    out = []
    for para in text.split("\n"):
        line = ""
        for w in para.split():
            t = (line + " " + w).strip()
            if d.textlength(t, font=f) > width and line:
                out.append(line); line = w
            else:
                line = t
        out.append(line)
    return out


def card(name, ch):
    """The app screen as a rounded card with a thin white rim."""
    shot = Image.open(os.path.join(IMG, name)).convert("RGB")
    cw = int(ch * shot.size[0] / shot.size[1])
    shot = clean_status_bar(shot.resize((cw, ch), Image.LANCZOS))
    rim = int(cw * 0.012)
    r = int(cw * 0.085)
    c = Image.new("RGBA", (cw + 2 * rim, ch + 2 * rim), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle([0, 0, c.size[0] - 1, c.size[1] - 1], r + rim, fill=(255, 255, 255, 255))
    c.paste(shot, (rim, rim), rounded_mask((cw, ch), r))
    return c


def place_with_shadow(img, layer, x, y, colour=(40, 40, 90), alpha=80, blur=50, dy=30):
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.paste(colour + (255,), (x, y + dy), layer.split()[3].point(lambda v: alpha if v else 0))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(blur)))
    img.alpha_composite(layer, (x, y))
    return img


def slide(s):
    fname, eyebrow, title, sub, a, b = s
    img = background(W, H, a, b).convert("RGBA")
    c = card(fname, int(H * 0.78))
    cx, cy = W - int(W * 0.055) - c.size[0], (H - c.size[1]) // 2
    img = place_with_shadow(img, c, cx, cy)
    d = ImageDraw.Draw(img)

    x0 = int(W * 0.065)
    colw = cx - x0 - int(W * 0.045)
    fe, ft = font("Inter-Bold.otf", 46), font("InterDisplay-Bold.otf", 112)
    fs, fp = font("Inter-Medium.otf", 46), font("Inter-SemiBold.otf", 44)
    tl = wrap(d, title.replace("\n", " "), ft, colw)
    sl = wrap(d, sub, fs, colw)
    pts = POINTS[fname]
    r = 30
    pl = [wrap(d, q, fp, colw - 2 * r - 30) for q in pts]
    block = 70 + len(tl) * 128 + 40 + len(sl) * 64 + 90 + sum(len(x) * 56 + 54 for x in pl)
    y = (H - block) / 2 - H * 0.03

    d.text((x0, y), eyebrow, font=fe, fill=a); y += 70
    for ln in tl:
        d.text((x0, y), ln, font=ft, fill=(18, 20, 33)); y += 128
    y += 40
    for ln in sl:
        d.text((x0, y), ln, font=fs, fill=(92, 98, 118)); y += 64
    y += 90
    for p, lines in zip(pts, pl):
        d.ellipse([x0, y, x0 + 2 * r, y + 2 * r], fill=a)
        d.line([(x0 + r * 0.55, y + r * 1.02), (x0 + r * 0.88, y + r * 1.35), (x0 + r * 1.48, y + r * 0.68)],
               fill=(255, 255, 255), width=7, joint="curve")
        for i, ln in enumerate(lines):
            d.text((x0 + 2 * r + 30, y + r + i * 56), ln, font=fp, fill=(30, 34, 52), anchor="lm")
        y += len(lines) * 56 + 54
    return img.convert("RGB")


def hero_slide():
    img = hero.background(W, H,
        stops=[(0.0, (226, 236, 255)), (0.14, (170, 198, 252)), (0.28, (74, 124, 236)),
               (0.65, (34, 76, 196)), (1.0, (16, 38, 120))],
        sparkles=[(0.93, 0.14, 0.014, 220), (0.97, 0.20, 0.008, 170), (0.45, 0.205, 0.008, 150)])
    d = ImageDraw.Draw(img)
    x0 = W * 0.065
    fh = font("InterDisplay-Bold.otf", 190)
    d.text((x0, H * 0.05), "Plan. Track. Achieve.", font=fh, fill=NAVY)
    fs, fb = font("Inter-Medium.otf", 64), font("Inter-Bold.otf", 64)
    part = "Your all-in-one daily planner for a "
    d.text((x0, H * 0.05 + 240), part, font=fs, fill=(22, 34, 80))
    d.text((x0 + d.textlength(part, font=fs), H * 0.05 + 240), "better you.", font=fb, fill=(31, 100, 245))

    c = card("20.webp", int(H * 0.60)).rotate(3, expand=True, resample=Image.BICUBIC)
    cx, cy = int(W * 0.95 - c.size[0]), int(H * 0.20)
    img = place_with_shadow(img, c, cx, cy, colour=(5, 15, 60), alpha=120, blur=60, dy=50)
    d = ImageDraw.Draw(img)

    isz = 128
    ft, fd = font("Inter-Bold.otf", 64), font("Inter-Medium.otf", 46)
    y, step = H * 0.255, H * 0.126
    for title, desc, color, kind in hero.FEATURES:
        pad = int(isz * 0.45)
        halo = Image.new("RGBA", (isz + 2 * pad, isz + 2 * pad), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([pad * 0.6, pad * 0.6, isz + pad * 1.4, isz + pad * 1.4], fill=color + (110,))
        img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(pad * 0.35)), (int(x0 - pad), int(y - pad + 4)))
        img.alpha_composite(hero.icon(kind, isz, color), (int(x0), int(y)))
        d = ImageDraw.Draw(img)
        tx = x0 + isz + 44
        d.text((tx, y + 2), title, font=ft, fill=(255, 255, 255))
        dy = y + 84
        for line in desc.split("\n"):
            d.text((tx, dy), line, font=fd, fill=(225, 234, 255)); dy += 58
        y += step

    by = H * 0.885
    band = Image.new("RGBA", (W, H - int(by)), (0, 0, 0, 0))
    ImageDraw.Draw(band).ellipse([-0.2 * W, 0, 1.2 * W, 2.4 * band.size[1]], fill=(12, 28, 92, 235))
    img.alpha_composite(band.filter(ImageFilter.GaussianBlur(6)), (0, int(by)))
    d = ImageDraw.Draw(img)
    fbn = font("Inter-Bold.otf", 88)
    a, b = "All You Need. In ", "One Place."
    total = d.textlength(a, font=fbn) + d.textlength(b, font=fbn)
    tx, ty = (W - total) / 2, H * 0.912
    d.text((tx, ty), a, font=fbn, fill=(255, 255, 255))
    d.text((tx + d.textlength(a, font=fbn), ty), b, font=fbn, fill=(120, 175, 255))
    d.text((W / 2, ty + 130), "Plan better. Do more. Live healthier.",
           font=font("Inter-Medium.otf", 54), fill=(225, 234, 255), anchor="mt")
    lh = 260
    img.alpha_composite(hero.laurel(lh), (int(tx - lh * 0.62), int(ty - lh * 0.15)))
    img.alpha_composite(hero.laurel(lh, flip=True), (int(tx + total + lh * 0.02), int(ty - lh * 0.15)))
    return img.convert("RGB")


os.makedirs(OUT, exist_ok=True)
shots = [hero_slide()] + [slide(s) for s in SLIDES]
for i, im in enumerate(shots):
    assert im.size == (W, H) and im.mode == "RGB"
    p = os.path.join(OUT, f"iPad13_2064x2752_{i:02d}.png")
    im.save(p, "PNG", optimize=True)
    print(p)
