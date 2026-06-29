#!/usr/bin/env python
"""
Generate Cyberpunk BCD Binary watch face store / promotional art into assets/:

    hero_image.png      1440x720  -- wide banner: "CYBERPUNK BINARY" title + watch on a scene
    cover_image.png     500x500   -- square cover: the watch on a synthwave scene
    cover_image.jpg     500x500   -- JPEG twin of the cover
    app_icon_24bit.png  128x128   -- circular store icon (neon binary-grid badge)
    app_icon_64color.png 128x128  -- same icon (separate file kept for parity)

The scene is composed from the watch face's own palette (a near-black cyberpunk
night, a glowing neon perspective grid floor, drifting columns of falling 0/1
digital rain, and floating glass orbs in the five theme colors) so the art stays
on-brand, with the real watch render (assets/screen_active.png) dropped into a
drawn watch body. Produce that render first with savescreenshot.ps1.

Run:  python tools/gen_promo.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
RENDER = os.path.join(ASSETS, "screen_active.png")  # round RGBA render from savescreenshot.ps1
BOLD_FONT = "C:/Windows/Fonts/segoeuib.ttf"
MONO_FONT = "C:/Windows/Fonts/consola.ttf"  # Consolas, for the digital-rain 0/1s

SS = 2  # supersample factor for the big pieces

# --- cyberpunk / synthwave palette (mirrors BinaryWatchFace's neon-on-black look) --
# Background sits on the face's own 0x0A0A0F near-black and rises into a magenta
# horizon glow, then drops back to dark below the grid floor.
SKY = [
    (0.00, (10, 10, 15)),      # 0x0A0A0F near-black zenith
    (0.40, (18, 12, 34)),      # deep indigo
    (0.66, (46, 16, 62)),      # purple
    (0.80, (132, 26, 98)),     # magenta horizon glow
    (0.86, (40, 14, 60)),      # falloff back into dark
    (1.00, (10, 8, 20)),
]
HORIZON = 0.80  # fraction of height where the neon grid floor begins

# the watch face's five theme accents: cyan, pink, green, amber, white
NEON = [
    (0, 255, 255), (255, 0, 255), (0, 255, 0), (255, 136, 0), (240, 248, 255),
]
CYAN = (0, 240, 255)
MAGENTA = (255, 0, 200)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def grad_color(stops, t):
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        if p0 <= t <= p1:
            return lerp(c0, c1, (t - p0) / (p1 - p0) if p1 > p0 else 0)
    return stops[-1][1]


def vgrad(w, h, stops):
    col = Image.new("RGB", (1, h))
    for y in range(h):
        col.putpixel((0, y), grad_color(stops, y / (h - 1)))
    return col.resize((w, h))


def add_glow(scene, layer, blur):
    """Composite a glow (blurred copy) then the crisp layer over the scene."""
    glow = layer.filter(ImageFilter.GaussianBlur(blur))
    scene.paste(glow, (0, 0), glow)
    scene.paste(layer, (0, 0), layer)


def draw_grid_floor(scene, w, h, horizon_y, vanish_x):
    """A glowing neon perspective grid receding to a vanishing point on the horizon."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lw = max(1, int(w * 0.0016))

    # converging vertical rails: fan out across (and beyond) the bottom edge
    span = int(w * 1.6)
    n_v = 26
    for i in range(n_v + 1):
        bx = (w - span) / 2 + span * i / n_v
        d.line([(bx, h), (vanish_x, horizon_y)], fill=CYAN + (180,), width=lw)

    # horizontal rungs: spaced ever-wider toward the foreground (perspective)
    n_h = 14
    for i in range(1, n_h + 1):
        t = i / n_h
        y = horizon_y + (h - horizon_y) * (t * t)
        a = int(70 + 150 * t)
        d.line([(0, y), (w, y)], fill=MAGENTA + (a,), width=lw)

    add_glow(scene, layer, h * 0.006)


def draw_horizon_sun(scene, cx, cy, r):
    """A soft synthwave sun glow behind the horizon (cyan core into magenta)."""
    w, h = scene.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 16
    for k in range(steps, 0, -1):
        rr = r * k / steps
        col = lerp(MAGENTA, CYAN, k / steps)
        a = int(120 * (1 - k / steps) + 30)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (a,))
    blur = layer.filter(ImageFilter.GaussianBlur(r * 0.10))
    scene.paste(blur, (0, 0), blur)


def draw_digital_rain(scene, w, h, horizon_y, rnd):
    """Faint vertical columns of falling 0/1 glyphs, Matrix-style, in the sky."""
    try:
        font = ImageFont.truetype(MONO_FONT, int(h * 0.030))
    except OSError:
        font = ImageFont.load_default()
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    gh = int(h * 0.038)
    cols = int(w / (gh * 0.85))
    for c in range(cols):
        if rnd.random() < 0.45:
            continue
        x = int(c * gh * 0.85) + rnd.randint(-4, 4)
        length = rnd.randint(4, 11)
        y0 = rnd.randint(-int(h * 0.1), int(horizon_y * 0.75))
        base = rnd.choice([(0, 255, 120), CYAN, (0, 255, 120)])
        for j in range(length):
            ch = rnd.choice("01")
            a = int(200 * (j + 1) / length)          # brightest at the leading tip
            col = (240, 255, 245) if j == length - 1 else base
            d.text((x, y0 + j * gh), ch, font=font, fill=col + (a,))
    add_glow(scene, layer, h * 0.004)


