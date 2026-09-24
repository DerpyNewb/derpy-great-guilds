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
}

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
        if write:
            new.save(os.path.join(DST, name + ".png"))
        made.append((IN_PACK % name, w, h))
    return out, made


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
    for tag in ("", "_emp", "_dwf", "_brt", "_cth", "_ksl", "_def", "_hef", "_gen"):
        for g in ("brass", "immortals", "daemonsmiths", "khanate", "overseers",
                  "slavers", "crest"):
            assert g + tag in names, "no icon ships as " + g + tag
    print("selftest ok: alpha preserved, peak opaque, detailed source refused")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    problems, made = build(write="--check" not in sys.argv)
    for p in problems:
        print("PROBLEM: " + p)
    for path, w, h in made:
        print("  %-46s %dx%d" % (path, w, h))
    sys.exit(1 if problems else 0)
