"""Runs GGUI.btn_anchor under Lua against the measured HUD geometry.

THE OPENER HAS BEEN PLACED WRONG THREE TIMES. It was created inside a RadialList
whose layout group owned its position; it was placed at 489,0 from a read taken
while resources_bar was mid-animation; and it drew nothing at all for want of art.
None of those was an error at runtime - the button was simply somewhere else, or
nowhere. Arithmetic that can only be checked by launching a campaign gets checked
by launching Lua instead.

The function is extracted from the shipped script rather than copied here, so this
cannot pass against a version of the maths that is no longer the one that ships.

Exits 0 and prints "skipped" when lua.exe is absent - this must never be the reason
a pack cannot be built on another machine.
"""
import io
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
SRC = os.path.join(ROOT, "Modding Files", "pack", "script", "campaign", "mod",
                   "zzz_derpy_guilds_ui.lua")

# resources_bar measured live on a 1920x1080 screen, 2026-09-10, settled:
#     resources_bar   pos 445,-4   990x60
# The Exchange parks its 48px button off the RIGHT end with a 4px gap, vertically
# centred; ours goes to its LEFT, or in its place when that mod is not installed.
STUB = """GGUI = {BTN_SIZE = 44, BTN_GAP = 4}
local BAR = {}
function BAR:Position() return 445, -4 end
function BAR:Dimensions() return 990, 60 end
core = {get_ui_root = function() return {} end}
function find_uicomponent(root, name) return BAR end
function is_uicomponent(c) return c ~= nil end
"""

TAIL = """
local SCREEN_W, SCREEN_H = 1920, 1080

EX = nil
local x, y, why = GGUI.btn_anchor()
print(string.format("no exchange : %d,%d  (%s)", x, y, why))

EX = {BUTTON = "derpy_chd_exchange_button", BUTTON_SIZE = 48, BUTTON_GAP = 4}
local x2, y2, why2 = GGUI.btn_anchor()
print(string.format("left of exch: %d,%d  (%s)", x2, y2, why2))

-- LEFT OF means one row, to the left, not overlapping. A button that lands under,
-- on top of, to the right of, or a few pixels out of line with the Exchange's is the
-- request not being met, and none of those is a crash.
assert(y2 == y, "the two buttons must share one row")
assert(x2 + GGUI.BTN_SIZE <= x, "the button overlaps the Exchange's")
assert(x2 + GGUI.BTN_SIZE >= x - 16, "the two buttons are not adjacent")

-- Both must be wholly on screen. The clamp downstream can only move a button by its
-- own size, so anything worse than that here ships as a button half off the edge.
for _, p in ipairs({{x, y}, {x2, y2}}) do
    assert(p[1] >= 0 and p[2] >= 0, "off the top or left of the screen")
    assert(p[1] + GGUI.BTN_SIZE <= SCREEN_W, "off the right of the screen")
    assert(p[2] + GGUI.BTN_SIZE <= SCREEN_H, "off the bottom of the screen")
end

-- AN ANIMATED STRIP MUST BE REFUSED, NOT GUESSED AT. resources_bar leaves the top of
-- the screen for cutscenes and end-turn; read mid-slide it answered by = -64 and the
-- button was placed at 489,0 - on-screen, so every downstream guard passed it.
function BAR:Position() return 445, -64 end
local bx, _, w3 = GGUI.btn_anchor()
assert(bx == nil and w3 == "unsettled", "a mid-animation read was accepted")

print("anchor ok: left-of, standalone and unsettled all behave")
"""


def script():
    """The shipped btn_anchor, wrapped in stubs. Extracted, never copied."""
    s = io.open(SRC, encoding="utf-8").read()
    i = s.index("function GGUI.btn_anchor()")
    j = s.index("\nend\n", i) + len("\nend\n")
    return STUB + s[i:j] + TAIL


def check():
    if not os.path.isfile(LUA):
        return []
    fd, path = tempfile.mkstemp(suffix=".lua")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(script())
        p = subprocess.Popen([LUA, path], stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT)
        out = p.communicate()[0].decode("utf-8", "replace")
        if p.returncode != 0:
            return ["opener placement: " + " ".join(out.split())]
        return []
    finally:
        os.unlink(path)


if __name__ == "__main__":
    if not os.path.isfile(LUA):
        print("skipped: no lua.exe at %s" % LUA)
        sys.exit(0)
    fd, path = tempfile.mkstemp(suffix=".lua")
    with os.fdopen(fd, "w") as fh:
        fh.write(script())
    try:
        sys.exit(subprocess.call([LUA, path]))
    finally:
        os.unlink(path)
