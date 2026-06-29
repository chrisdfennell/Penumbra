#!/usr/bin/env python
"""
Generate Penumbra store / promotional art into assets/:

    hero_image.png      1440x720  -- wide banner: "PENUMBRA" wordmark + the watch
    cover_image.png     500x500   -- square cover: the watch on the terminator
    cover_image.jpg     500x500   -- JPEG twin of the cover
    app_icon_24bit.png  128x128   -- circular store icon (an eclipse badge)
    app_icon_64color.png 128x128  -- same icon (separate file kept for parity)

Penumbra is named for the penumbra -- the soft edge between light and shadow -- so
the art is built from that single idea: a smooth "terminator" gradient sweeping from
full light into deep shadow, the real round watch render (assets/screen_active.png)
dropped into a clean graphite case ringed by an accent-coloured corona, and a quiet,
data-clean wordmark. No neon: the face is bright and minimal, and so is its art.

Produce the render first with savescreenshot.ps1, then run:

    python tools/gen_promo.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
RENDER = os.path.join(ASSETS, "screen_active.png")  # round RGBA render from savescreenshot.ps1
BOLD_FONT = "C:/Windows/Fonts/segoeuib.ttf"
LIGHT_FONT = "C:/Windows/Fonts/segoeui.ttf"  # for the quiet tagline / small caps

SS = 2  # supersample factor for the big pieces

# --- Penumbra palette --------------------------------------------------------------
# The face's two themes are pure light (white paper, black ink) and pure dark (black,
# white ink). The art lives in the band between them: a sweep from paper-light through
# a soft grey penumbra into umbra-black.
LIGHT = (249, 249, 251)    # light-theme paper, the bright end of the sweep
PENUMBRA = (118, 120, 130)  # the soft grey mid-band the face is named for
UMBRA = (9, 9, 11)         # dark-theme ink-black, the shadow end

# The diagonal light -> shadow terminator, sampled as a gradient.
SWEEP = [
    (0.00, LIGHT),
    (0.40, (208, 208, 214)),
    (0.54, PENUMBRA),
    (0.68, (42, 42, 50)),
    (1.00, UMBRA),
]

# The face's five selectable accents: orange (default), blue, green, red, yellow.
ACCENTS = [
    (240, 138, 30),   # 0xF08A1E orange  (default)
    (46, 125, 224),   # 0x2E7DE0 blue
    (46, 168, 79),    # 0x2EA84F green
    (226, 59, 46),    # 0xE23B2E red
    (242, 196, 0),    # 0xF2C400 yellow
]
ACCENT_IDX = 0           # match the watch face's default accent
ACCENT = ACCENTS[ACCENT_IDX]


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


def diag_grad(w, h, stops, ang_deg=34):
    """A smooth gradient sweeping along a diagonal -- the light->shadow terminator.

    Sampled at low resolution and scaled up so the transition stays buttery."""
    a = math.radians(ang_deg)
    ux, uy = math.cos(a), math.sin(a)
    norm = ux + uy
    sw = 200
    sh = max(1, int(sw * h / w))
    small = Image.new("RGB", (sw, sh))
    px = small.load()
    for yy in range(sh):
        fy = yy / (sh - 1) if sh > 1 else 0
        for xx in range(sw):
            fx = xx / (sw - 1) if sw > 1 else 0
            t = (fx * ux + fy * uy) / norm
            px[xx, yy] = grad_color(stops, t)
    return small.resize((w, h), Image.BILINEAR)


def draw_corona(scene, cx, cy, r, color, strength=150):
    """A soft circular halo of light around a point -- the watch's eclipse corona."""
    w, h = scene.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 22
    for k in range(steps, 0, -1):
        rr = r * k / steps
        a = int(strength * (1 - k / steps) ** 1.6)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(r * 0.06))
    scene.paste(layer, (0, 0), layer)


