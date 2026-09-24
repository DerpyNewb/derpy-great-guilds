"""Packs The Great Guilds. Refuses on a TSV-vs-build() mismatch, then does the packing.

    py tools/import_great_guilds.py --check    verify only, no RPFM needed
    py tools/import_great_guilds.py            verify, then import and save

THIS USED TO ONLY PRINT THE PLAN. The packing was done by a throwaway script that
imported two of the eight tables, so every DB change made after it was written stayed in
the TSVs while the loc and the Lua reached the game - a pack whose loc described effects
its own junction rows did not have.

--verify-only re-opens the SAVED pack in a fresh session and counts the rows in every
table, because a table that is merely present proves nothing about whether it received
this build. It runs automatically after a save.
"""
import io
import os
import re
import sys

sys.path.insert(0, "tools")
import gen_great_guilds as G          # noqa: E402

SRC = "Modding Files/source/great_guilds"
SCRIPTS = [
    "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds.lua",
    "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua",
    "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ai.lua",
]
UI_FILES = [
    "Modding Files/pack/ui/campaign ui/derpy_gg_panel.twui.xml",
    "Modding Files/pack/ui/campaign ui/derpy_gg_card.twui.xml",
    "Modding Files/pack/ui/campaign ui/derpy_gg_row.twui.xml",
    "Modding Files/pack/ui/campaign ui/derpy_gg_list.twui.xml",
    "Modding Files/pack/ui/campaign ui/derpy_gg_frow.twui.xml",
    "Modding Files/pack/ui/campaign ui/derpy_gg_opener.twui.xml",
]
MCT_FILE = "Modding Files/pack/script/mct/settings/derpy_great_guilds.lua"
MODEL_LUA = SCRIPTS[0]


# Every folder of loose art this mod ships. Hand-written, and cross-checked below
# against what is actually staged - the icons folder was hardcoded here and a second
# folder would have been packed by nothing.
ART_DIRS = [
    "ui/campaign ui/derpy_gg_icons",
    "ui/campaign ui/derpy_gg_bg",
]


def _check_art_dirs():
    """A staged derpy_gg_* art folder that nothing packs is a silent non-draw.

    Same fault as UI_FILES below, one level up: the art is reached from Lua by a path
    the .twui.xml never mentions, so neither the imagepath sweep nor the ui file list
    can see it missing. What the player gets is the panel's default ground forever.
    """
    base = "Modding Files/pack/ui/campaign ui"
    if not os.path.isdir(base):
        return
    staged = {"ui/campaign ui/" + n for n in sorted(os.listdir(base))
              if n.startswith("derpy_gg_")
              and os.path.isdir(os.path.join(base, n))}
    missing = sorted(staged - set(ART_DIRS))
    if missing:
        raise SystemExit("REFUSING: %s is staged and ART_DIRS does not pack it - "
                         "anything the Lua draws from it is a blank that logs nothing"
                         % ", ".join(missing))
    gone = sorted(d for d in ART_DIRS if not os.path.isdir("Modding Files/pack/" + d))
    if gone:
        raise SystemExit("REFUSING: ART_DIRS names %s, which is not staged"
                         % ", ".join(gone))


def _check_ui_file_list():
    """UI_FILES above is written by hand and gen_guilds_ui.py decides what exists.

    THIS ALREADY NEARLY SHIPPED. The faction list added two .twui.xml files; this list
    still named four; the pack built, verified, reported "4 ui file(s)" and was correct
    about every row it checked. The panel would have created a component from a file that
    was not in the pack - which is a silent non-draw, the same failure as a bad GUID.
    """
    import sys as _sys
    _sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
    import gen_guilds_ui as _UI
    want = {n for n, _b, _c in _UI.FILES}
    got = {os.path.basename(p) for p in UI_FILES}
    missing = sorted(want - got)
    extra = sorted(got - want)
    if missing:
        raise SystemExit("REFUSING: gen_guilds_ui.py builds %s and UI_FILES does not "
                         "pack it - the panel would create a component from a file that "
                         "is not in the pack, which draws nothing and says nothing"
                         % ", ".join(missing))
    if extra:
        raise SystemExit("REFUSING: UI_FILES packs %s, which gen_guilds_ui.py no longer "
                         "builds" % ", ".join(extra))

