"""App Store app preview: 886x1920, 30 fps, ~27 s, H.264 + stereo AAC.

Usage: python preview.py <images_dir> <app_icon_png> <out_mp4>
"""
import os, sys, math, struct, wave, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFilter
from make_shots import font, clean_status_bar

IMG, ICON, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
W, H, FPS = 886, 1920, 30
WORK = os.path.dirname(os.path.abspath(OUT))

SCENES = [
    ("20.webp", "YOUR DAY, ORGANISED", "Everything at a glance", (61, 120, 255)),
    ("18.webp", "TO-DO LIST", "Plan it. Do it. Tick it off.", (40, 120, 245)),
    ("16.webp", "HEALTH TRACKER", "Small habits, a healthier you", (240, 80, 130)),
    ("19.webp", "HEALTH & FITNESS", "Syncs with Apple Health", (235, 70, 110)),
    ("13.webp", "FOOD TRACKER", "Snap a meal, see the calories", (245, 140, 30)),
    ("12.webp", "FINANCE TRACKER", "Know where your money goes", (30, 170, 100)),
    ("17.webp", "MY SCHEDULE", "Your day, perfectly planned", (120, 80, 235)),
    ("15.webp", "SUBSCRIPTIONS", "Never miss a renewal", (120, 80, 235)),
    ("14.webp", "NOTES & JOURNAL", "Reflect on what matters", (240, 70, 120)),
]
INTRO, SCENE, OUTRO, FADE = 2.4, 2.4, 3.0, 0.35
TOTAL = INTRO + SCENE * len(SCENES) + OUTRO


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------- prepared layers ----------

def soft_bg():
    top, bot = (226, 236, 255), (246, 243, 255)
    col = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / H
        col.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    bg = col.resize((W, H)).convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse([0.3 * W, -0.15 * H, 1.4 * W, 0.35 * H], fill=(150, 185, 255, 150))
    g.ellipse([-0.5 * W, 0.6 * H, 0.6 * W, 1.1 * H], fill=(190, 160, 255, 110))
    return Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(120)))


def screen(name):
    im = Image.open(os.path.join(IMG, name)).convert("RGB")
    im = im.resize((W, int(im.size[1] * W / im.size[0])), Image.LANCZOS)
    top = (im.size[1] - H) // 2
    im = im.crop((0, top, W, top + H))
    return clean_status_bar(im)


def caption_layer(eyebrow, title, color):
    """A dark band at the foot of the screen with the scene's caption."""
    band_h = int(H * 0.215)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grad = Image.new("RGBA", (1, band_h))
    for y in range(band_h):
        a = int(235 * min(1.0, (y / band_h) / 0.45))
        grad.putpixel((0, y), (10, 18, 58, a))
    layer.alpha_composite(grad.resize((W, band_h)), (0, H - band_h))
    d = ImageDraw.Draw(layer)
    cy = H - band_h * 0.50
    light = tuple(min(255, int(c * 0.55 + 255 * 0.45)) for c in color)
    d.text((W / 2, cy - 10), eyebrow, font=font("Inter-Bold.otf", 30), fill=light + (255,), anchor="mb")
    ft = font("InterDisplay-Bold.otf", 60)
    while d.textlength(title, font=ft) > W * 0.9:
        ft = font("InterDisplay-Bold.otf", ft.size - 2)
    d.text((W / 2, cy + 6), title, font=ft, fill=(255, 255, 255, 255), anchor="mt")
    return layer


def title_card(lines, icon_scale):
    """Intro / outro: icon, then lines of (text, font, size, colour)."""
    img = BG.copy()
    s = int(300 * icon_scale)
    if s > 4:
        ic = ICON_IMG.resize((s, s), Image.LANCZOS)
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], int(s * 0.225), fill=255)
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([(W - s) / 2, H * 0.30 - s / 2 + 22, (W + s) / 2, H * 0.30 + s / 2 + 22],
                                             int(s * 0.225), fill=(40, 60, 140, 90))
        img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(28)))
        img.paste(ic, (int((W - s) / 2), int(H * 0.30 - s / 2)), mask)
    d = ImageDraw.Draw(img)
    y = H * 0.30 + 190
    for text, fname, size, colour in lines:
        d.text((W / 2, y), text, font=font(fname, size), fill=colour, anchor="mt")
        y += size * 1.35
    return img


BG = soft_bg()
ICON_IMG = Image.open(ICON).convert("RGB")
SCREENS = [screen(s[0]) for s in SCENES]
CAPS = [caption_layer(s[1], s[2], s[3]) for s in SCENES]


