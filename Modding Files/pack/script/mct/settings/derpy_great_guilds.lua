-- MCT registration for The Great Guilds.
--
-- MCT loads every .lua under script/mct/settings/, so this file only runs when
-- MCT is installed. It runs in MCT's OWN environment and CANNOT see GG - a mod
-- script's globals are not _G - so nothing here calls into the mod directly. The
-- campaign script reads these values once, at the first tick of a campaign, and
-- freezes them into the save. In multiplayer only the host's are read, and the
-- campaign script sends them to every player (GG.send_tune).

local mct = get_mct and get_mct()
if not mct then return end

local m = mct:register_mod("derpy_great_guilds")
m:set_title("The Great Guilds")
m:set_author("derpy")
m:set_description("Six guilds span the world. Earn their favour by playing your "
    .. "campaign, spend it on services. These values are read once, when a campaign "
    .. "starts, and are then fixed for the life of that save - change them from the "
    .. "main menu before starting a new one. In multiplayer the host's settings are "
    .. "used for every player.")

-- MCT HAS NO CAMPAIGN GATING OF ITS OWN. set_context_specific is an empty
-- function body and set_local_only is commented out end to end, so both read as
-- gating and gate nothing. The real defence is the snapshot the campaign script
-- writes at the first tick; the lock below is only the warning.
local IN_CAMPAIGN = __game_mode == __lib_type_campaign
local LOCK_REASON = "Fixed for the life of a campaign. Change it from the main "
    .. "menu before starting a new one."

m:add_new_section("preset", "Difficulty")
m:add_new_section("systems", "Systems")
m:add_new_section("court", "The Court")
m:add_new_section("rates", "Earn rates")
m:add_new_section("caps", "Limit per turn")
m:add_new_section("debug", "Debug")

-- ----------------------------------------------------------------- difficulty --
-- ONE DROPDOWN THAT OWNS THE NUMBERS. Twenty of the values below are difficulty; pick
-- anything but Custom and the preset sets all twenty and greys them.
--
-- THE FOUR SWITCHES IN "Systems" ARE NOT LOCKED BY A PRESET and are read on every one of
-- them. The Zharr Exchange's presets own its checkboxes too, so under any preset but
-- Custom every checkbox in that mod is inert - and a switch that silently does nothing is
-- a defect this mod has already shipped once. Difficulty is not the same question as
-- whether you want feed notices.
local o_preset = m:add_new_option("preset", "dropdown")
o_preset:set_text("Difficulty")
o_preset:set_tooltip_text("How fast reputation is earned and how hard the Court presses. "
    .. "Fixed for the life of a campaign - change it from the main menu before starting "
    .. "a new one. The switches under Systems are yours on every difficulty.")
o_preset:set_assigned_section("preset")
o_preset:add_dropdown_value("easy", "Easy",
    "A faster climb and a gentler Court. About a third more reputation per event with "
    .. "higher limits per turn, demands half as often with twice as long to answer and "
    .. "half the sting for missing one, and rivalry costing half as much so courting a "
    .. "wide spread of guilds stays viable.", false)
o_preset:add_dropdown_value("default", "Default",
    "The Guilds as designed, and as every build so far has played.", true)
o_preset:add_dropdown_value("hard", "Hard",
    "Slower, and the Court presses. About a quarter less reputation per event with "
    .. "lower limits per turn, demands every nine turns with six to answer, and an "
    .. "ignored demand costing half again what it does on Default.", false)
o_preset:add_dropdown_value("ultra", "Cutthroat",
    "Reputation comes at roughly half the Default rate with limits to match, "
    .. "rivalry costs more than double, and the Court asks every six turns with five "
    .. "to answer and a penalty larger than its own reward - so a demand you cannot pay "
    .. "is a rank lost rather than a delay. Specialising stops being a style and becomes "
    .. "the way through.", false)
o_preset:add_dropdown_value("custom", "Custom",
    "Every rate, limit and Court value below can be changed. Set them before you start a "
    .. "campaign; they are fixed once one is running.", false)
o_preset:set_default_value("default")

-- ------------------------------------------------------------------ systems --