def draw_orb(d, cx, cy, r, color):
    """A glowing glass orb like the watch's lit binary dots: core + specular highlight."""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (255,))
    # darker rim for a touch of glass depth
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=lerp(color, (0, 0, 0), 0.45) + (200,),
              width=max(1, int(r * 0.14)))
    # specular highlight, top-left
    hr = r * 0.34
    hx, hy = cx - r * 0.30, cy - r * 0.34
    d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=(255, 255, 255, 190))


def draw_orbs(scene, w, h, rnd):
    """Scatter floating glass orbs (glow + crisp) across the sky in theme colors."""
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    crisp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd, cd = ImageDraw.Draw(glow), ImageDraw.Draw(crisp)
    n = int(w * h / 90000)
    for _ in range(n):
        x = rnd.randint(int(w * 0.04), int(w * 0.96))
        y = rnd.randint(int(h * 0.06), int(h * 0.74))
        r = rnd.choice([int(h * 0.012), int(h * 0.018), int(h * 0.026)])
        col = rnd.choice(NEON)
        gr = r * 2.4
        gd.ellipse([x - gr, y - gr, x + gr, y + gr], fill=col + (110,))
        draw_orb(cd, x, y, r, col)
    glow = glow.filter(ImageFilter.GaussianBlur(h * 0.012))
    scene.paste(glow, (0, 0), glow)
    scene.paste(crisp, (0, 0), crisp)


def build_scene(w, h):
    """Return an RGB cyberpunk synthwave scene sized (w, h)."""
    rnd = random.Random(101)
    img = vgrad(w, h, SKY)
    d = ImageDraw.Draw(img, "RGBA")
    horizon_y = int(h * HORIZON)

    # faint stars in the upper sky
    for _ in range(int(w * h / 5200)):
        x = rnd.randint(0, w - 1)
        y = rnd.randint(0, int(horizon_y * 0.7))
        r = rnd.choice([1, 1, 1, 2])
        a = rnd.randint(90, 210)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 235, 255, a))

    draw_horizon_sun(img, int(w * 0.50), horizon_y, int(h * 0.34))
    draw_digital_rain(img, w, h, horizon_y, rnd)
    draw_grid_floor(img, w, h, horizon_y, int(w * 0.50))

    # a thin bright scanline right on the horizon
    ld = ImageDraw.Draw(img, "RGBA")
    ld.rectangle([0, horizon_y - max(1, int(h * 0.003)), w, horizon_y], fill=(255, 255, 255, 120))

    draw_orbs(img, w, h, rnd)
    return img


