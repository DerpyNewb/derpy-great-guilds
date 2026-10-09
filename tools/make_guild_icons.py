"""Recolour The Great Guilds' card icons so they read on a dark panel.

WHY THIS EXISTS. CA's building icons are FLAT SILHOUETTES: measured on
chd_factory_port.png, every visible pixel carries exactly one RGB value,
(11, 40, 65), and all of the shape plus its anti-aliasing lives in 200 levels of
alpha. Their peak alpha is 204, not 255, so they are semi-transparent as well.
CA tints them at draw time on its own building panels. Drawn raw on ours they were
a dark navy glyph at 80% opacity on a near-black card - legible only just.

TINTING IN THE .twui.xml CANNOT FIX IT. A layer `colour` MULTIPLIES: that is why
1x1_blank_white.png tinted #C8A05AFF gives a gold bar. Multiplying a value of 40 by
anything only ever makes it darker. The pixels have to change.

THE TRANSFORM, and why it is lossless in the way that matters:
  * RGB  := one bright constant. The source has a single RGB value, so replacing it
            uniformly loses nothing at all - there is no detail in those channels.
  * A    := scaled so the peak becomes fully opaque, relative levels preserved.
            Shape and edge anti-aliasing are untouched.

The recoloured files ship under our OWN path. Writing them back over
ui/buildings/icons/ would override CA's icons everywhere in the game - every
building panel, not just this one.

    py tools/make_guild_icons.py            # write the pack copies
    py tools/make_guild_icons.py --check    # report only, write nothing
    py tools/make_guild_icons.py --selftest
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Modding Files", "source", "guild_icons")
# lowercase only - since patch 6.1 an uppercase character in a pack path crashes.
DST = os.path.join(ROOT, "Modding Files", "pack", "ui", "campaign ui", "derpy_gg_icons")
IN_PACK = "ui/campaign ui/derpy_gg_icons/%s.png"

# The panel's own label colour, so a glyph and the text beside it are the same ink.
INK = (255, 248, 215)

# source stem -> the name we ship it under. The shipped name says what the icon IS
# for this mod, not which CA building it was borrowed from.
ICONS = {
    "chd_factory_port": "brass",
    "chd_military_chaos_dwarf_infantry": "immortals",
    "chd_factory_furnace": "daemonsmiths",
    "chd_military_hobgoblins": "khanate",
    "chd_outpost_overseer_hut": "overseers",
    "chd_outpost_raiding_camp": "slavers",
    "chd_tower_tribute_halls": "crest",
    # EMPIRE and DWARFS. CA's own building icons for the same six trades, each measured a
    # flat silhouette (commonest colour 100% of visible pixels, 74x74, 2026-09-23).
    # dwarf_hall_of_oaths (51%) and dwf_underdeep_grudges (69%) were the first picks and
    # are textured - build() refuses them, which is why the crest and the Grudge-Settlers
    # are the Karaz-a-Karak and slayer-cult icons instead.
    "empire_port": "brass_emp",
    "empire_barracks": "immortals_emp",
    "empire_gunnery_school": "daemonsmiths_emp",
    "empire_tavern": "khanate_emp",
    "empire_walls": "overseers_emp",
    "empire_shooting_range": "slavers_emp",
    "empire_imperial_cult": "crest_emp",
    "dwarf_trade_depot": "brass_dwf",
    "dwarf_barracks": "immortals_dwf",
    "dwarf_engineering": "daemonsmiths_dwf",
    "dwarf_rangers": "khanate_dwf",
    "dwarf_industry": "overseers_dwf",
    "dwarf_slayer_cult": "slavers_dwf",
    "dwarf_city_karaz_a_karak": "crest_dwf",
    # EVERY OTHER RACE. Icons that belong to no one race's building line, or whose
    # picture reads as the trade and not the builder: a handshake shield, crossed swords
    # on a banner, an anvil, crossed daggers, a quarried block, a loot pile, and a plain
    # heraldic shield for the crest. Each measured a flat silhouette, 2026-09-24.
    "war_coordination_outpost": "brass_gen",
    "wh_main_emp_academy": "immortals_gen",
    "special_vauls_anvil": "daemonsmiths_gen",
    "minor_cult_assassins_hideout": "khanate_gen",
    "wh2_dlc15_special_massif_orcal_quarry": "overseers_gen",
    "ogre_camp_loot_pile": "slavers_gen",
    "minor_cult_tilean_traders": "crest_gen",
    # BRETONNIA, CATHAY AND KISLEV, each from its own race's building line. Picked from a
    # rendered sheet of every candidate, 2026-09-24; all 21 measure 97-100% one colour.
    "bretonnia_bordeleaux_wine_market": "brass_brt",
    "bretonnia_tournament_grounds": "immortals_brt",
    "bretonnia_tower_of_the_enchantress": "daemonsmiths_brt",
    "bretonnia_tavern": "khanate_brt",
    "bretonnia_carpenter": "overseers_brt",
    "bretonnia_barracks": "slavers_brt",
    "bretonnia_worship": "crest_brt",
    "cathay_gold_yin": "brass_cth",
    "cathay_celestial_barracks": "immortals_cth",
    "cathay_growth_yin": "daemonsmiths_cth",
    "cathay_shang_yang_house_of_secrets": "khanate_cth",
    "cathay_walls_yang": "overseers_cth",
    "cathay_jade_barracks": "slavers_cth",
    "cathay_special_celestial_palace": "crest_cth",
    "kislev_erengrad_trading_port": "brass_ksl",
    "kislev_royal_guards_prologue": "immortals_ksl",
    "kislev_frosthome": "daemonsmiths_ksl",
    "kislev_trade_order": "khanate_ksl",
    "kislev_timber_prologue": "overseers_ksl",
    "kislev_ungol_quarters": "slavers_ksl",
    "kislev_bears": "crest_ksl",
    # DARK ELVES AND HIGH ELVES, from their own building lines, 2026-09-24. All fourteen
    # measure 98-100% one colour. dark_elves_sorcery would suit the Convent better but is
    # 70% - textured - so the Convent is dark_elves_cold_ones, a spired tower. The High
    # Elves' White Tower (high_elves_mages) and Phoenix Crown chamber are flat but drawn
    # inside a haze and a filled square, which read as boxes at 74px; the Loremasters get
    # the scroll and quill instead, and the crest the lone phoenix.
    "dark_elves_port": "brass_def",
    "dark_elves_barracks": "immortals_def",
    "dark_elves_cold_ones": "daemonsmiths_def",
    "dark_elves_hired_killers": "khanate_def",
    "dark_elves_defence_major": "overseers_def",
    "dark_elves_slaves": "slavers_def",
    "dark_elves_worship": "crest_def",
    "hef_foreign_trade_market": "brass_hef",
    "high_elves_barracks": "immortals_hef",
    "high_elves_embassy": "daemonsmiths_hef",
    "high_elves_aesanar": "khanate_hef",
    "high_elves_defence_major": "overseers_hef",
    "high_elves_stables": "slavers_hef",
    "hef_sea_patrol_outpost_beasts": "crest_hef",
    # THE TEMPLE (2026-10-04), one CA temple or college icon per race, each measured a flat
    # silhouette (100% one colour, 74x74) before it was picked.
    "chd_tower_temple_of_hashut": "temple",
    "empire_altdorf_college": "temple_emp",
    "special_ancestors_hall": "temple_dwf",
    "bretonnia_abbey_of_the_grail_companions": "temple_brt",
    "wh3_main_special_cth_li_temple": "temple_cth",
    "kislev_great_orthodoxy": "temple_ksl",
    "special_har_ganeth_temple_of_khaine": "temple_def",
    "high_elves_worship": "temple_hef",
    "minor_cult_shallya": "temple_gen",
    # THE SKAVEN (2026-10-05), CA's own Skaven building icons, each measured flat by build().
    # Not the warpstone refinery: its commonest colour is 38% of its pixels, not a silhouette.
    "skaven_resource_gold": "brass_skv",
    "skaven_stormvermin": "immortals_skv",
    "skaven_engineers": "daemonsmiths_skv",
    "skaven_assassins": "khanate_skv",
    "skaven_breeding": "overseers_skv",
    "skaven_slaves": "slavers_skv",
    "wh3_dlc29_skv_scruten_landmark": "temple_skv",
    "wh2_main_special_skavenblight_council13": "crest_skv",
}

# THE SIX HALL ICONS (2026-10-04). building_culture_variants.icon names a file in
# ui/buildings/icons/, which CA TINTS AT DRAW TIME - so these are CA's own flat silhouettes
# copied under our names, not recoloured like the panel's cards above. Same six source
# silhouettes as the cards, so a guild's hall and its card read as one trade. CA-derived art:
# ships in the pack only, never in the public repo (.gitignore blocks images).
HALL_ICONS = {
    "chd_factory_port": "derpy_gg_hall_brass",
    "chd_military_chaos_dwarf_infantry": "derpy_gg_hall_immortals",
    "chd_factory_furnace": "derpy_gg_hall_daemonsmiths",
    "chd_military_hobgoblins": "derpy_gg_hall_khanate",
    "chd_outpost_overseer_hut": "derpy_gg_hall_overseers",
    "chd_outpost_raiding_camp": "derpy_gg_hall_slavers",
    "chd_tower_temple_of_hashut": "derpy_gg_hall_temple",
}
# STAGE 2: the other seven races' halls (42 icons). Each race's card icons above already come
# from that race's own building line, so the hall takes the SAME source stem as its guild's
# card - read off ICONS rather than retyped, so the two cannot drift apart.
_CARD_STEM = {name: stem for stem, name in ICONS.items()}
_GUILDS = ("brass", "immortals", "daemonsmiths", "khanate", "overseers", "slavers", "temple")
# PER-LEVEL HALL ICONS (2026-10-08): races whose halls draw one icon PER LEVEL, the way
# Medieval II's guild pictures grow with each upgrade. Codex drew each set from the M2 line
# (source/guild_icons/codex_<g><tag>/, made by to_ca_icon.py there) and they ship under the
# LEVEL's key, derpy_gg_hall_<g>_<n><tag>. Must match gen_great_guilds.HALL_LEVEL_ICON_TAGS -
# import_great_guilds refuses a build whose variant rows name an icon that is not staged.
HALL_LEVEL_ICON_TAGS = ("_emp", "_dwf", "")
HALL_LEVEL_ICONS = {
    os.path.join(SRC, "codex_%s%s" % (_g, _tag), "derpy_gg_hall_%s%s_%d.png" % (_g, _tag, _n + 1)):
        "derpy_gg_hall_%s_%d%s" % (_g, _n, _tag)
    for _tag in HALL_LEVEL_ICON_TAGS for _g in _GUILDS for _n in range(3)}
for _tag in ("_emp", "_dwf", "_brt", "_cth", "_ksl", "_def", "_hef", "_skv"):
    for _g in _GUILDS:
        HALL_ICONS[_CARD_STEM[_g + _tag]] = "derpy_gg_hall_" + _g + _tag
# A per-level race's one-per-chain icon is retired (build_halls deletes it), so never copy it.
_RETIRED = {"derpy_gg_hall_%s%s" % (_g, _t) for _t in HALL_LEVEL_ICON_TAGS for _g in _GUILDS}
HALL_ICONS = {k: v for k, v in HALL_ICONS.items() if v not in _RETIRED}
HALL_DST = os.path.join(ROOT, "Modding Files", "pack", "ui", "buildings", "icons")

UI_PACK = os.path.join(r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III",
                       "data", "ui.pack")
CA_ICON = "ui/buildings/icons/%s.png"


def fetch(stem):
    """Copy CA's original of one source icon into SRC, read offline out of ui.pack.

    CA's ui art is COMPRESSED in the pack - a u32 length and then a zstd frame - so a
    byte-grep finds the path and not a usable PNG; read_vanilla_loc._decompress strips
    that wrapper. Returns None on success, or why it could not.
    """
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import read_pack_index as rpi
    import read_vanilla_loc as rvl
    want = CA_ICON % stem
    try:
        hits = [h for h in rpi.read(UI_PACK, want) if h[0].lower() == want]
    except (IOError, OSError, ValueError) as e:
        return "cannot read %s: %s" % (UI_PACK, e)
    if not hits:
        return "%s is not in %s" % (want, UI_PACK)
    _path, comp, data = hits[0]
    if comp:
        data = rvl._decompress(data)
    if not os.path.isdir(SRC):
        os.makedirs(SRC)
    with open(os.path.join(SRC, stem + ".png"), "wb") as fh:
        fh.write(data)
    return None


def brighten(im, ink=INK):
    """Flat-recolour to `ink` and lift peak alpha to fully opaque. Shape untouched."""
    im = im.convert("RGBA")
    r, g, b, a = im.split()
    peak = a.getextrema()[1]
    assert peak > 0, "icon is fully transparent"
    scale = 255.0 / peak
    a = a.point(lambda v: min(255, int(round(v * scale))))
    from PIL import Image
    flat = [Image.new("L", im.size, c) for c in ink]
    return Image.merge("RGBA", (flat[0], flat[1], flat[2], a))


# SHIPPED AT 2x. CA ships these at 74px only, and the card draws its glyph at 62 - so at
# 125-150% UI scale the engine was upscaling a 74px file to 78-93px, which is what read as
# blurry in game (2026-09-30). The shape is all alpha, so the alpha is enlarged 4x smoothly,
# its edge ramp steepened by EDGE about the midpoint (what a vector edge would be), then
# box-reduced to 2x so the edge keeps anti-aliasing. EDGE 2 keeps every stroke CA drew:
# only pixels under alpha 64 - the outer half of the source's own anti-aliasing - drop out.
UPSCALE, EDGE = 2, 2.0


def upscale(im, k=UPSCALE, edge=EDGE):
    """A flat-ink silhouette at k times the size, with crisp anti-aliased edges."""
    from PIL import Image
    a = im.getchannel("A")
    w, h = a.size
    big = a.resize((w * 4, h * 4), Image.LANCZOS)
    big = big.point(lambda v: max(0, min(255, int(round((v - 128) * edge + 128)))))
    a = big.resize((w * k, h * k), Image.BOX)
    flat = [Image.new("L", a.size, c) for c in im.getpixel((0, 0))[:3]]
    return Image.merge("RGBA", flat + [a])


def build(write=True):
    from PIL import Image
    out, made = [], []
    if not os.path.isdir(SRC):
        return ["no source icons at %s" % SRC], []
    if write and not os.path.isdir(DST):
        os.makedirs(DST)
    for stem, name in sorted(ICONS.items()):
        src = os.path.join(SRC, stem + ".png")
        if not os.path.isfile(src) and write:
            why = fetch(stem)
            if why:
                out.append("%s: %s" % (stem, why))
                continue
        if not os.path.isfile(src):
            out.append("missing source icon: %s" % src)
            continue
        im = Image.open(src)
        w, h = im.size
        new = brighten(im)
        # A SILHOUETTE MUST STAY A SILHOUETTE. If the source ever stops being flat,
        # this transform would be throwing away real colour detail, so say so rather
        # than quietly flattening a detailed icon.
        px = im.convert("RGBA").load()
        vis = [(px[x, y][0], px[x, y][1], px[x, y][2])
               for y in range(h) for x in range(w) if px[x, y][3] > 32]
        # SHARE, not distinct count. chd_factory_furnace is 2,172 pixels of one
        # colour plus FOUR stray edge pixels; counting distinct values called that
        # "not a silhouette" and refused an icon that plainly is one. What matters is
        # whether replacing the colour throws away anything a player could see.
        import collections
        top, n = collections.Counter(vis).most_common(1)[0]
        share = float(n) / max(len(vis), 1)
        if share < 0.95:
            out.append("%s: its commonest colour is only %.0f%% of the visible "
                       "pixels, so it is not a silhouette and recolouring it would "
                       "discard detail" % (stem, share * 100))
            continue
        new = upscale(new)
        w, h = new.size
        if write:
            new.save(os.path.join(DST, name + ".png"))
        made.append((IN_PACK % name, w, h))
    # gen_guilds_ui.check() refuses an icon drawn larger than the size recorded here, so
    # the record follows the files rather than being hand-edited.
    if write and made:
        import json
        jp = os.path.join(ROOT, "tools", "ui_icon_sizes.json")
        sizes = json.load(io.open(jp, encoding="utf-8"))
        sizes.update({p: w for p, w, _h in made})
        with io.open(jp, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(sizes, indent=1, sort_keys=True) + "\n")
    return out, made


def build_halls(write=True):
    """Copy each hall icon's CA source (fetched offline if missing) to ui/buildings/icons/."""
    out = []
    if write and not os.path.isdir(HALL_DST):
        os.makedirs(HALL_DST)
    for stem, name in sorted(HALL_ICONS.items()):
        src = os.path.join(SRC, stem + ".png")
        if not os.path.isfile(src) and write:
            why = fetch(stem)
            if why:
                out.append("%s: %s" % (stem, why))
                continue
        if not os.path.isfile(src):
            out.append("missing source icon: %s" % src)
            continue
        data = open(src, "rb").read()
        if write:
            with open(os.path.join(HALL_DST, name + ".png"), "wb") as fh:
                fh.write(data)
        elif not os.path.isfile(os.path.join(HALL_DST, name + ".png")):
            out.append("hall icon not written: %s.png" % name)
    for src, name in sorted(HALL_LEVEL_ICONS.items()):
        dst = os.path.join(HALL_DST, name + ".png")
        if not os.path.isfile(src):
            out.append("missing per-level hall icon: %s" % src)
        elif write:
            with open(dst, "wb") as fh:
                fh.write(open(src, "rb").read())
        elif not os.path.isfile(dst) or open(dst, "rb").read() != open(src, "rb").read():
            out.append("per-level hall icon not staged or stale: %s.png" % name)
    # A retired one-per-chain icon would still be packed (the importer takes every
    # derpy_gg_hall_*.png), so delete it.
    for tag in HALL_LEVEL_ICON_TAGS:
        for g in _GUILDS:
            old = os.path.join(HALL_DST, "derpy_gg_hall_%s%s.png" % (g, tag))
            if os.path.isfile(old):
                if write:
                    os.remove(old)
                else:
                    out.append("retired hall icon still staged: %s" % os.path.basename(old))
    return out