def draw_motes(scene, w, h, rnd_seed=7):
    """Faint specks of light: warm dust in the lit zone, cool sparks in the shadow.

    A tiny, seeded LCG keeps this deterministic without Math.random / Date."""
    state = rnd_seed
    def rnd():
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state / 0x7FFFFFFF

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    n = int(w * h / 14000)
    for _ in range(n):
        x = rnd() * w
        y = rnd() * h
        # brightness of the underlying sweep along the same diagonal we used above
        t = ((x / w) * math.cos(math.radians(34)) + (y / h) * math.sin(math.radians(34)))
        t /= (math.cos(math.radians(34)) + math.sin(math.radians(34)))
        if t < 0.5:  # lit zone -> warm motes, sparse
            if rnd() < 0.7:
                continue
            col, a = (255, 244, 224), int(40 + 50 * rnd())
        else:        # shadow -> cool sparks like emerging stars
            col, a = (220, 232, 255), int(60 + 130 * rnd())
        r = rnd() * 1.6 + 0.6
        d.ellipse([x - r, y - r, x + r, y + r], fill=col + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    scene.paste(layer, (0, 0), layer)


def add_vignette(scene, strength=90):
    """Gently darken the corners to settle the composition."""
    w, h = scene.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([-w * 0.25, -h * 0.25, w * 1.25, h * 1.25], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, strength))
    inv = Image.eval(mask, lambda v: 255 - v)
    scene.paste(dark, (0, 0), inv)


def build_scene(w, h, ang_deg=34):
    """Return an RGB light->shadow penumbra scene sized (w, h)."""
    img = diag_grad(w, h, SWEEP, ang_deg).convert("RGB")
    draw_motes(img, w, h)
    return img


