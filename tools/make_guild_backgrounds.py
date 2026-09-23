"""Bake one panel background per guild out of the Chaos Dwarf reference art.

WHY A BAKE AND NOT A PATH IN THE .twui.xml. The panel's ground is image index 1 of four
on the panel component (tile, art, scrim, frame) and the campaign Lua swaps it with
SetImagePath as the player pages from guild to guild - the same idiom the card glyphs
already use. A runtime swap can only reach a file that ships, and none of the reference
pictures is shippable as it stands: they are 1920px JPEGs at 1.5:1 to 2.7:1 with a
WARHAMMER III logo and an ArtStation URL burnt into the bottom strip.

BRIGHTNESS IS THE GATE, NOT TASTE. The Help tab draws twenty-one lines of body text
straight onto the panel ground with no plate between, so the shipped ground was chosen on
what it measures under the panel's 0x77 scrim, not on how it looks: p99 luminance 34, peak
131. Measured the same way, EVERY picture in the reference folder is brighter - the darkest
is p99 55 and most are 70 to 95 - so shipping any of them raw would leave that text sitting
on a ground half again as bright as the one it was made readable against. Each picture is
therefore multiplied down until it measures at or under what today's ground measures, which
is what makes "the background now changes" a change to the picture only and not to whether
anything on top of it can still be read.

The ceiling is READ OFF THE SHIPPED GROUND, not typed in here, so it tracks if that art is
ever replaced. `tools/preview_guilds_panel.py --check` is what puts that file on disk.

    py tools/make_guild_backgrounds.py            # write the pack copies
    py tools/make_guild_backgrounds.py --check    # measure what ships, write nothing
    py tools/make_guild_backgrounds.py --selftest
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Modding Files", "reference")
# lowercase only - since patch 6.1 an uppercase character in a pack path crashes.
DST = os.path.join(ROOT, "Modding Files", "pack", "ui", "campaign ui", "derpy_gg_bg")
IN_PACK = "ui/campaign ui/derpy_gg_bg/%s.png"

# The reference ground, extracted out of CA's ui packs by preview_guilds_panel.py.
GROUND = os.path.join(ROOT, ".skilltree_cache", "ui_preview", "ui", "skins", "default",
                      "dlc23_tower_of_zharr", "tier_01_background.png")
# What that file measured on 2026-09-12, used only when it is not on disk.
GROUND_FALLBACK = (34.0, 131.0)

PANEL_W, PANEL_H = 790, 700
SCRIM_ALPHA = 0x77 / 255.0        # the panel's own scrim, black at 0x77

# THE BOTTOM STRIP IS NOT PICTURE. Every one of these carries CA's WARHAMMER III logo
# and the artist's ArtStation URL across the bottom; the crop below removes it before
# anything else, because a cover-crop of a wide source trims the WIDTH and would keep
# that strip in full.
#
# 0.16 and not the 0.09 this started at, MEASURED OFF THE BAKE: at 9% the logo's crown
# still sat in the bottom centre of five of the six grounds - faint under the scrim,
# entirely readable once you had seen it. The logo is a good deal taller than the black
# strip it sits on, so the number has to clear the artwork, not the strip.
FOOTER = 0.16

# guild -> (file in Modding Files/reference, where to take the crop from: 0 left/top,
# 0.5 centred, 1 right/bottom). Content first, then measured brightness - a picture that
# has to be multiplied by 0.4 to pass the gate arrives on screen as a dark smudge.
BACKGROUNDS = {
    "brass":        ("alex-voysey-chd-zharr-n-3c.jpg", 0.5),
    "immortals":    ("nedim-can-chd-showreel04.jpg", 0.5),
    "daemonsmiths": ("morgan-ketelaar-jarass-wh3-chd-hellforge.jpg", 0.5),
    "khanate":      ("ashley-heppell-ashley-heppell-wh3-dlc-environment-art-chaos-"
                     "dwarfs-3.jpg", 0.5),
    "overseers":    ("simon-tosovsky-simon-tosovsky-factories.jpg", 0.5),
    "slavers":      ("alex-voysey-chd-underground-7.jpg", 0.5),
}


def measure(im):
    """(p99, peak) luminance at panel size under the panel's scrim.

    p99 and not the mean: what makes text unreadable is the bright end. A picture that
    averages 20 with a white-hot furnace mouth in it is not a dark picture.
    """
    from PIL import Image
    if im.size != (PANEL_W, PANEL_H):
        im = im.resize((PANEL_W, PANEL_H), Image.LANCZOS)
    lum = im.convert("L")
    hist = lum.histogram()
    total = sum(hist)
    p99, run = 255, 0
    for v, c in enumerate(hist):
        run += c
        if run >= total * 0.99:
            p99 = v
            break
    peak = max(v for v, c in enumerate(hist) if c)
    k = 1.0 - SCRIM_ALPHA
    return p99 * k, peak * k


def ceiling():
    """What the shipped ground measures - the bar every baked picture has to clear."""
    from PIL import Image
    if os.path.isfile(GROUND):
        return measure(Image.open(GROUND).convert("RGB")), GROUND
    return GROUND_FALLBACK, None


def trim_letterbox(im, floor=12):
    """Drop the black cinematic bars some of the showreel stills are rendered inside.

    They are part of the FILE and not of the picture, and left in place they push the
    crop off centre and then get scaled up into two grey bands across a panel.
    """
    lum = im.convert("L")
    w, h = im.size
    rows = [lum.crop((0, y, w, y + 1)).getextrema()[1] for y in range(h)]
    top = 0
    while top < h and rows[top] < floor:
        top += 1
    bot = h
    while bot > top + 1 and rows[bot - 1] < floor:
        bot -= 1
    # A PICTURE THAT IS ENTIRELY UNDER THE FLOOR IS NOT ALL BARS. Trimming it would
    # return a zero-height crop, and every later step would fail somewhere less obvious.
    if top >= bot - 1:
        return im
    return im.crop((0, top, w, bot)) if (top or bot != h) else im


def frame(im, anchor=0.5):
    """Drop the bars and the logo strip, then cover-crop to panel size."""
    from PIL import Image
    im = trim_letterbox(im.convert("RGB"))
    w, h = im.size
    cut = int(h * FOOTER)
    im = im.crop((0, 0, w, h - cut))
    w, h = im.size
    par = PANEL_W / float(PANEL_H)
    if w / float(h) > par:                      # wider than the panel: trim the sides
        nw = int(round(h * par))
        x = int(round((w - nw) * anchor))
        im = im.crop((x, 0, x + nw, h))
    else:                                       # taller: trim top and bottom
        nh = int(round(w / par))
        y = int(round((h - nh) * anchor))
        im = im.crop((0, y, w, y + nh))
    return im.resize((PANEL_W, PANEL_H), Image.LANCZOS)


def darken(im, max_p99, max_peak):
    """Multiply the picture down until it measures inside the ground's numbers.

    A flat multiply and not a curve: it is the one transform that cannot invent contrast
    where the picture has none, and the scrim it is being fitted under is itself a
    multiply. Returns (image, factor) - factor 1.0 means it already passed.
    """
    lo, hi = 0.05, 1.0
    p99, peak = measure(im)
    if p99 <= max_p99 and peak <= max_peak:
        return im, 1.0
    for _ in range(24):                          # bisect; 24 rounds is well under a step
        mid = (lo + hi) / 2.0
        test = im.point(lambda v, m=mid: int(v * m))
        p99, peak = measure(test)
        if p99 <= max_p99 and peak <= max_peak:
            lo = mid
        else:
            hi = mid
    f = lo
    return im.point(lambda v, m=f: int(v * m)), f


def build(write=True):
    from PIL import Image
    out, made = [], []
    (max_p99, max_peak), ground = ceiling()
    if ground is None:
        out.append("NOTE: %s is not on disk, so the ceiling is the 2026-09-12 "
                   "measurement (p99 %.0f, peak %.0f) rather than a fresh one. "
                   "`py tools/preview_guilds_panel.py --check` extracts it."
                   % (GROUND, max_p99, max_peak))
    if write and not os.path.isdir(DST):
        os.makedirs(DST)
    for guild in sorted(BACKGROUNDS):
        fname, anchor = BACKGROUNDS[guild]
        src = os.path.join(SRC, fname)
        if not os.path.isfile(src):
            out.append("%s: no such reference picture: %s" % (guild, src))
            continue
        im, factor = darken(frame(Image.open(src), anchor), max_p99, max_peak)
        p99, peak = measure(im)
        if p99 > max_p99 + 0.5 or peak > max_peak + 0.5:
            # Bisection cannot fail on a picture with any dark in it at all, so this
            # means the source is flat bright - a picture with no ground in it.
            out.append("%s: %s cannot be darkened into the ground's numbers (p99 %.0f "
                       "of %.0f, peak %.0f of %.0f) - pick another picture"
                       % (guild, fname, p99, max_p99, peak, max_peak))
            continue
        dst = os.path.join(DST, guild + ".png")
        if write:
            im.save(dst, optimize=True)
        made.append((guild, fname, factor, p99, peak,
                     os.path.getsize(dst) if os.path.isfile(dst) else 0))
    return out, made


def check():
    """Measure the files that SHIP, not the ones a rebuild would produce.

    The bake and the pack are separate steps, so a picture swapped in the source folder,
    or a file edited by hand, is invisible to anything that only re-runs build().
    """
    from PIL import Image
    out = []
    (max_p99, max_peak), _ = ceiling()
    for guild in sorted(BACKGROUNDS):
        path = os.path.join(DST, guild + ".png")
        if not os.path.isfile(path):
            out.append("%s: %s does not ship - the Lua's SetImagePath would silently "
                       "draw nothing" % (guild, IN_PACK % guild))
            continue
        im = Image.open(path).convert("RGB")
        if im.size != (PANEL_W, PANEL_H):
            out.append("%s: ships at %dx%d, not the panel's %dx%d"
                       % (guild, im.size[0], im.size[1], PANEL_W, PANEL_H))
        p99, peak = measure(im)
        if p99 > max_p99 + 0.5 or peak > max_peak + 0.5:
            out.append("%s: measures p99 %.0f / peak %.0f under the scrim against the "
                       "ground's %.0f / %.0f - the Help tab's unplated text loses its "
                       "contrast on this guild" % (guild, p99, peak, max_p99, max_peak))
    return out


def selftest():
    from PIL import Image
    # the frame drops the logo strip and returns panel size, whatever went in
    for size in ((1920, 1080), (1920, 821), (1024, 1326)):
        got = frame(Image.new("RGB", size, (40, 30, 20)))
        assert got.size == (PANEL_W, PANEL_H), (size, got.size)
    # letterbox bars go, and only the bars: a picture with no bars is returned whole
    boxed = Image.new("RGB", (100, 100), (0, 0, 0))
    boxed.paste(Image.new("RGB", (100, 60), (90, 80, 70)), (0, 20))
    assert trim_letterbox(boxed).size == (100, 60), trim_letterbox(boxed).size
    plain = Image.new("RGB", (100, 100), (90, 80, 70))
    assert trim_letterbox(plain).size == (100, 100)
    # an all-black picture must not be trimmed to nothing
    assert trim_letterbox(Image.new("RGB", (10, 10), (0, 0, 0))).size[1] >= 1
    # and it takes the crop where the anchor says: a left-anchored crop of a wide
    # picture keeps the left edge's colour, a right-anchored one the right edge's.
    wide = Image.new("RGB", (2000, 1000), (0, 0, 0))
    wide.paste(Image.new("RGB", (200, 1000), (255, 0, 0)), (0, 0))
    wide.paste(Image.new("RGB", (200, 1000), (0, 255, 0)), (1800, 0))
    assert frame(wide, 0.0).getpixel((2, 10))[0] > 200, "left anchor lost the left edge"
    assert frame(wide, 1.0).getpixel((PANEL_W - 3, 10))[1] > 200, "right anchor"
    # darken hits the ceiling rather than merely moving towards it
    bright = Image.new("RGB", (PANEL_W, PANEL_H), (200, 200, 200))
    got, f = darken(bright, 34.0, 131.0)
    p99, peak = measure(got)
    assert p99 <= 34.5 and peak <= 131.5, (p99, peak, f)
    assert f < 1.0, f
    # a picture already inside the numbers is left alone, not darkened anyway
    dark = Image.new("RGB", (PANEL_W, PANEL_H), (20, 20, 20))
    got, f = darken(dark, 34.0, 131.0)
    assert f == 1.0, f
    # THE GATE MUST REFUSE SOMETHING. A check that cannot fail is not a check: bake a
    # deliberately bright file over one of the shipped names and require a finding.
    keep = os.path.join(DST, "brass.png")
    backup = keep + ".selftest_bak"
    if os.path.isfile(keep):
        os.rename(keep, backup)
    try:
        if not os.path.isdir(DST):
            os.makedirs(DST)
        Image.new("RGB", (PANEL_W, PANEL_H), (220, 220, 220)).save(keep)
        bad = check()
        assert any("loses its contrast" in b for b in bad), bad
        # ... and a missing file is a finding too, since that is the silent one
        os.remove(keep)
        bad = check()
        assert any("does not ship" in b for b in bad), bad
    finally:
        if os.path.isfile(keep):
            os.remove(keep)
        if os.path.isfile(backup):
            os.rename(backup, keep)
    print("selftest ok: crop, anchor, ceiling reached, bright file and missing file "
          "both refused")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    if "--check" in sys.argv:
        problems = check()
        for p in problems:
            print("PROBLEM: " + p)
        (mp, mk), g = ceiling()
        print("ceiling: p99 %.0f / peak %.0f%s" % (mp, mk, g and " (measured)" or ""))
        sys.exit(1 if problems else 0)
    problems, made = build()
    for p in problems:
        print(("NOTE: " in p and p or "PROBLEM: " + p))
    total = 0
    for guild, fname, factor, p99, peak, size in made:
        total += size
        print("  %-13s x%.2f  p99 %4.1f  peak %5.1f  %6.1f KB  <- %s"
              % (guild, factor, p99, peak, size / 1024.0, fname[:44]))
    print("  %-13s %38.1f KB" % ("total", total / 1024.0))
    sys.exit(1 if [p for p in problems if not p.startswith("NOTE")] else 0)