# THE EIGHT TAB ICONS (2026-10-04). building_sets.icon of derpy_gg_set_guild_halls<tag> is a
# construction-panel TAB and takes a FULL lowercase path (docs/sessions/
# HANDOFF_20260902_ADMIRAL_AND_HERO_RECRUITMENT.md 9.1). Every CA category tab is a 64x64
# parchment scroll with a glyph in the category's ink (red recruitment, purple support,
# green civic). Each tab here is the race's OWN category scroll with the glyph painted out
# and the race's guild crest drawn in GOLD, an ink no CA tab uses, so it reads as a tab of
# that race and as a different tab from its neighbours. CA-derived: pack only.
TAB_FRAME = {
    "": "chd_cat_advanced_military", "_emp": "empire_cat_support",
    "_dwf": "dwarf_cat_support", "_brt": "empire_cat_recruitment",
    "_cth": "cathay_cat_military", "_ksl": "kislev_cat_support",
    "_def": "dark_elves_cat_recruitment", "_hef": "high_elves_cat_recruitment",
    "_skv": "skaven_cat_recruitment",
}
TAB_INK = (150, 100, 14)
TAB_GLYPH = 36                  # px square the crest is fitted into, inside a 64px scroll
TAB_DST = HALL_DST
TAB_CAT_SRC = os.path.join(SRC, "cat")
CA_TAB = "ui/buildings/icons/%s.png"