# in-pack destination for each generated TSV
DB_DEST = {
    # The bounty mission rows. Without a destination here verify() refuses to pack,
    # which is the point: a table the generator emits and the pack never receives is a
    # feature that silently does nothing.
    "missions": "db/missions_tables/derpy_great_guilds",
    "effect_bundles": "db/effect_bundles_tables/derpy_great_guilds",
    "effect_bundles_to_effects_junctions":
        "db/effect_bundles_to_effects_junctions_tables/derpy_great_guilds",
}
LOC_DEST = "text/db/derpy_great_guilds.loc"

for _t in ("campaign_groups", "campaign_group_members",
           "campaign_group_member_criteria_values", "event_feed_message_events",
           "effects", "building_effects_junction"):
    DB_DEST[_t] = "db/%s_tables/derpy_great_guilds" % _t


def verify():
    problems = G.check()
    built = G.build()

    # BYTE FOR BYTE AGAINST WHAT THE GENERATOR WOULD WRITE, not a row count. Counting
    # rows says nothing about the values in them: on 2026-09-12 four event picture paths
    # and one loc string changed, every count stayed put, this check passed, and the pack
    # was built from the PREVIOUS build's TSVs - caught only by the read-back after the
    # save, which is one irreversible step too late. The metadata line is inside the
    # rendered text, so the version check below comes free with the comparison.
    rendered = G.render_tsvs()
    for table in built:
        # LOC INCLUDED. It was skipped here, and on 2026-09-13 a changed tab header went
        # into the pack from the previous build's loc.tsv - the same fault this check was
        # written to stop, in the one table the check did not cover. render_tsvs() walks
        # every table build() returns, loc among them, so there was never a reason for
        # the exemption beyond its having been written before loc was rendered.
        path = os.path.join(SRC, table + ".tsv")
        if not os.path.isfile(path):
            problems.append("missing TSV: " + path)
            continue
        with io.open(path, encoding="utf-8") as fh:
            have = fh.read().replace("\r\n", "\n")
        want = rendered.get(table, "")
        if have != want:
            hl, wl = have.split("\n"), want.split("\n")
            where = "row count %d vs %d" % (len(hl) - 3, len(wl) - 3)
            for i in range(min(len(hl), len(wl))):
                if hl[i] != wl[i]:
                    where = ("line %d is %r, build() has %r"
                             % (i + 1, hl[i][:90], wl[i][:90]))
                    break
            problems.append("%s.tsv is not what build() would write - %s. Run "
                            "`py tools/gen_great_guilds.py --write`" % (table, where))

    keys = [r["key"] for r in built["effect_bundles"]]
    if len(keys) != len(set(keys)):
        problems.append("duplicate bundle keys - the game drops duplicates silently")

    lockeys = [r["key"] for r in built["loc"]]
    if len(lockeys) != len(set(lockeys)):
        problems.append("duplicate loc keys")

    for s in SCRIPTS:
        if not os.path.isfile(s):
            problems.append("missing script: " + s)
        elif any(c.isupper() for c in os.path.basename(s)):
            problems.append("uppercase in pack path crashes since patch 6.1: " + s)

    # Every table the generator emits must have somewhere to go in the pack.
    for table in built:
        if table != "loc" and table not in DB_DEST:
            problems.append("no in-pack destination for table: " + table)

    if not os.path.isfile(MCT_FILE):
        problems.append("missing MCT settings file: " + MCT_FILE)
    else:
        # An unknown option type is refused by MCT, add_new_option returns FALSE, and
        # the next line indexes nil - which fails the whole settings file, so MCT
        # disables the mod until the next game start. luac and every other checker
        # pass it, because the string is only meaningful to MCT.
        #
        # The nine real types, read out of
        # groovy_mct.pack/script/groovy/modules/mct/objects/options/types/ on
        # 2026-09-10. There is no "button" - an action button is its own constructor,
        # add_new_action(option_key, button_text, callback).
        mct_types = {"action", "checkbox", "dropdown", "dropdown_game_object",
                     "dummy", "multibox", "radio_button", "slider", "text_input"}
        with io.open(MCT_FILE, encoding="utf-8") as fh:
            mct = fh.read()
        for m in re.finditer(r'add_new_option\(\s*"[^"]+"\s*,\s*"([^"]+)"', mct):
            if m.group(1) not in mct_types:
                problems.append(
                    "MCT option type %r is not one of %s - MCT refuses the file and "
                    "disables the mod" % (m.group(1), sorted(mct_types)))

    for u in UI_FILES:
        if not os.path.isfile(u):
            problems.append("missing UI file: " + u)
        elif any(c.isupper() for c in os.path.basename(u)):
            problems.append("uppercase in pack path crashes since patch 6.1: " + u)

    # The Lua service table and the Python one must not drift. Two copies of the
    # same eighteen rows is the price of the panel reading them without a DB call;
    # this is what keeps the copies honest.
    if os.path.isfile(MODEL_LUA):
        lua = io.open(MODEL_LUA, encoding="utf-8").read()
        for s in G.SERVICES:
            if ('key="%s"' % s["key"]) not in lua:
                problems.append("service missing from the Lua table: " + s["key"])
            else:
                for field, val in (("rank", s["rank"]), ("cost", s["cost"]),
                                   ("cd", s["cd"])):
                    pat = r'key="%s".*?%s=(\d+)' % (re.escape(s["key"]), field)
                    m = re.search(pat, lua)
                    if not m:
                        problems.append("%s: %s not found in Lua row" % (s["key"], field))
                    elif int(m.group(1)) != val:
                        problems.append("%s: Lua %s=%s, generator %s=%s"
                                        % (s["key"], field, m.group(1), field, val))
        if s and G.SERVICES and 'GG.HIRE_UNIT = "' in lua:
            m = re.search(r'GG\.HIRE_UNIT = "([^"]+)"', lua)
            want = [x.get("unit") for x in G.SERVICES if x.get("unit")]
            if m and want and m.group(1) != want[0]:
                problems.append("GG.HIRE_UNIT is %s, generator says %s"
                                % (m.group(1), want[0]))

    # EVERY SIGNAL MUST HAVE A LISTENER. GG.on_agent_action and GG.on_settlement
    # shipped written, commented and harness-covered with nothing in the game calling
    # them, so two of six guilds could not earn reputation from their own route at all.
    # A signal function that appears exactly once in the pack is its own definition and
    # nothing else.
    if os.path.isfile(MODEL_LUA):
        model = io.open(MODEL_LUA, encoding="utf-8").read()
        for m in re.finditer(r"function GG\.(on_[a-z_]+)", model):
            fn = m.group(1)
            if len(re.findall(r"GG\.%s\s*\(" % fn, model)) < 2:
                problems.append("GG.%s is defined but nothing ever calls it - the "
                                "signal is dead and its guild cannot earn from it" % fn)

    # EVERY MCT OPTION MUST BE READ BY SOMETHING. "Log every accrual" shipped as a
    # checkbox with a tooltip promising a line in the log, and no file in the pack
    # mentioned the key - a switch the player can toggle that does nothing at all.
    if os.path.isfile(MCT_FILE):
        mct_src = io.open(MCT_FILE, encoding="utf-8").read()
        scripts_src = ""
        for path in SCRIPTS:
            if os.path.isfile(path):
                scripts_src += io.open(path, encoding="utf-8").read()
        # QUOTED AND WHOLE. A bare substring test passes on a typo: searching for
        # "log_accrual" finds it inside "log_accrualX", which is exactly the mistake
        # that would make the switch silently dead again.
        for m in re.finditer(r'add_new_option\(\s*"([a-z_0-9]+)"', mct_src):
            key = m.group(1)
            if not re.search(r'"%s"' % re.escape(key), scripts_src):
                problems.append("MCT option %r is not read by any script in the pack - "
                                "it is a switch that does nothing" % key)

    # And every loc key the panel asks for by name must exist, or the panel draws the
    # bare key at the player.
    ui_file = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua"
    if os.path.isfile(ui_file):
        lockeys = set(r["key"] for r in G.build()["loc"])
        ui_src = io.open(ui_file, encoding="utf-8").read()
        for m in re.finditer(r'GGUI\.loc\("([a-z_0-9]+)"\)', ui_src):
            want = "derpy_gg_" + m.group(1)
            if want not in lockeys:
                problems.append("the panel asks for loc %s, which the generator never "
                                "emits - it draws the bare key" % want)

    # THE BOUNTY TABLES ARE MIRRORED, like SERVICES above. The generator owns the DB
    # rows and the loc; the Lua owns the offers and the mission string. A drift means
    # the panel offers a bounty whose row says something else, so the two are pinned.
    if os.path.isfile(MODEL_LUA):
        lua = io.open(MODEL_LUA, encoding="utf-8").read()
        table = re.search(r"GG\.BOUNTIES\s*=\s*\{(.*?)\}", lua, re.S)
        if not table:
            problems.append("the Lua has no GG.BOUNTIES table")
        for guild, (kind, _title, _desc) in sorted(
                G.BOUNTIES.items() if table else []):
            got = re.search(r"%s\s*=\s*\"([a-z_]+)\"" % re.escape(guild),
                            table.group(1))
            if not got:
                problems.append("guild %s has no bounty in the Lua" % guild)
            elif got.group(1) != kind:
                problems.append("%s: Lua bounty kind is %s, generator says %s"
                                % (guild, got.group(1), kind))
        for kind, spec in sorted(G.BOUNTY_KINDS.items()):
            m = re.search(r"%s\s*=\s*\{(.*?)\}" % re.escape(kind), lua, re.S)
            if not m:
                problems.append("bounty kind %s is missing from the Lua" % kind)
                continue
            body = m.group(1)
            if spec["otype"] not in body:
                problems.append("%s: the Lua does not carry objective type %s"
                                % (kind, spec["otype"]))
            if ("gold = %d" % spec["gold"]) not in body.replace("gold=", "gold = "):
                problems.append("%s: the Lua gold disagrees with the generator's %d"
                                % (kind, spec["gold"]))
        # The panel counts an offer down from this, so a drift draws a countdown that
        # disagrees with when the offer is actually withdrawn.
        ui_lua = "Modding Files/pack/script/campaign/mod/zzz_derpy_guilds_ui.lua"
        if os.path.isfile(ui_lua):
            u = io.open(ui_lua, encoding="utf-8").read()
            a = re.search(r"GG\.BOUNTY_OFFER_LIFE\s*=\s*(\d+)", lua)
            b = re.search(r"GGUI\.BOUNTY_LIFE\s*=\s*(\d+)", u)
            if not a or not b:
                problems.append("cannot find the bounty offer lifetime in both files")
            elif a.group(1) != b.group(1):
                problems.append("offer lifetime is %s in the model and %s in the panel"
                                % (a.group(1), b.group(1)))

    # The UI generator and the UI checker each refuse on their own faults.
    try:
        import gen_guilds_ui as U
        problems += U.check()
        import check_guilds_ui as C
        problems += C.check()
        # The opener's placement arithmetic, run under Lua against the measured HUD
        # geometry. Silent if lua.exe is absent - it must never be why a pack cannot
        # be built on another machine.
        import check_guilds_anchor as A
        problems += A.check()
    except Exception as e:
        problems.append("UI checks could not run: %r" % (e,))

    return problems