def paste_watch(scene, cx, cy, screen_d):
    """Draw a clean graphite case, ring it with an accent corona, and drop the real
    round render onto it, centred at (cx, cy)."""
    w, h = scene.size
    render = Image.open(RENDER).convert("RGBA").resize((screen_d, screen_d), Image.LANCZOS)
    case_d = int(screen_d * 1.13)
    band_w = int(case_d * 0.46)

    # the corona of light bleeding past the watch -- the "penumbra" around the case
    draw_corona(scene, cx, cy, int(case_d * 0.92), ACCENT, strength=120)

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # contact shadow under the watch
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - case_d * 0.55, cy + case_d * 0.30,
                                cx + case_d * 0.55, cy + case_d * 0.64],
                               fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(case_d * 0.045))
    scene.paste(sh, (0, 0), sh)

    # band (top + bottom), in a soft graphite that reads on both ends of the sweep
    for sign in (-1, 1):
        y0 = cy + sign * case_d * 0.30
        y1 = cy + sign * case_d * 0.95
        top, bot = (y0, y1) if sign < 0 else (y1, y0)
        d.polygon([(cx - band_w / 2, cy), (cx + band_w / 2, cy),
                   (cx + band_w * 0.40, bot if sign > 0 else top),
                   (cx - band_w * 0.40, bot if sign > 0 else top)],
                  fill=(36, 38, 44, 255))
    # case (brushed graphite)
    d.ellipse([cx - case_d / 2, cy - case_d / 2, cx + case_d / 2, cy + case_d / 2],
              fill=(30, 31, 37, 255))
    # thin accent bezel ring
    bz = int(screen_d * 1.05)
    d.ellipse([cx - bz / 2, cy - bz / 2, cx + bz / 2, cy + bz / 2],
              outline=ACCENT + (220,), width=max(2, int(screen_d * 0.012)))
    scene.paste(layer, (0, 0), layer)

    # accent bezel glow
    ring = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([cx - bz / 2, cy - bz / 2, cx + bz / 2, cy + bz / 2],
                                 outline=ACCENT + (170,), width=max(3, int(screen_d * 0.028)))
    ring = ring.filter(ImageFilter.GaussianBlur(screen_d * 0.02))
    scene.paste(ring, (0, 0), ring)

    # cool metallic sheen arc on the case (top-left, catching the light)
    sheen = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).arc([cx - case_d / 2, cy - case_d / 2, cx + case_d / 2, cy + case_d / 2],
                              start=158, end=252, fill=(210, 214, 226, 150),
                              width=max(2, int(case_d * 0.018)))
    sheen = sheen.filter(ImageFilter.GaussianBlur(case_d * 0.01))
    scene.paste(sheen, (0, 0), sheen)

    # the actual round render (its own alpha makes it a clean circle)
    scene.paste(render, (cx - screen_d // 2, cy - screen_d // 2), render)


def draw_wordmark(scene, text, cx, cy, px, ink, halo):
    """Centred, letter-spaced wordmark with a soft contrasting halo for legibility,
    and a short accent underline tying it to the face's accent colour."""
    font = ImageFont.truetype(BOLD_FONT, px)
    track = int(px * 0.16)
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

    # soft halo (opposite tone) so the wordmark holds up wherever it sits on the sweep
    glow = render_pass(halo + (235,)).filter(ImageFilter.GaussianBlur(px * 0.16))
    scene.paste(glow, (0, 0), glow)
    scene.paste(glow, (0, 0), glow)

    # crisp glyphs
    scene.paste(render_pass(ink + (255,)), (0, 0), render_pass(ink + (255,)))

    # accent underline, centred under the wordmark
    bar = Image.new("RGBA", scene.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    uw = total * 0.30
    uy = y + asc + desc * 0.4
    bd.rounded_rectangle([cx - uw / 2, uy, cx + uw / 2, uy + max(2, px * 0.05)],
                         radius=px * 0.03, fill=ACCENT + (255,))
    scene.paste(bar, (0, 0), bar)


def draw_tagline(scene, text, cx, y, px, color):
    """A quiet, wide-tracked small-caps tagline."""
    font = ImageFont.truetype(LIGHT_FONT, px)
    text = text.upper()
    track = int(px * 0.34)
    widths = [font.getbbox(ch)[2] - font.getbbox(ch)[0] for ch in text]
    total = sum(widths) + track * (len(text) - 1)
    layer = Image.new("RGBA", scene.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x = cx - total / 2
    for ch, wch in zip(text, widths):
        d.text((x, y), ch, font=font, fill=color + (235,))
        x += wch + track
    scene.paste(layer, (0, 0), layer)


def eclipse_badge(size):
    """A bold split disc: a light half and a shadow half meeting at a soft penumbra
    terminator down the middle, with an accent rim and a faint glow on the seam.
    The literal picture of a penumbra, legible right down to favicon size
    -> RGBA (size x size)."""
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    disc = [S * 0.05, S * 0.05, S * 0.95, S * 0.95]
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse(disc, fill=255)

    # high-contrast light->shadow split with a soft penumbra band across the middle
    SPLIT = [
        (0.00, (236, 237, 242)),   # full light
        (0.40, (224, 225, 231)),
        (0.50, (120, 122, 132)),   # penumbra mid-grey
        (0.60, (34, 34, 41)),
        (1.00, UMBRA),             # full shadow
    ]
    split = Image.new("RGB", (S, 1))
    for x in range(S):
        split.putpixel((x, 0), grad_color(SPLIT, x / (S - 1)))
    split = split.resize((S, S)).convert("RGBA")
    img.paste(split, (0, 0), mask)

    # a faint accent glow sitting on the terminator seam
    seam = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(seam)
    sw = max(3, int(S * 0.02))
    sd.rectangle([S * 0.5 - sw, S * 0.08, S * 0.5 + sw, S * 0.92], fill=ACCENT + (170,))
    seam = seam.filter(ImageFilter.GaussianBlur(S * 0.03))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow.paste(seam, (0, 0), mask)
    img.alpha_composite(glow)

    # a thin accent rim with a touch of glow for a crisp store-icon edge
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse(disc, outline=ACCENT + (255,), width=max(3, int(S * 0.032)))
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(S * 0.012)))
    img.alpha_composite(ring)

    # clip everything back to the disc so nothing bleeds past the edge
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)


def build_hero():
    W, H = 1440 * SS, 720 * SS
    scene = build_scene(W, H, ang_deg=30)
    paste_watch(scene, int(W * 0.62), int(H * 0.54), int(H * 0.62))
    # wordmark sits in the lit upper-left; dark ink on a light halo holds up there
    draw_wordmark(scene, "PENUMBRA", int(W * 0.305), int(H * 0.30),
                  int(H * 0.105), ink=(22, 22, 26), halo=(255, 255, 255))
    draw_tagline(scene, "Light · Dark digital", int(W * 0.305), int(H * 0.41),
                 int(H * 0.030), color=(70, 72, 82))
    add_vignette(scene, strength=70)
    return scene.resize((1440, 720), Image.LANCZOS)


def build_cover():
    W = H = 500 * SS
    scene = build_scene(W, H, ang_deg=34)
    paste_watch(scene, W // 2, int(H * 0.50), int(H * 0.66))
    add_vignette(scene, strength=80)
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

    icon = eclipse_badge(128)
    icon.convert("RGB").save(os.path.join(ASSETS, "app_icon_24bit.png"))
    icon.convert("RGB").save(os.path.join(ASSETS, "app_icon_64color.png"))
    print("app_icon_*.png      128x128")
    print("Done.")
