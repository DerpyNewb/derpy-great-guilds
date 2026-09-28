"""The Great Guilds - the icons its effect bundles show in the game's own effect lists.

WHY. All 379 of the mod's effect bundles shipped with an empty `ui_icon`, so the Faction
Effects panel and every list that reads `effect_bundles` drew the guilds' ranks, lead and
services with no picture at all, beside CA's rows which all wear one. Asked for on
2026-09-26 ("active effects should also have the background").

WHAT CA'S LOOK IS. Every one of CA's 1,115 files in `ui/campaign ui/effect_bundles/` is
24x24, and 520 of them are a glyph over the same teal disc - lower left, the glyph over its
upper right. CA ships no bare disc (`icon_blank.png` is fully transparent), so the disc is
RECOVERED from CA's own icons each run rather than copied or drawn by eye:

  1. read all 24x24 icons out of the game's ui packs, keep the ones teal at the disc's
     left edge (the glyphs never reach it);
  2. fit a circle to the edge of their median alpha on the left and bottom arcs, which no
     glyph covers;
  3. take the teal's colour straight from those icons wherever at least half of them show
     it there, and under the glyphs, where too few do, from a quadratic in x and y fitted
     to the measured pixels - the disc has a rim light on its left that a fit alone
     flattens, measured 40-55 levels off;
  4. take the rim - teal darkening to black, then a soft shadow - from the radial profile
     of the clean arcs.

The glyph is our own recoloured guild mark (tools/make_guild_icons.py), in the race's
flavour, with a dark outline: the marks are cream, drawn for a near-black card, and cream
on teal has too little edge without one. The patron's bundle names no guild and wears the
crest.

    py tools/make_guild_bundle_icons.py            write the icons
    py tools/make_guild_bundle_icons.py --check    every icon the DB names is staged
    py tools/make_guild_bundle_icons.py --selftest
"""
import io
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_great_guilds as G                                   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data"
PACKS = ("ui.pack", "ui2.pack", "ui3.pack", "ui_3.pack")
ICONS = os.path.join(ROOT, "Modding Files", "pack", "ui", "campaign ui", "derpy_gg_icons")
OUT = os.path.join(ROOT, "Modding Files", "pack", "ui", "campaign ui", "effect_bundles")
SIZE = 24
# Where the glyph goes, CA's way: over the disc's upper right, reaching past its rim.
GLYPH = 18
GLYPH_AT = (6, 0)


def ca_icons():
    """Every 24x24 effect bundle icon in the game's ui packs, as an N x 24 x 24 x 4 array."""
    import read_pack_index as r
    from read_vanilla_loc import _decompress
    out = []
    for pk in PACKS:
        fp = os.path.join(GAME, pk)
        if not os.path.isfile(fp):
            continue
        f, lst = r.entries(fp)
        for path, size, off, comp in lst:
            if not (path.startswith("ui/campaign ui/effect_bundles/")
                    and path.count("/") == 3 and path.endswith(".png")):
                continue
            f.seek(off)
            blob = f.read(size)
            try:
                im = Image.open(io.BytesIO(_decompress(blob) if comp else blob)).convert("RGBA")
            except Exception:                                   # noqa: BLE001
                continue
            if im.size == (SIZE, SIZE):
                out.append(np.asarray(im, dtype=float))
        f.close()
    if not out:
        raise SystemExit("no effect bundle icons read from %s" % GAME)
    return np.stack(out)


def _teal(A):
    rgb = A[..., :3] / 255.0
    a = A[..., 3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-9
    R, Gc, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == R, ((Gc - B) / d) % 6,
                 np.where(mx == Gc, (B - R) / d + 2, (R - Gc) / d + 4)) * 60
    s = d / (mx + 1e-9)
    return (h > 165) & (h < 215) & (s > 0.3) & (mx > 0.12) & (a > 200)