PACK = os.path.abspath("Modding Files/Modpacks/derpy_great_guilds.pack")


def _pack_files():
    """Every loose file that ships, as (source on disk, path inside the pack)."""
    out = []
    for path in SCRIPTS + UI_FILES + [MCT_FILE]:
        out.append((os.path.abspath(path),
                    path.replace("Modding Files/pack/", "")))
    for folder in ART_DIRS:
        disk = "Modding Files/pack/" + folder
        if os.path.isdir(disk):
            for name in sorted(os.listdir(disk)):
                out.append((os.path.abspath(os.path.join(disk, name)),
                            folder + "/" + name))
    return out


def _reopen(rpfm):
    """Open the pack, closing it first. RPFM refuses to open one it already holds, so
    a second run against the same RPFM session dies on the open rather than the work."""
    # close_pack, singular, and it takes pack_key - NOT close_packfiles taking paths,
    # which is the shape open_packfiles uses and is not a tool that exists.
    try:
        rpfm.call("close_pack", {"pack_key": PACK}, quiet=True)
    except RuntimeError:
        pass
    rpfm.open_pack(PACK)


def do_import():
    import json
    import rpfm_client as rpfm

    _reopen(rpfm)
    files = _pack_files()
    rpfm.call("add_packed_files", {
        "pack_key": PACK,
        "source_paths": [a for a, _b in files],
        "destination_paths": json.dumps([{"File": b} for _a, b in files]),
    }, quiet=True)
    print("  %-44s %d file(s)" % ("scripts, ui and icons", len(files)))

    for table, dest in sorted(DB_DEST.items()):
        version = G.TSV_META[table][1]
        # DELETED AND RECREATED, never imported into. A table keeps the version it was
        # created with, so importing over a wrong-version file leaves the wrong version
        # in place - and a wrong version is a hard crash during loading with no
        # bad_mods_report, no minidump and no script log.
        try:
            rpfm.call("delete_packed_files",
                      {"pack_key": PACK, "paths": json.dumps([{"File": dest}])},
                      quiet=True)
        except RuntimeError:
            pass
        rpfm.call("new_packed_file", {
            "pack_key": PACK, "path": dest,
            # `path` is the FULL file path; the name inside the enum is ignored.
            "new_file": json.dumps({"DB": ["derpy_great_guilds",
                                           G.TSV_META[table][0], version]}),
        }, quiet=True)
        rpfm.call("import_tsv", {"pack_key": PACK,
                                 "tsv_path": os.path.abspath(SRC + "/" + table + ".tsv"),
                                 "table_path": dest}, quiet=True)
        print("  %-44s v%d" % (dest, version))

    rpfm.call("import_tsv", {"pack_key": PACK,
                             "tsv_path": os.path.abspath(SRC + "/loc.tsv"),
                             "table_path": LOC_DEST}, quiet=True)
    print("  %-44s" % LOC_DEST)
    rpfm.call("save_packfile", {"pack_key": PACK}, quiet=True)
    print("saved " + PACK)