local o_ai = m:add_new_option("ai_spending", "checkbox")
o_ai:set_text("Rival factions use the guilds")
o_ai:set_tooltip_text("Rival factions earn their own reputation and use it the way you "
    .. "do: they buy services, including the one that can be aimed at you, they answer "
    .. "the guilds' demands, and they appoint patrons of their own. Off, rivals still "
    .. "earn - so the leaderboard still means something - but never act on it.")
o_ai:set_default_value(true)
o_ai:set_assigned_section("systems")

local o_hostile = m:add_new_option("hostile_services", "checkbox")
o_hostile:set_text("Guilds can be turned on you")
o_hostile:set_tooltip_text("The Khan's Price, the one service that targets another "
    .. "faction. Off, no faction may buy it - you included.")
o_hostile:set_default_value(true)
o_hostile:set_assigned_section("systems")

local o_notices = m:add_new_option("guild_notices", "checkbox")
o_notices:set_default_value(true)
o_notices:set_text("Guild notices")
o_notices:set_tooltip_text("Announce a rank gained, and the first time a guild takes "
                           .. "notice of you, on the event feed. Bad news - demands, a "
                           .. "guild lost, a rival's service landing on you - is always "
                           .. "announced and is not covered by this switch.")
o_notices:set_assigned_section("systems")

local o_mono = m:add_new_option("lead_monopoly", "checkbox")
o_mono:set_text("Only the leader buys the finest service")
o_mono:set_tooltip_text("Each guild's dearest service is sold only to the faction "
    .. "holding the most reputation with it - you or a rival. Off, the leader's bonus "
    .. "still applies, and anyone with the rank can buy the service.")
o_mono:set_default_value(true)
o_mono:set_assigned_section("systems")

-- ------------------------------------------------------------------- court --
-- The demands, the patron, and the upkeep. These are the things that can take reputation
-- away on a clock, so every clock is tunable and 0 turns each one off.

local COURT = {
    {"demand_every", "Turns between demands", 12, 0, 60,
     "How long a guild waits before asking something of you. 0 switches demands off "
     .. "entirely."},
    {"demand_turns", "Turns to pay a demand", 8, 2, 30,
     "The deadline. Let it pass and your reputation with that guild falls."},
    {"demand_reward", "Reputation for paying", 120, 0, 400,
     "Paid to the demanding guild when you meet its terms."},
    {"demand_penalty", "Reputation for refusing", 60, 0, 400,
     "Taken from the demanding guild when the deadline passes unpaid. Enough of it "
     .. "costs you a rank, and the rank's bonus with it."},
    {"rate_patron", "Patron's share", 50, 0, 200,
     "Extra reputation, as a percentage, for the guild your patron serves. The guild's "
     .. "own limit per turn still applies, so this cannot be used to outrun it."},
    {"rate_decay", "Upkeep", 100, 0, 400,
     "What reputation costs to hold. Every guild you have reputation with charges some "
     .. "back each turn, scaled by the rank you hold there - 100 means one point a turn "
     .. "at Unmarked and five at Exalted, so the top of the ladder is the dearest seat. "
     .. "0 switches it off and reputation only ever falls to a rival or a demand."},
    {"decay_from", "Upkeep begins on turn", 25, 0, 200,
     "The grace period. Nothing is charged before this turn, so the opening of a "
     .. "campaign is yours. 0 switches the upkeep off entirely."},
    {"rate_bounty_fail", "Failed bounty costs", 100, 0, 300,
     "Reputation a bounty takes back when you accept it and do not finish it before the "
     .. "deadline, as a percentage of what finishing it would have paid. 100 makes the "
     .. "failure worth exactly what the success was. Leaving an offer alone or handing "
     .. "it back is always free - this is only for work you promised. 0 switches it off."},
}

for i = 1, #COURT do
    local key, label, def, lo, hi, tip = unpack(COURT[i])
    local o = m:add_new_option(key, "slider")
    o:set_text(label)
    o:set_tooltip_text(tip)
    o:slider_set_min_max(lo, hi)
    o:slider_set_step_size(1)
    o:set_default_value(def)
    o:set_assigned_section("court")
    if IN_CAMPAIGN then o:set_locked(true, LOCK_REASON) end