def tab_name(tag):
    return "derpy_gg_tab_halls" + tag


def tab_path(tag):
    """The building_sets.icon value: a full lowercase pack path."""
    return "ui/buildings/icons/%s.png" % tab_name(tag)


def _fetch_to(stem, folder):
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import read_pack_index as rpi
    import read_vanilla_loc as rvl
    want = CA_TAB % stem
    hits = [h for h in rpi.read(UI_PACK, want) if h[0].lower() == want]
    if not hits:
        return "%s is not in %s" % (want, UI_PACK)
    _p, comp, data = hits[0]
    if comp:
        data = rvl._decompress(data)
    if not os.path.isdir(folder):
        os.makedirs(folder)
    with open(os.path.join(folder, stem + ".png"), "wb") as fh:
        fh.write(data)
    return None


def paint_out_glyph(frame):
    """The scroll with its glyph removed. Inside the paper box (between the rollers and the
    side margins) a pixel far from the paper's own colour is glyph ink; the mask is grown by
    two pixels and every masked pixel takes the mean of a straight-line fill across its gap
    along the row and along the column, from the paper either side."""
    import numpy as np
    from PIL import Image, ImageFilter
    im = frame.convert("RGBA")
    w, h = im.size
    arr = np.array(im).astype(float)
    x0, x1, y0, y1 = int(w * 0.17), int(w * 0.83), int(h * 0.15), int(h * 0.86)
    box = arr[y0:y1, x0:x1, :3]
    lum = box.sum(axis=2)
    ref = np.median(box[lum >= np.percentile(lum, 60)].reshape(-1, 3), axis=0)
    dist = np.abs(box - ref).sum(axis=2)
    mask = Image.fromarray(((dist > 40) * 255).astype("uint8")).filter(ImageFilter.MaxFilter(5))
    mask = np.array(mask) > 0
    fill = box.copy()
    hh, ww = mask.shape
    hor, ver = box.copy(), box.copy()
    hv, vv = np.zeros(mask.shape, bool), np.zeros(mask.shape, bool)   # a line with paper left
    for y in range(hh):
        ok = ~mask[y]
        if ok.any():
            hv[y, :] = True
            for c in range(3):
                hor[y, :, c] = np.interp(np.arange(ww), np.nonzero(ok)[0], box[y, ok, c])
    for x in range(ww):
        ok = ~mask[:, x]
        if ok.any():
            vv[:, x] = True
            for c in range(3):
                ver[:, x, c] = np.interp(np.arange(hh), np.nonzero(ok)[0], box[ok, x, c])
    # both directions where both have paper, else the one that has; a pixel with neither
    # (a glyph wider than the box in both) keeps the paper reference colour
    both = hv & vv
    est = np.where(both[..., None], (hor + ver) / 2.0,
                   np.where(hv[..., None], hor, np.where(vv[..., None], ver, ref)))
    fill[mask] = est[mask]
    arr[y0:y1, x0:x1, :3] = fill
    return Image.fromarray(arr.round().clip(0, 255).astype("uint8"), "RGBA")


