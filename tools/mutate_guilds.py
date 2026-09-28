# -*- coding: utf-8 -*-
"""Break the Great Guilds' bounty rules one at a time and prove a harness notices.

Modelled on tools/mutate_iron_court.py, with two differences that matter:
- THE GUILDS HARNESSES FAIL BY assert, not by printing FAIL. A mutant is caught when a
  harness exits non-zero with a traceback naming a harness file; a crash naming the
  model file (a parse error) is an ERROR, not a catch.
- FILES ARE READ AND WRITTEN AS BYTES. The model is LF and the UI is CRLF; a text-mode
  round trip would rewrite one of them.

The mutation goes into the SHIPPED Lua and is restored in a `finally`. Neither harness
writes a file, so unlike the Iron Court run there is nothing generated to restore.

    py tools/mutate_guilds.py            # every mutant
    py tools/mutate_guilds.py --selftest
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "Modding Files", "pack", "script", "campaign", "mod")
M = os.path.join(MOD, "zzz_derpy_guilds.lua")
U = os.path.join(MOD, "zzz_derpy_guilds_ui.lua")   # CRLF: a two-line anchor needs \r\n
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
HARNESSES = [os.path.join(ROOT, "tools", "_guilds_harness.lua"),
             os.path.join(ROOT, "tools", "_guilds_bounty_harness.lua")]

# (what it breaks, file, code as it ships, the mistake). Anchors are CODE lines.
MUTANTS = [
    ("a Leaderboard row's tooltip given the guild's whole description back", U,
     b"            local tip = GGUI.table_lines(L.guild, faction)\r\n",
     b"            local tip = GGUI.table_lines(L.guild, faction) .. \"||\""
     b" .. GGUI.loc_guild_desc(L.guild)\r\n"),
    ("the opener left grey when placement bails at turn start", U,
     b"    -- stay grey for the whole turn.\r\n    GGUI.gate_opener(GGUI.player_turn())",
     b"    -- stay grey for the whole turn."),
    ("the opener clickable during the AI round", U,
     b"        if not GGUI.player_turn() then return end\r\n        if GGUI.PICK then",
     b"        if GGUI.PICK then"),
    ("the opener not greyed at the player's turn end", U,
     b"        GGUI.gate_opener(false)\r\n    end, true)",
     b"    end, true)"),
    ("a research job for a tech the player cannot start", M,
     b"                if got >= need then found[#found + 1] = list[i] end",
     b"                found[#found + 1] = list[i]"),
    ("a building job for a level the player cannot upgrade to", M,
     b"                    if GG.player_has_building(faction, froms[j]) then",
     b"                    if true then"),
    ("required_parents read as all parents", M,
     b"                if got >= need then found[#found + 1] = list[i] end",
     b"                if got >= #ps then found[#found + 1] = list[i] end"),
    ("the front line allowed for military work", M,
     b"        local front = (not k.front_ok) and GG.front_regions(faction) or {}",
     b"        local front = {}"),
    ("a lord on the front posted", M,
     b"                           and (k.front_ok or not GG.char_on_front(faction, gen)) then",
     b"                           then"),
    ("a pact partner made a target", M,
     b"        if pf:non_aggression_pact_with(e) then return false end",
     b""),
    ("the stake not spent", M,
     b"    if stake > 0 and not GG.spend(faction, o.guild, stake) then return false end",
     b""),
    ("the refund paid as a grant", M,
     b"    if g then g.fav = g.fav + amount end",
     b"    if g then GG.grant(faction, guild, amount, \"refund\") return end"),
    ("the new-war premium dropped", M,
     b"    if war == 1 then gm, rm = GG.BOUNTY_WAR_GOLD, GG.BOUNTY_WAR_REP end",
     b""),
    ("an opportune failure counted", M,
     b"    if not won or target == nil then return nil end",
     b"    if target == nil then return nil end"),
    ("any target counted", M,
     b"        if o.taken and not o.void and k and k.shape and o.target == tostring(target)",
     b"        if o.taken and not o.void and k and k.shape"),
    ("the void flag ignored on cancel", M,
     b"    if o and o.void then GG.refund(faction, o.guild, o.stake) end",
     b""),
    ("a hero bounty completed on every success", M,
     b"            if o.done == (o.amount or 1) then",
     b"            if true then"),
    ("the progress saved after the completion call", M,
     b"            o.done = (o.done or 0) + 1\n            GG.save_bounties(faction)",
     b"            o.done = (o.done or 0) + 1"),
    ("a researched tech still offered", M,
     b"            if not used[key] and not has(key) then",
     b"            if not used[key] then"),
]


def run():
    for h in HARNESSES:
        p = subprocess.run([LUA, h], capture_output=True, cwd=ROOT)
        # stderr only: the bounty harness prints a line per passing block to stdout,
        # and the first line of the ERROR test below must be the error itself.
        if p.returncode != 0:
            return p.returncode, p.stderr.decode("utf-8", "replace")
    return 0, ""


def check(mutants, quiet=False):
    code, text = run()
    if code != 0:
        return [("the harnesses", "not green before anything was broken: " + text[-300:])]
    bad = []
    for what, path, old, new in mutants:
        src = open(path, "rb").read()
        if src.count(old) != 1:
            bad.append((what, "STALE ANCHOR - matched %d times, not 1" % src.count(old)))
            continue
        try:
            open(path, "wb").write(src.replace(old, new))
            code, text = run()
        finally:
            open(path, "wb").write(src)
        if code == 0:
            bad.append((what, "SURVIVED - both harnesses are green with this broken"))
        # The FIRST line names who raised it. The traceback under it always mentions
        # the harness (it dofiles the model), so matching the whole text catches a
        # parse error as if it were an assertion.
        elif "_harness.lua:" not in text.strip().splitlines()[0]:
            bad.append((what, "ERROR - failed without a harness assertion: " + text[-200:]))
        elif not quiet:
            print("caught: " + what)
    if run()[0] != 0:
        bad.append(("the tree", "left BROKEN - a restore did not take"))
    return bad


def selftest():
    before = open(M, "rb").read()
    harmless = [("a comment nobody can test", M, b"function GG.bounty_stake(rep)",
                 b"-- selftest\nfunction GG.bounty_stake(rep)")]
    bad = check(harmless, quiet=True)
    assert len(bad) == 1 and "SURVIVED" in bad[0][1], bad
    bad = check([("a moved anchor", M, b"no such code anywhere", b"x")], quiet=True)
    assert len(bad) == 1 and "STALE" in bad[0][1], bad
    bad = check([("a parse error", M, b"function GG.bounty_stake(rep)",
                  b"function GG.bounty_stake(")], quiet=True)
    assert len(bad) == 1 and "ERROR" in bad[0][1], bad
    assert open(M, "rb").read() == before, "the selftest did not restore the model"
    for what, path, old, _new in MUTANTS:
        n = open(path, "rb").read().count(old)
        assert n == 1, "%s: anchor matches %d times" % (what, n)
    print("selftest ok: %d mutants anchored" % len(MUTANTS))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
        sys.exit(0)
    bad = check(MUTANTS)
    for what, why in bad:
        print("PROBLEM: %s: %s" % (what, why))
    sys.exit(1 if bad else 0)