end

-- ------------------------------------------------------------------- rates --
-- One slider per guild. These are the reputation and favour paid per event, and
-- they are STARTING VALUES rather than measurements - the design says so plainly.
--
-- NAMED BY ROLE, because the frontend has no race to name them for. In a campaign
-- GGUI.name_mct renames all twelve guild sliders to the player's own flavour at the
-- first tick. gen_great_guilds.py checks these labels against its generic flavour.

local RATES = {
    {"rate_brass", "The Merchant Houses", 250, 50, 1000,
     "Gold of net income per point. Lower is faster."},
    {"rate_immortals", "The Veterans' Company", 15, 1, 60, "Points per battle won."},
    {"rate_daemonsmiths", "The Artisans' Guild", 60, 5, 200,
     "Points per technology researched."},
    {"rate_khanate", "The Shadow Guild", 8, 1, 40,
     "Points per successful hero action."},
    {"rate_overseers", "The Builders' Guild", 10, 1, 40,
     "Points per building level completed, paid to whichever guild the building "
     .. "belongs to - its card names the guild."},
    {"rate_slavers", "The Raiders' Guild", 25, 1, 100,
     "Points per settlement sacked. A raze pays this plus half again."},
    -- Not a guild: the one signal that pays ALL SIX. Each guild's own per-turn cap
    -- still applies, so this cannot be used to outrun them.
    {"rate_missions", "Missions (every guild)", 10, 0, 60,
     "Points paid to every guild when you complete a mission. 0 turns it off."},
    -- The bounty board's pay. An order of magnitude above the blanket rate because a
    -- bounty is chosen, targeted and timed. 0 empties the board entirely.
    {"rate_bounty", "Bounties (the posting guild)", 80, 0, 400,
     "Reputation a completed bounty pays the guild that posted it. 0 empties the "
     .. "bounty board."},
    -- Not an earn rate at all, but it belongs beside them: it is the price of one.
    -- The only setting here that can take reputation AWAY, so 0 is a real choice and
    -- turns the six guilds back into six independent counters.
    {"rate_rivalry", "Rivalry (cost to the rival)", 40, 0, 100,
     "Reputation a guild loses when its rival earns, as a percentage of that earning. "
     .. "0 switches rivalry off."},
}

for i = 1, #RATES do
    local key, label, def, lo, hi, tip = unpack(RATES[i])
    local o = m:add_new_option(key, "slider")
    o:set_text(label)
    o:set_tooltip_text(tip)
    o:slider_set_min_max(lo, hi)
    o:slider_set_step_size(1)
    o:set_default_value(def)
    o:set_assigned_section("rates")
    if IN_CAMPAIGN then o:set_locked(true, LOCK_REASON) end
end

-- -------------------------------------------------------------------- caps --
-- The caps are not decoration. Without them, income-scaled reputation lets a
-- large empire max the Brass Tablets passively while a small one never climbs.
-- 0 means no cap, which is what the Daemonsmiths ship with.

local CAPS = {
    {"cap_brass", "The Merchant Houses", 40},
    {"cap_immortals", "The Veterans' Company", 60},
    {"cap_daemonsmiths", "The Artisans' Guild", 0},
    {"cap_khanate", "The Shadow Guild", 40},
    {"cap_overseers", "The Builders' Guild", 40},
    {"cap_slavers", "The Raiders' Guild", 80},
}

for i = 1, #CAPS do
    local key, label, def = unpack(CAPS[i])
    local o = m:add_new_option(key, "slider")
    o:set_text(label .. " limit")
    o:set_tooltip_text("Most reputation this guild can pay in one turn. 0 removes "
        .. "the limit entirely.")
    o:slider_set_min_max(0, 400)
    o:slider_set_step_size(5)
    o:set_default_value(def)
    o:set_assigned_section("caps")
    if IN_CAMPAIGN then o:set_locked(true, LOCK_REASON) end
end

-- ------------------------------------------------------------------- debug --
-- The debug class is deliberately NOT snapshotted: the campaign script reads it
-- live, which is what makes it usable mid-campaign.