def paste_watch(scene, cx, cy, screen_d):
    """Draw a watch body and drop the real round render onto it, centred at (cx, cy)."""
    w, h = scene.size
    render = Image.open(RENDER).convert("RGBA").resize((screen_d, screen_d), Image.LANCZOS)
    case_d = int(screen_d * 1.13)
    band_w = int(case_d * 0.46)

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # contact shadow under the watch
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - case_d * 0.55, cy + case_d * 0.30,
                                cx + case_d * 0.55, cy + case_d * 0.62],
                               fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(case_d * 0.04))
    scene.paste(sh, (0, 0), sh)

    # band (top + bottom)
    for sign in (-1, 1):
        y0 = cy + sign * case_d * 0.30
        y1 = cy + sign * case_d * 0.95
        top, bot = (y0, y1) if sign < 0 else (y1, y0)
        d.polygon([(cx - band_w / 2, cy), (cx + band_w / 2, cy),
                   (cx + band_w * 0.40, bot if sign > 0 else top),
                   (cx - band_w * 0.40, bot if sign > 0 else top)],
                  fill=(20, 22, 30, 255))
    # case (dark gunmetal, on theme)
    d.ellipse([cx - case_d / 2, cy - case_d / 2, cx + case_d / 2, cy + case_d / 2],
              fill=(14, 15, 20, 255))
    # neon bezel ring (cyan)
    bz = int(screen_d * 1.05)
    d.ellipse([cx - bz / 2, cy - bz / 2, cx + bz / 2, cy + bz / 2],
              outline=CYAN + (210,), width=max(2, int(screen_d * 0.012)))
    scene.paste(layer, (0, 0), layer)

    # cyan bezel glow
    ring = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([cx - bz / 2, cy - bz / 2, cx + bz / 2, cy + bz / 2],
                                 outline=CYAN + (180,), width=max(3, int(screen_d * 0.03)))
    ring = ring.filter(ImageFilter.GaussianBlur(screen_d * 0.02))
    scene.paste(ring, (0, 0), ring)

    # metallic sheen arc on the case (top-left)
    sheen = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).arc([cx - case_d / 2, cy - case_d / 2, cx + case_d / 2, cy + case_d / 2],
                              start=160, end=250, fill=(170, 180, 205, 140),
                              width=max(2, int(case_d * 0.02)))
    sheen = sheen.filter(ImageFilter.GaussianBlur(case_d * 0.01))
    scene.paste(sheen, (0, 0), sheen)

    # the actual round render (its own alpha makes it a clean circle)
    scene.paste(render, (cx - screen_d // 2, cy - screen_d // 2), render)


def draw_title(scene, text, cx, cy, px):
    """Centred, letter-spaced bold title with a cyan glow + magenta chromatic echo."""
    font = ImageFont.truetype(BOLD_FONT, px)
    track = int(px * 0.10)
    widths = [font.getbbox(ch)[2] - font.getbbox(ch)[0] for ch in text]
    total = sum(widths) + track * (len(text) - 1)
    asc, desc = font.getmetrics()
    y = cy - (asc + desc) / 2

    def render_pass(fill, dx=0, dy=0):
        img = Image.new("RGBA", scene.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(img)
        x = cx - total / 2
        for ch, wch in zip(text, widths):
            gd.text((x + dx, y + dy), ch, font=font, fill=fill)
            x += wch + track
        return img

    # cyan glow halo
    glow = render_pass(CYAN + (255,)).filter(ImageFilter.GaussianBlur(px * 0.13))
    scene.paste(glow, (0, 0), glow)

    # chromatic echoes: magenta down-right, cyan up-left, white face on top
    for layer in (render_pass(MAGENTA + (220,), px * 0.04, px * 0.04),
                  render_pass(CYAN + (200,), -px * 0.03, -px * 0.03),
                  render_pass((244, 248, 255, 255))):
        scene.paste(layer, (0, 0), layer)


def binary_badge(size):
    """A neon binary-grid badge on a dark disc -> RGBA (size x size)."""
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # dark disc, on the face's near-black
    disc = vgrad(S, S, [(0.0, (12, 12, 18)), (0.7, (16, 14, 30)),
                        (1.0, (30, 16, 44))]).convert("RGBA")
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([S * 0.02, S * 0.02, S * 0.98, S * 0.98], fill=255)
    img.paste(disc, (0, 0), mask)

    # neon ring with glow
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([S * 0.04, S * 0.04, S * 0.96, S * 0.96],
                                 outline=CYAN + (255,), width=max(3, int(S * 0.045)))
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(S * 0.02)))
    img.alpha_composite(ring)

    # a 3-column x 4-row mini BCD grid; "lit" cells glow, others stay dim.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    crisp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd, cd = ImageDraw.Draw(glow), ImageDraw.Draw(crisp)
    cols, rows = 3, 4
    r = S * 0.052
    x0, x1 = S * 0.30, S * 0.70
    y0, y1 = S * 0.28, S * 0.72
    lit = {(0, 1), (1, 0), (1, 2), (1, 3), (2, 1), (2, 3), (0, 3)}  # an arbitrary on-pattern
    col_accent = [CYAN, (255, 0, 200), (0, 255, 0)]
    for c in range(cols):
        cx = x0 + (x1 - x0) * c / (cols - 1)
        for rrow in range(rows):
            cy = y0 + (y1 - y0) * rrow / (rows - 1)
            if (c, rrow) in lit:
                col = col_accent[c]
                gd.ellipse([cx - r * 2, cy - r * 2, cx + r * 2, cy + r * 2], fill=col + (120,))
                cd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))
                cd.ellipse([cx - r * 0.34, cy - r * 0.4, cx + r * 0.2, cy], fill=(255, 255, 255, 200))
            else:
                cd.ellipse([cx - r * 0.8, cy - r * 0.8, cx + r * 0.8, cy + r * 0.8],
                           fill=(40, 44, 60, 255))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(S * 0.012)))
    img.alpha_composite(crisp)

    # clip everything back to the disc so the glow doesn't bleed past the edge
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def build_hero():
    W, H = 1440 * SS, 720 * SS
    scene = build_scene(W, H)
    paste_watch(scene, int(W * 0.50), int(H * 0.56), int(H * 0.60))
    draw_title(scene, "CYBERPUNK BINARY", int(W * 0.50), int(H * 0.135), int(H * 0.100))
    return scene.resize((1440, 720), Image.LANCZOS)


def build_cover():
    W = H = 500 * SS
    scene = build_scene(W, H)
    paste_watch(scene, W // 2, int(H * 0.50), int(H * 0.66))
    return scene.resize((500, 500), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)

    hero = build_hero()
    hero.save(os.path.join(ASSETS, "hero_image.png"))
    print("hero_image.png      1440x720")

    cover = build_cover()
    cover.save(os.path.join(ASSETS, "cover_image.png"))
    cover.convert("RGB").save(os.path.join(ASSETS, "cover_image.jpg"), quality=90)
    print("cover_image.png/.jpg 500x500")

    icon = binary_badge(128)
    icon.convert("RGB").save(os.path.join(ASSETS, "app_icon_24bit.png"))
    icon.convert("RGB").save(os.path.join(ASSETS, "app_icon_64color.png"))
    print("app_icon_*.png      128x128")
    print("Done.")