def fit_disc(A):
    """(cx, cy, r, shading coefficients) of CA's disc, and how many icons carry it."""
    teal = _teal(A)
    has = teal[:, 9:17, 3:5].mean((1, 2)) > 0.8
    T, tt = A[has], teal[has]
    ma = np.median(T[..., 3], 0)
    pts = []
    for y in range(SIZE):
        for x in range(SIZE):
            if ma[y, x] > 128 and (x < 12 or y > 15):
                nb = ((y, x + 1), (y, x - 1), (y + 1, x), (y - 1, x))
                if any(not (0 <= yy < SIZE and 0 <= xx < SIZE) or ma[yy, xx] <= 128
                       for yy, xx in nb):
                    pts.append((x + 0.5, y + 0.5))
    P = np.array(pts)
    X, Y = P[:, 0], P[:, 1]
    M = np.c_[2 * X, 2 * Y, np.ones(len(X))]
    a, b, c = np.linalg.lstsq(M, X ** 2 + Y ** 2, rcond=None)[0]
    r = float(np.sqrt(c + a * a + b * b))
    frac = tt.mean(0)
    ys, xs = np.where(frac >= 0.5)
    med = np.array([np.median(T[tt[:, y, x], y, x, :3], 0) for y, x in zip(ys, xs)])
    D = np.c_[np.ones(len(xs)), xs, ys, xs * xs, ys * ys, xs * ys]
    coef = np.linalg.lstsq(D, med, rcond=None)[0]
    # The colour of each pixel: measured where the disc shows, fitted where glyphs sit.
    colour = np.zeros((SIZE, SIZE, 3))
    for y in range(SIZE):
        for x in range(SIZE):
            if frac[y, x] >= 0.5:
                colour[y, x] = np.median(T[tt[:, y, x], y, x, :3], 0)
            else:
                colour[y, x] = np.clip(coef.T @ np.array([1, x, y, x * x, y * y, x * y]),
                                       0, 255)
    return float(a), float(b), r, colour, int(has.sum())


def draw_disc(cx, cy, r, colour, ss=4):
    """The disc at 24x24, supersampled. Teal to r-1.2, darkening to black by r-0.4, black
    to r+0.1, then a shadow fading out by r+1.2 - the radial profile measured off CA's."""
    out = np.zeros((SIZE, SIZE, 4))
    inner, dark, rim, shadow = r - 1.2, r - 0.4, r + 0.1, r + 1.2
    for y in range(SIZE):
        for x in range(SIZE):
            acc = np.zeros(4)
            for sy in range(ss):
                for sx in range(ss):
                    px, py = x + (sx + 0.5) / ss, y + (sy + 0.5) / ss
                    d = np.hypot(px - cx, py - cy)
                    col = colour[y, x]
                    if d < inner:
                        rgba = np.r_[col, 255.0]
                    elif d < dark:
                        rgba = np.r_[col * (1 - (d - inner) / (dark - inner)), 255.0]
                    elif d < rim:
                        rgba = np.array([0, 0, 0, 255.0])
                    elif d < shadow:
                        rgba = np.array([0, 0, 0, 255 * 0.4 * (shadow - d) / (shadow - rim)])
                    else:
                        rgba = np.zeros(4)
                    acc += np.r_[rgba[:3] * rgba[3] / 255.0, rgba[3]]
            acc /= ss * ss
            out[y, x] = np.r_[acc[:3] * 255.0 / max(acc[3], 1e-6), acc[3]]
    return Image.fromarray(out.clip(0, 255).astype("uint8"), "RGBA")


def compose(disc, glyph_path):
    """The disc, then the glyph's dark outline, then the glyph."""
    g = Image.open(glyph_path).convert("RGBA")
    bbox = g.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if bbox:
        g = g.crop(bbox)
    w, h = g.size
    k = GLYPH / float(max(w, h))
    g = g.resize((max(1, int(round(w * k))), max(1, int(round(h * k)))), Image.LANCZOS)
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gx = GLYPH_AT[0] + (GLYPH - g.width) // 2
    gy = GLYPH_AT[1] + (GLYPH - g.height) // 2
    layer.alpha_composite(g, (gx, gy))
    edge = layer.getchannel("A").filter(ImageFilter.MaxFilter(3))
    outline = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    outline.putalpha(edge.point(lambda v: int(v * 0.85)))
    out = disc.copy()
    out.alpha_composite(outline)
    out.alpha_composite(layer)
    return out