local o_log = m:add_new_option("log_accrual", "checkbox")
o_log:set_text("Log every reputation gain")
o_log:set_tooltip_text("Writes a line to script_log.txt each time any faction "
    .. "earns reputation. Noisy, and read live rather than frozen into the save, so "
    .. "it can be turned on in a running campaign.")
o_log:set_default_value(false)
o_log:set_assigned_section("debug")
-- EACH PLAYER'S OWN, in multiplayer too. A global option is left out of MCT's host sync
-- and left unlocked on a client - the same call MCT makes for its own logging switches.
-- It only writes to this machine's log, so it cannot desync anything.
o_log:set_is_global(true)

-- Action buttons fire a custom event rather than calling into the mod: this file
-- runs in MCT's environment and cannot see GG.
--
-- "button" IS NOT AN MCT OPTION TYPE. add_new_option(key, "button") is refused with
-- `option type provided [button] is not a valid type`, add_new_option returns false,
-- and the next line indexes nil - which fails the WHOLE settings file, so MCT
-- disables the mod until the next game start. The nine real types, read out of
-- groovy_mct.pack/script/groovy/modules/mct/objects/options/types/, are: action,
-- checkbox, dropdown, dropdown_game_object, dummy, multibox, radio_button, slider,
-- text_input.
--
-- An action button has its own constructor, signed
-- add_new_action(option_key, button_text, callback) - it wraps the "action" type and
-- sets the callback itself, so there is no add_option_set_callback here.
local o_dump = m:add_new_action("dump_standings", "Write every reputation to the log", function()
    if core and core.trigger_custom_event then
        core:trigger_custom_event("DerpyGGDumpStandings", {})
    end
end)
o_dump:set_tooltip_text("Writes every faction's reputation to script_log.txt. Does "
    .. "nothing outside a campaign.")
o_dump:set_assigned_section("debug")

-- ------------------------------------------------------- locking the numbers --
-- THIS BLOCK MUST COME LAST. m:get_option_by_key answers nil for an option that has not
-- been registered yet, and the loop below would then silently lock nothing.
--
-- The list is every NUMERIC key, which is exactly the set GG.PRESETS is allowed to name.
-- If a slider is added above without being added here it stays editable under a preset
-- that overrides it - the player sets a number, the preset wins, and nothing says so.
local PRESET_OWNED = {
    "rate_brass", "rate_immortals", "rate_daemonsmiths",
    "rate_khanate", "rate_overseers", "rate_slavers",
    "cap_brass", "cap_immortals", "cap_daemonsmiths",
    "cap_khanate", "cap_overseers", "cap_slavers",
    "rate_missions", "rate_bounty", "rate_rivalry", "rate_patron",
    "demand_every", "demand_turns", "demand_reward", "demand_penalty",
    "rate_decay", "decay_from", "rate_bounty_fail",
}
local CUSTOM_ONLY = "Set by the difficulty above. Choose Custom to edit it."

local function relock()
    local custom = o_preset:get_finalized_setting() == "custom"
    for _, k in ipairs(PRESET_OWNED) do
        local o = m:get_option_by_key(k)
        if o then
            if IN_CAMPAIGN then
                o:set_locked(true, LOCK_REASON)
            elseif not custom then
                o:set_locked(true, CUSTOM_ONLY)
            else
                o:set_locked(false)
            end
        end
    end
    if IN_CAMPAIGN then o_preset:set_locked(true, LOCK_REASON) end
end

-- The callback fires on MctOptionSelectedSettingSet, BEFORE the value is finalized, so it
-- reads the selected setting rather than the finalized one.
o_preset:add_option_set_callback(function(opt)
    if IN_CAMPAIGN then return end
    local custom = opt:get_selected_setting() == "custom"
    for _, k in ipairs(PRESET_OWNED) do
        local o = m:get_option_by_key(k)
        if o then
            if custom then o:set_locked(false)
            else o:set_locked(true, CUSTOM_ONLY) end
        end
    end
end)
core:add_listener("derpy_gg_mct_ready", "MctFinalized", true,
    function() relock() end, false)
relock()