def scene_frame(i, t):
    """Scene i at local time t: slow zoom, caption rising in."""
    z = 1.0 + 0.045 * ease(t / SCENE)
    sw, sh = int(W * z), int(H * z)
    im = SCREENS[i].resize((sw, sh), Image.BILINEAR)
    ox, oy = (sw - W) // 2, int((sh - H) * 0.35)
    frame = im.crop((ox, oy, ox + W, oy + H)).convert("RGBA")
    k = ease((t - 0.15) / 0.45)
    if k > 0:
        cap = CAPS[i]
        if k < 1:
            a = cap.split()[3].point(lambda v: int(v * k))
            cap = cap.copy(); cap.putalpha(a)
        frame.alpha_composite(cap, (0, int((1 - k) * 40)))
    return frame


def intro_frame(t):
    k = ease(t / 0.8)
    navy = (14, 30, 91, 255)
    return title_card([("Daily Planner", "InterDisplay-Bold.otf", 76, navy),
                       ("Plan. Track. Achieve.", "Inter-SemiBold.otf", 40, (31, 100, 245, 255))],
                      0.6 + 0.4 * k)


def outro_frame(t):
    navy = (14, 30, 91, 255)
    return title_card([("All You Need.", "InterDisplay-Bold.otf", 72, navy),
                       ("In One Place.", "InterDisplay-Bold.otf", 72, (31, 100, 245, 255)),
                       ("Plan better. Do more. Live healthier.", "Inter-Medium.otf", 34, (70, 80, 110, 255))],
                      1.0)


def frame_at(t):
    """The video frame at time t, with cross-fades between segments."""
    segs = [("intro", 0.0, INTRO)]
    for i in range(len(SCENES)):
        segs.append((i, INTRO + i * SCENE, SCENE))
    segs.append(("outro", INTRO + len(SCENES) * SCENE, OUTRO))

    def render(seg, local):
        key = seg[0]
        if key == "intro": return intro_frame(local)
        if key == "outro": return outro_frame(local)
        return scene_frame(key, local)

    for idx, seg in enumerate(segs):
        start, dur = seg[1], seg[2]
        if start <= t < start + dur or idx == len(segs) - 1:
            local = t - start
            cur = render(seg, local)
            if idx + 1 < len(segs) and local > dur - FADE:
                a = ease((local - (dur - FADE)) / FADE)
                cur = Image.blend(cur, render(segs[idx + 1], 0.0), a)
            return cur
    return BG


# ---------- soft music bed ----------

def music(path, seconds, rate=48000):
    """A calm four-chord pad with soft bell accents."""
    chords = [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]]
    hz = lambda m: 440 * 2 ** ((m - 69) / 12)
    n = int(seconds * rate)
    seg = n / 4
    out = []
    for i in range(n):
        t = i / rate
        c = min(3, int(i / seg))
        lt = (i - c * seg) / rate
        env = min(1.0, lt / 1.2) * min(1.0, (seg / rate - lt) / 1.2)
        v = 0.0
        for m in chords[c]:
            f = hz(m)
            v += math.sin(2 * math.pi * f * t) + 0.25 * math.sin(2 * math.pi * f * 2.003 * t)
        v *= 0.035 * env
        # a soft bell on each beat of the chord's top note
        bt = lt % 1.6875
        if bt < 1.2:
            v += 0.05 * math.exp(-4.5 * bt) * math.sin(2 * math.pi * hz(chords[c][-1] + 12) * t)
        fade = min(1.0, t / 1.0) * min(1.0, (seconds - t) / 1.5)
        s = max(-1.0, min(1.0, v * fade))
        l = int(s * 32767 * 0.9)
        out.append(struct.pack("<hh", l, l))
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"".join(out))


if __name__ == "__main__":
    audio = os.path.join(WORK, "preview_music.wav")
    music(audio, TOTAL)
    frames = int(round(TOTAL * FPS))
    cmd = ["ffmpeg", "-y", "-loglevel", "error",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-i", audio,
           "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
           "-b:v", "11M", "-maxrate", "12M", "-bufsize", "24M", "-r", str(FPS),
           "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
           "-shortest", "-movflags", "+faststart", OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for f in range(frames):
        p.stdin.write(frame_at(f / FPS).convert("RGB").tobytes())
    p.stdin.close()
    p.wait()
    print(OUT, TOTAL, "s,", frames, "frames")