def wanted():
    """{icon file name: glyph source} for every icon the DB rows name."""
    out = {}
    for r in G.build()["effect_bundles"]:
        name = r.get("ui_icon") or ""
        if not name.startswith("derpy_gg_"):
            continue
        stem = name[len("derpy_gg_"):-len(".png")]
        src = "crest.png" if stem == "patron" else stem + ".png"
        out[name] = os.path.join(ICONS, src)
    return out


def write():
    A = ca_icons()
    cx, cy, r, coef, n = fit_disc(A)
    disc = draw_disc(cx, cy, r, coef)
    os.makedirs(OUT, exist_ok=True)
    todo = wanted()
    for name, src in sorted(todo.items()):
        compose(disc, src).save(os.path.join(OUT, name))
    print("disc fitted on %d of %d CA icons: centre (%.2f, %.2f), radius %.2f; wrote %d"
          % (n, len(A), cx, cy, r, len(todo)))


def check():
    out = []
    todo = wanted()
    if not todo:
        out.append("no effect bundle names a derpy_gg_ icon - the rows lost their ui_icon")
    for name, src in sorted(todo.items()):
        if not os.path.isfile(src):
            out.append("%s has no glyph source %s" % (name, src))
        p = os.path.join(OUT, name)
        if not os.path.isfile(p):
            out.append("%s is named by the DB and not staged - the bundle draws no icon" % name)
            continue
        im = Image.open(p)
        if im.size != (SIZE, SIZE) or im.mode != "RGBA":
            out.append("%s is %r %s, CA's are 24x24 RGBA" % (name, im.size, im.mode))
    staged = {n for n in os.listdir(OUT) if n.startswith("derpy_gg_")} if os.path.isdir(OUT) else set()
    for n in sorted(staged - set(todo)):
        out.append("%s is staged and no bundle names it - it would ship for nothing" % n)
    return out


def selftest():
    A = ca_icons()
    cx, cy, r, coef, n = fit_disc(A)
    # The fit is a measurement, so pin it loosely to what it measured on 9.0 - a wild
    # centre or radius means the teal test caught the wrong pixels, not a new disc.
    assert n > 300, "only %d icons read as carrying the disc" % n
    assert 10 < cx < 12 and 12 < cy < 14 and 9 < r < 11, (cx, cy, r)
    disc = np.asarray(draw_disc(cx, cy, r, coef), dtype=float)
    # Compared where no glyph reaches - the clean left arc, per channel against CA's
    # median. The FACE must match closely; the outer ring is an anti-aliased edge, where
    # a supersampled circle and CA's hand-drawn one differ by up to ~35 levels.
    teal = _teal(A)
    T = A[teal[:, 9:17, 3:5].mean((1, 2)) > 0.8]
    ref = np.median(T[:, 9:17, 2:6], 0)
    diff = np.abs(disc[9:17, 2:6] - ref).max(-1)
    yy, xx = np.mgrid[9:17, 2:6]
    face = np.hypot(xx + 0.5 - cx, yy + 0.5 - cy) < r - 1.2
    err, edge = diff[face].max(), diff[~face].max()
    assert err < 20, "the drawn disc's face is %d levels off CA's on the clean arc" % err
    assert edge < 45, "the drawn disc's rim is %d levels off CA's on the clean arc" % edge
    # And the checker notices a missing icon.
    todo = wanted()
    assert todo, "no icons wanted"
    print("selftest ok: disc from %d icons, clean arc off by %d on the face and %d on the "
          "rim, %d icons wanted" % (n, err, edge, len(todo)))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    elif "--check" in sys.argv:
        problems = check()
        for p in problems:
            print("PROBLEM: " + p)
        sys.exit(1 if problems else 0)
    else:
        write()