def make_tab(tag):
    from PIL import Image
    frame = Image.open(os.path.join(TAB_CAT_SRC, TAB_FRAME[tag] + ".png"))
    crest = Image.open(os.path.join(SRC, _CARD_STEM["crest" + tag] + ".png")).convert("RGBA")
    out = paint_out_glyph(frame)
    a = crest.getchannel("A")
    bbox = a.point(lambda v: 255 if v > 32 else 0).getbbox()
    a = a.crop(bbox)
    k = TAB_GLYPH / float(max(a.size))
    a = a.resize((max(1, int(round(a.size[0] * k))), max(1, int(round(a.size[1] * k)))),
                 Image.LANCZOS)
    # the paper's centre, same box paint_out_glyph used
    w, h = out.size
    cx, cy = w // 2, (int(h * 0.15) + int(h * 0.86)) // 2
    ink = Image.new("RGBA", a.size, TAB_INK + (255,))
    ink.putalpha(a.point(lambda v: v))
    out.alpha_composite(ink, (cx - a.size[0] // 2, cy - a.size[1] // 2))
    return out


def build_tabs(write=True):
    out = []
    if write and not os.path.isdir(TAB_DST):
        os.makedirs(TAB_DST)
    for tag in sorted(TAB_FRAME):
        fr = os.path.join(TAB_CAT_SRC, TAB_FRAME[tag] + ".png")
        if not os.path.isfile(fr) and write:
            why = _fetch_to(TAB_FRAME[tag], TAB_CAT_SRC)
            if why:
                out.append(why)
                continue
        crest = os.path.join(SRC, _CARD_STEM["crest" + tag] + ".png")
        if not os.path.isfile(crest) and write:
            why = fetch(_CARD_STEM["crest" + tag])
            if why:
                out.append(why)
                continue
        dst = os.path.join(TAB_DST, tab_name(tag) + ".png")
        if write:
            make_tab(tag).save(dst)
        elif not os.path.isfile(dst):
            out.append("tab icon not written: %s.png" % tab_name(tag))
    return out


def selftest():
    from PIL import Image
    # alpha shape is preserved exactly in relative terms, and the peak goes opaque
    src = Image.new("RGBA", (4, 1))
    src.putdata([(11, 40, 65, 0), (11, 40, 65, 51),
                 (11, 40, 65, 102), (11, 40, 65, 204)])
    got = list(brighten(src).convert('RGBA').getdata())
    assert [p[3] for p in got] == [0, 64, 128, 255], got
    assert all(p[:3] == INK for p in got), got
    # and a detailed source is refused rather than flattened
    import tempfile
    d = tempfile.mkdtemp()
    # half the pixels one colour, half another: genuinely not a silhouette
    im = Image.new("RGBA", (2, 1), (1, 2, 3, 255))
    im.putpixel((0, 0), (200, 10, 10, 255))
    im.save(os.path.join(d, "a.png"))
    global SRC, ICONS
    SRC, keep = d, ICONS
    ICONS = {"a": "a"}
    try:
        bad, _ = build(write=False)
        assert bad and "not a silhouette" in bad[0], bad
    finally:
        ICONS = keep
    # EVERY FLAVOUR has all six guild icons and a crest, each from its own source.
    names = set(ICONS.values())
    assert len(names) == len(ICONS), "two sources ship under one name"
    for tag in ("", "_emp", "_dwf", "_brt", "_cth", "_ksl", "_def", "_hef", "_skv", "_gen"):
        for g in ("brass", "immortals", "daemonsmiths", "khanate", "overseers",
                  "slavers", "temple", "crest"):
            assert g + tag in names, "no icon ships as " + g + tag
    assert len(set(HALL_ICONS.values())) == len(HALL_ICONS) == 63 - 7 * len(HALL_LEVEL_ICON_TAGS)
    assert len(set(HALL_LEVEL_ICONS.values())) == 21 * len(HALL_LEVEL_ICON_TAGS)
    assert not set(HALL_ICONS.values()) & set(HALL_LEVEL_ICONS.values())
    assert all(v == v.lower() for v in HALL_LEVEL_ICONS.values()), "a pack path must be lowercase"
    assert all(v == v.lower() for v in HALL_ICONS.values()), "a pack path must be lowercase"
    print("selftest ok: alpha preserved, peak opaque, detailed source refused")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    problems, made = build(write="--check" not in sys.argv)
    problems += build_halls(write="--check" not in sys.argv)
    problems += build_tabs(write="--check" not in sys.argv)
    for p in problems:
        print("PROBLEM: " + p)
    for path, w, h in made:
        print("  %-46s %dx%d" % (path, w, h))
    sys.exit(1 if problems else 0)
