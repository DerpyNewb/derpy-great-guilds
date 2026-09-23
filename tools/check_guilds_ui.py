"""Build-time UI checker for The Great Guilds, modelled on check_rite_panel_ui.py.

Every fault below is a SILENT failure in game - no error, no log line, the widget
simply does not draw or draws in the wrong place. Ten such checks each caught a
fault after it had already shipped on the last panel this workspace built, which
is why this file exists rather than a visual once-over.

    py tools\\check_guilds_ui.py            # check the generated files
    py tools\\check_guilds_ui.py --selftest # break each fault, confirm it is caught

Needs neither RPFM nor the game.
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_guilds_ui as U             # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA_UI = os.path.join(ROOT, "Modding Files", "pack", "script", "campaign",
                      "mod", "zzz_derpy_guilds_ui.lua")


def load_all():
    """The four files as text, from the generator rather than from disk, so a
    check run cannot be fooled by a stale write."""
    return dict(U.build_xml())


def _hier_guids(text):
    hier = text.split("<hierarchy>", 1)[1].split("</hierarchy>", 1)[0]
    return set(re.findall(r'this="([^"]+)"', hier))


def _comp_guids(text):
    comps = text.split("<components>", 1)[1]
    return set(re.findall(r'(?m)^\t\t<\w+[^>]*?this="([^"]+)"', comps))


def check_guid_pairing(files):
    """A guid in <components> with no <hierarchy> node never draws."""
    out = []
    for fname, text in sorted(files.items()):
        h, c = _hier_guids(text), _comp_guids(text)
        for g in sorted(c - h):
            out.append("%s: %s in components with no hierarchy node - silent non-draw"
                       % (fname, g))
        for g in sorted(h - c):
            out.append("%s: %s in hierarchy with no component definition" % (fname, g))
    return out


def check_guid_range(files):
    """A reused prefix against a save holding the old component is a silent non-draw."""
    out = []
    for fname, text in sorted(files.items()):
        for g in sorted(_comp_guids(text)):
            if g.startswith("DE15"):
                out.append("%s: DE15 is RETIRED and must not be reused" % fname)
            elif not g.startswith(U.GUID_PREFIX):
                out.append("%s: %s outside the %s range claimed by this mod"
                           % (fname, g, U.GUID_PREFIX))
    return out


def check_names_reached(files, lua_text=None):
    """Every component the Lua looks up must exist, or the lookup silently returns nil."""
    out = []
    if lua_text is None:
        if not os.path.isfile(LUA_UI):
            return ["panel Lua not found: " + LUA_UI]
        lua_text = io.open(LUA_UI, encoding="utf-8").read()
    declared = set()
    for text in files.values():
        declared |= set(U.xml_component_names(text))
    for m in sorted(set(re.findall(r'comp\("([a-z0-9_]+)"', lua_text))):
        if m in U.HOST_COMPONENTS:
            continue
        base = re.sub(r"_\d+$", "_1", m)
        if m not in declared and base not in declared:
            out.append("Lua reaches for %r, which no .twui.xml declares" % m)
    return out


def check_extent(_files=None):
    """Bounds() includes children and Dimensions() does not, so an overhanging
    child is a silent misplacement rather than an error."""
    out = []
    for label, layout, w, h in (
            ("panel", U.PANEL_LAYOUT, U.PANEL_W, U.PANEL_H),
            ("card", U.CARD_LAYOUT, U.CARD_W, U.CARD_H),
            ("row", U.ROW_LAYOUT, U.ROW_W, U.ROW_H)):
        for name, (x, y, cw, ch) in sorted(layout.items()):
            if x + cw > w or y + ch > h:
                out.append("%s child %s (%d,%d %dx%d) overhangs the %dx%d %s"
                           % (label, name, x, y, cw, ch, w, h, label))
    return out


def check_paths(files):
    """An uppercase character in a pack path crashes the game since patch 6.1."""
    out = []
    for fname in sorted(files):
        if any(ch.isupper() for ch in fname):
            out.append("uppercase in pack path: " + fname)
    return out


def check_against(files, lua_text=None):
    return (check_guid_pairing(files) + check_guid_range(files)
            + check_names_reached(files, lua_text) + check_extent(files)
            + check_paths(files))


def check():
    return check_against(load_all())


# ------------------------------------------------------------------ faults ---

def drop_hierarchy_node(files):
    f = dict(files)
    name = "derpy_gg_card.twui.xml"
    text = f[name]
    g = sorted(_hier_guids(text) & _comp_guids(text))[-1]
    hier, rest = text.split("</hierarchy>", 1)
    hier = re.sub(r'(?m)^\t+<\w+ this="%s"/>\n' % re.escape(g), "", hier)
    f[name] = hier + "</hierarchy>" + rest
    return f


def orphan_hierarchy_node(files):
    f = dict(files)
    name = "derpy_gg_row.twui.xml"
    text = f[name]
    hier, rest = text.split("</hierarchy>", 1)
    hier += '\t\t\t<ghost this="%s9999-D000-4000-B000000000009999"/>\n' % U.GUID_PREFIX
    f[name] = hier + "</hierarchy>" + rest
    return f


def wrong_guid_range(files):
    f = dict(files)
    name = "derpy_gg_panel.twui.xml"
    f[name] = f[name].replace(U.GUID_PREFIX + "0001", "DE150001")
    return f


def uppercase_path(files):
    f = dict(files)
    f["derpy_GG_panel.twui.xml"] = f.pop("derpy_gg_panel.twui.xml")
    return f


def selftest():
    base = load_all()
    assert not check_against(base), \
        "the real files must be clean before fault injection: %r" % (check_against(base),)

    cases = [
        ("hierarchy node dropped", drop_hierarchy_node(base), None, "silent non-draw"),
        ("orphan hierarchy node", orphan_hierarchy_node(base), None, "no component"),
        ("guid out of range", wrong_guid_range(base), None, "RETIRED"),
        ("uppercase path", uppercase_path(base), None, "uppercase"),
        ("lua reaches a missing name", base,
         'local x = comp("gg_does_not_exist")', "no .twui.xml declares"),
    ]
    for label, files, lua, expect in cases:
        problems = check_against(files, lua)
        assert any(expect in p for p in problems), \
            "fault NOT caught (%s): expected %r in %r" % (label, expect, problems)

    # The extent check needs its own injection: it reads the layout dicts, not text.
    saved = U.PANEL_LAYOUT.get("gg_footer")
    try:
        U.PANEL_LAYOUT["gg_footer"] = (20, 690, 750, 300)
        problems = check_extent(base)
        assert any("overhangs" in p for p in problems), \
            "fault NOT caught (overhanging child): %r" % (problems,)
    finally:
        U.PANEL_LAYOUT["gg_footer"] = saved

    print("selftest ok: %d/%d faults caught" % (len(cases) + 1, len(cases) + 1))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    else:
        problems = check()
        for p in problems:
            print("PROBLEM: " + p)
        print("%d problem(s)" % len(problems))
        sys.exit(1 if problems else 0)