def _read_tsv(path):
    """RPFM's TSV: row 1 is the header, row 2 is `#<table>;<version>;<path>`."""
    lines = io.open(path, encoding="utf-8").read().split("\n")
    header = lines[0].rstrip("\r").split("\t")
    out = []
    for line in lines[2:]:
        line = line.rstrip("\r")
        if not line.strip():
            continue
        out.append(dict(zip(header, line.split("\t"))))
    return out


def _same(a, b):
    """One cell against another, tolerating RPFM's float and bool spellings.

    export_tsv writes 3 back as "3.0000" and True as "true", so a literal string
    comparison would report every numeric column in every table as a mismatch.
    """
    a, b = (a or "").strip(), (b or "").strip()
    if a.lower() == b.lower():
        return True
    try:
        return abs(float(a) - float(b)) < 1e-6
    except ValueError:
        return False


def verify_saved():
    """Read the SAVED pack back and compare its CONTENT against build().

    A row count catches a table that missed the import entirely. It does not catch a
    table that received an OLDER import - which is the failure that actually shipped:
    36 junction rows, correct in number, every one of them a build stale.
    """
    import rpfm_client as rpfm
    import tempfile

    problems = []
    built = G.build()
    # CLOSED AND RE-OPENED, so the rows counted below come off the file on disk rather
    # than out of the in-memory pack this process has just been writing to. A save that
    # did not land would otherwise verify perfectly against its own author.
    _reopen(rpfm)
    tmp = tempfile.mkdtemp()
    for table, dest in sorted(DB_DEST.items()):
        out = os.path.join(tmp, table + ".tsv")
        try:
            rpfm.call("export_tsv", {"pack_key": PACK, "table_path": dest,
                                     "tsv_path": out}, quiet=True)
        except RuntimeError as e:
            problems.append("%s is not in the saved pack: %s" % (dest, str(e)[:60]))
            continue
        rows = _read_tsv(out)
        want = built[table]
        if len(rows) != len(want):
            problems.append("%s holds %d rows, this build has %d - the table did not "
                            "receive this build" % (dest, len(rows), len(want)))
            continue

        # Keyed on every column the generator emits that the export also carries, so a
        # different row ORDER is not a mismatch but a different row IS. Tables here have
        # no single primary key column in common, so the whole row is the key.
        cols = [c for c in want[0] if c in (rows[0] if rows else {})]
        if not cols:
            problems.append("%s: nothing in common between the export and build() - "
                            "the column names have moved" % dest)
            continue
        missing = [c for c in want[0] if c not in cols]
        if missing:
            problems.append("%s: the saved table has no column(s) %s"
                            % (dest, ", ".join(sorted(missing))))
            continue

        def sig(r):
            return tuple(str(r.get(c, "")).strip().lower() for c in cols)

        have = {}
        for r in rows:
            have.setdefault(sig(r), 0)
            have[sig(r)] += 1
        for r in want:
            k = sig(r)
            # Try the exact spelling first, then fall back to a per-cell compare, which
            # is what absorbs RPFM writing 3 back as "3.0000".
            if have.get(k):
                have[k] -= 1
                continue
            hit = None
            for cand in rows:
                if all(_same(cand.get(c), r.get(c)) for c in cols):
                    hit = cand
                    break
            if hit is None:
                shown = ", ".join("%s=%s" % (c, r[c]) for c in cols[:3])
                problems.append("%s is missing a row this build emits (%s) - the table "
                                "received an older import" % (dest, shown))
                break

    # THE LOC TOO. It was the one table that WAS being imported, which is exactly why
    # nobody thought to check it - and it is the file that describes what every other
    # table does, so a stale one lies about all of them.
    lout = os.path.join(tmp, "loc.tsv")
    try:
        rpfm.call("export_tsv", {"pack_key": PACK, "table_path": LOC_DEST,
                                 "tsv_path": lout}, quiet=True)
    except RuntimeError as e:
        problems.append("%s is not in the saved pack: %s" % (LOC_DEST, str(e)[:60]))
    else:
        have = dict((r.get("key"), r.get("text")) for r in _read_tsv(lout))
        for r in built["loc"]:
            if r["key"] not in have:
                problems.append("loc key %s is missing from the saved pack" % r["key"])
                break
            if (have[r["key"]] or "").strip() != r["text"].strip():
                problems.append("loc key %s reads %r in the saved pack and %r in this "
                                "build" % (r["key"], (have[r["key"]] or "")[:40],
                                           r["text"][:40]))
                break
    return problems


if __name__ == "__main__":
    _check_ui_file_list()
    _check_art_dirs()
    bad = verify()
    for b in bad:
        print("REFUSING: " + b)
    if bad:
        sys.exit(1)
    built = G.build()
    print("verify ok - %d bundles, %d junctions, %d loc, %d script(s), %d ui file(s)" % (
        len(built["effect_bundles"]),
        len(built["effect_bundles_to_effects_junctions"]),
        len(built["loc"]), len(SCRIPTS), len(UI_FILES)))
    if "--check" in sys.argv:
        for t, d in sorted(DB_DEST.items()):
            print("  %-40s -> %s" % (t + ".tsv", d))
        print("  %-40s -> %s" % ("loc.tsv", LOC_DEST))
        sys.exit(0)

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    if "--verify-only" not in sys.argv:
        do_import()
    late = verify_saved()
    for p in late:
        print("FAILED: " + p)
    if late:
        sys.exit(1)
    print("saved pack verified - every table holds this build's rows")
