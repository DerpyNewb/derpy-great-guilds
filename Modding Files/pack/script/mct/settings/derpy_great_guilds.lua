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
m:set_description("Earn Favour with seven guilds during your campaign and spend "
    .. "it on their services. Settings are fixed when a campaign starts. "
    .. "Change them from the main menu before starting a new one. In multiplayer, "
    .. "every player uses the host's settings.")

-- MCT HAS NO CAMPAIGN GATING OF ITS OWN. set_context_specific is an empty
-- function body and set_local_only is commented out end to end, so both read as
-- gating and gate nothing. The real defence is the snapshot the campaign script
-- writes at the first tick; the lock below is only the warning.
local IN_CAMPAIGN = __game_mode == __lib_type_campaign
local LOCK_REASON = "Fixed when a campaign starts. Change it from the main "
    .. "menu before starting a new one."

m:add_new_section("preset", "Difficulty")
m:add_new_section("systems", "Systems")
m:add_new_section("court", "The Court")
m:add_new_section("rates", "Earn rates")
m:add_new_section("caps", "Limit per turn")
m:add_new_section("display", "Display")
m:add_new_section("debug", "Debug")

-- ----------------------------------------------------------------- difficulty --
-- ONE DROPDOWN THAT OWNS THE NUMBERS. Thirty of the values below are difficulty
-- (PRESET_OWNED); pick anything but Custom and the preset sets all of them and greys them.
--
-- THE SWITCHES IN "Systems" ARE NOT LOCKED BY A PRESET and are read on every one of
-- them. The Zharr Exchange's presets own its checkboxes too, so under any preset but
-- Custom every checkbox in that mod is inert - and a switch that silently does nothing is
-- a defect this mod has already shipped once. Difficulty is not the same question as
-- whether you want feed notices.
local o_preset = m:add_new_option("preset", "dropdown")
o_preset:set_text("Difficulty")
o_preset:set_tooltip_text("How fast you earn Reputation and how hard the Court presses. "
    .. "Fixed when a campaign starts: change it from the main menu before starting "
    .. "a new one. You can change the Systems switches on every difficulty.")
o_preset:set_assigned_section("preset")
o_preset:add_dropdown_value("easy", "Easy",
    "A faster climb and a gentler Court. About half again as much Reputation per event "
    .. "and higher limits per turn. Demands come a third less often, with half again as "
    .. "long to answer and half the penalty for missing one. Rivalry costs half as much, "
    .. "making it easier to court several guilds.", false)
o_preset:add_dropdown_value("default", "Default",
    "The Guilds' original rates, limits and Court terms.", true)
o_preset:add_dropdown_value("hard", "Hard",
    "A slower climb and a demanding Court. About a quarter less Reputation per event with "
    .. "lower limits per turn, demands every nine turns with six to answer, and an "
    .. "ignored demand costing half again what it does on Default.", false)
o_preset:add_dropdown_value("ultra", "Brutal",
    "Reputation comes at roughly half the Default rate with limits to match, "
    .. "rivalry costs more than double, and the Court asks every six turns with five "
    .. "to answer. Missing a demand costs more than meeting it earns. Concentrate on "
    .. "fewer guilds to survive.", false)
o_preset:add_dropdown_value("custom", "Custom",
    "Choose every rate, limit and Court value below before starting a campaign. "
    .. "They stay fixed throughout it.", false)
o_preset:set_default_value("default")

-- ------------------------------------------------------------------ systems --

local o_ai = m:add_new_option("ai_spending", "checkbox")
o_ai:set_text("Rival factions use the guilds")
o_ai:set_tooltip_text("Rivals earn Reputation, buy services (some can target you), "
    .. "answer guild demands and appoint patrons. Off: rivals still earn Reputation "
    .. "and compete for leadership, but never buy services, answer demands or appoint patrons.")
o_ai:set_default_value(true)
o_ai:set_assigned_section("systems")
-- LOCKED IN A CAMPAIGN like every other setting: every switch below is frozen into
-- the save at the first tick, so a box ticked mid-campaign changed nothing and said
-- nothing (logic audit, 2026-09-29).
if IN_CAMPAIGN then o_ai:set_locked(true, LOCK_REASON) end

local o_aib = m:add_new_option("ai_bounties", "checkbox")
o_aib:set_text("Rivals take bounties")
o_aib:set_tooltip_text("Rivals of your race take guild bounties and earn Reputation for "
    .. "completing them. A rival at war with you may be paid to take your settlements "
    .. "or kill your lords. You are told when, and by whom. Requires "
    .. "\"Rival factions use the guilds\" on.")
o_aib:set_default_value(true)
o_aib:set_assigned_section("systems")
if IN_CAMPAIGN then o_aib:set_locked(true, LOCK_REASON) end

local o_halls = m:add_new_option("guild_halls", "checkbox")
o_halls:set_text("Guild halls")
o_halls:set_tooltip_text("Factions whose races have guild halls can build them in "
    .. "settlements. Off: no new halls; existing halls remain but give no benefits.")
o_halls:set_default_value(true)
o_halls:set_assigned_section("systems")
if IN_CAMPAIGN then o_halls:set_locked(true, LOCK_REASON) end

local o_hrep = m:add_new_option("hall_rep", "slider")
o_hrep:set_text("Reputation from halls (%)")
o_hrep:set_tooltip_text("Reputation each hall pays every turn, as a percentage of the "
    .. "standard amount. 100 pays the full amount; 0 pays none.")
o_hrep:slider_set_min_max(0, 300)
o_hrep:slider_set_step_size(10)
o_hrep:set_default_value(100)
o_hrep:set_assigned_section("systems")
if IN_CAMPAIGN then o_hrep:set_locked(true, LOCK_REASON) end

local o_hoff = m:add_new_option("hall_off", "slider")
o_hoff:set_text("Price cut per hall (%)")
o_hoff:set_tooltip_text("Each hall reduces the price of its guild's services by this "
    .. "percentage, up to 15% in total.")
o_hoff:slider_set_min_max(0, 10)
o_hoff:slider_set_step_size(1)
o_hoff:set_default_value(3)
o_hoff:set_assigned_section("systems")
if IN_CAMPAIGN then o_hoff:set_locked(true, LOCK_REASON) end

local o_rot = m:add_new_option("rotate_turns", "slider")
o_rot:set_text("Services change every")
o_rot:set_tooltip_text("Turns between changes to the services on offer. Each guild "
    .. "offers three at a time, chosen from a larger set.")
o_rot:slider_set_min_max(5, 30)
o_rot:slider_set_step_size(1)
o_rot:set_default_value(10)
o_rot:set_assigned_section("systems")
if IN_CAMPAIGN then o_rot:set_locked(true, LOCK_REASON) end

local o_race = m:add_new_option("race_differences", "checkbox")
o_race:set_text("Race differences")
o_race:set_tooltip_text("Each race has its own guild services, an extra way to earn and "
    .. "one rule changed. Off: every race plays alike; services still change over time.")
o_race:set_default_value(true)
o_race:set_assigned_section("systems")
if IN_CAMPAIGN then o_race:set_locked(true, LOCK_REASON) end

local o_hostile = m:add_new_option("hostile_services", "checkbox")
o_hostile:set_text("Guilds can be turned on you")
o_hostile:set_tooltip_text("Allows services aimed at other factions: those that raise an enemy's costs, "
    .. "and strikes against enemy settlements. Off: nobody may buy them, including you.")
o_hostile:set_default_value(true)
o_hostile:set_assigned_section("systems")
if IN_CAMPAIGN then o_hostile:set_locked(true, LOCK_REASON) end

local o_notices = m:add_new_option("guild_notices", "checkbox")
o_notices:set_default_value(true)
o_notices:set_text("Guild notices")
o_notices:set_tooltip_text("Announces new ranks, a guild first taking notice of you "
                           .. "and changes to services on the event feed. Demands, "
                           .. "losing a guild's lead and a rival's service used against you "
                           .. "are always announced.")
o_notices:set_assigned_section("systems")
if IN_CAMPAIGN then o_notices:set_locked(true, LOCK_REASON) end

local o_mono = m:add_new_option("lead_monopoly", "checkbox")
o_mono:set_text("Only the leader buys the finest service")
o_mono:set_tooltip_text("Only the faction with the most Reputation in a guild can buy "
    .. "its finest service. Off: anyone with the required rank may buy it, "
    .. "and the leader keeps their bonus.")
o_mono:set_default_value(true)
o_mono:set_assigned_section("systems")
if IN_CAMPAIGN then o_mono:set_locked(true, LOCK_REASON) end

-- ------------------------------------------------------------------- court --
-- The demands, the patron, and the upkeep. These are the things that can take reputation
-- away on a clock, so every clock is tunable and 0 turns each one off.

local COURT = {
    {"demand_every", "Turns between demands", 12, 0, 60,
     "Turns between guild demands. 0 switches demands off."},
    {"demand_turns", "Turns to pay a demand", 8, 2, 30,
     "Miss this deadline and you lose Reputation with the demanding guild."},
    {"demand_reward", "Reputation for paying", 120, 0, 400,
     "Reputation earned with the guild for meeting its demand."},
    {"demand_penalty", "Reputation for refusing", 60, 0, 400,
     "Reputation lost with the guild when you miss its deadline. You may lose "
     .. "a rank and its bonus."},
    {"rate_patron", "Patron's share", 50, 0, 200,
     "Extra Reputation, as a percentage, with your patron's guild. Its limit per "
     .. "turn still applies."},
    {"rate_decay", "Upkeep", 100, 0, 400,
     "Each guild charges Reputation every turn according to your rank. At 100, "
     .. "rank 1 costs 1 Reputation a turn and rank 5 costs 5. 0 switches upkeep "
     .. "off: only rivalry, demands and failed bounties can then reduce Reputation."},
    {"decay_from", "Upkeep begins on turn", 25, 0, 200,
     "No upkeep is charged before this turn. 0 switches upkeep off."},
    {"rate_bounty_fail", "Failed bounty costs", 100, 0, 300,
     "Reputation lost for missing an accepted bounty's deadline, as a percentage "
     .. "of its reward. At 100, failure costs as much as success pays. Ignoring an "
     .. "offer or handing it back costs no Reputation. 0 switches this loss off."},
    {"rate_bounty_stake", "Bounty stake", 25, 0, 100,
     "Favour paid to accept a bounty, as a percentage of its Reputation reward. "
     .. "Complete it to get the stake back; fail or hand it back to lose it. "
     .. "0 switches stakes off."},
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
-- One slider per guild, and four for the temple's earn routes. These are the Reputation
-- and Favour paid per event, and
-- they are STARTING VALUES rather than measurements - the design says so plainly.
--
-- NAMED BY ROLE, because the frontend has no race to name them for. In a campaign
-- GGUI.name_mct renames the guild sliders (rate_<guild> and cap_<guild>, thirteen) to the
-- player's own flavour at the first tick. The temple's four route sliders keep their
-- role label: each race earns from its temple by different routes, so a race name on
-- them could promise a route that race does not have. gen_great_guilds.py checks these
-- labels against its generic flavour.

local RATES = {
    {"rate_brass", "The Merchant Houses", 250, 50, 1000,
     "Net income in gold for each point of Reputation. Lower earns faster."},
    {"rate_immortals", "The Veterans' Company", 15, 1, 60, "Reputation per battle won."},
    {"rate_daemonsmiths", "The Artisans' Guild", 60, 5, 200,
     "Reputation per technology researched."},
    {"rate_khanate", "The Shadow Guild", 8, 1, 40,
     "Reputation per successful hero action."},
    {"rate_overseers", "The Builders' Guild", 10, 1, 40,
     "Reputation per completed building level, paid to the guild named on its card."},
    {"rate_slavers", "The Raiders' Guild", 25, 1, 100,
     "Reputation per settlement sacked. Razing pays 60% more."},
    {"rate_temple_devout", "The Faith Guild: provinces in good order", 1, 0, 10,
     "Reputation per province with public order above zero, every turn."},
    {"rate_temple_chaos", "The Faith Guild: provinces free of corruption", 2, 0, 10,
     "Reputation per province with no Chaos corruption, every turn."},
    {"rate_temple_holy", "The Faith Guild: holy wars", 10, 0, 60,
     "Reputation per battle won against the faith's sworn enemies."},
    {"rate_temple_taint", "The Faith Guild: tainted provinces", 2, 0, 10,
     "Reputation per province carrying Skaven corruption, every turn. Skaven only."},
    -- Not a guild: the one signal that pays EVERY GUILD. Each guild's own per-turn cap
    -- still applies, so this cannot be used to outrun them.
    {"rate_missions", "Missions (every guild)", 10, 0, 60,
     "Reputation earned with every guild for completing a mission. 0 switches this off."},
    -- The bounty board's pay. An order of magnitude above the blanket rate because a
    -- bounty is chosen, targeted and timed. 0 empties the board entirely.
    {"rate_bounty", "Bounties (the posting guild)", 80, 0, 400,
     "Reputation earned with the posting guild for completing a bounty. "
     .. "0 empties the bounty board."},
    -- Not an earn rate at all, but it belongs beside them: it is the price of one.
    -- The only setting here that can take reputation AWAY, so 0 is a real choice and
    -- turns the guilds back into independent counters.
    {"rate_rivalry", "Rivalry (cost to the rival)", 40, 0, 100,
     "Reputation lost with a guild when you earn with its rival, as a percentage of what "
     .. "you earned. "
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
    {"cap_temple", "The Faith Guild", 40},
}

for i = 1, #CAPS do
    local key, label, def = unpack(CAPS[i])
    local o = m:add_new_option(key, "slider")
    o:set_text(label .. " limit")
    o:set_tooltip_text("Most Reputation this guild pays in one turn. 0 removes "
        .. "the limit.")
    o:slider_set_min_max(0, 400)
    o:slider_set_step_size(5)
    o:set_default_value(def)
    o:set_assigned_section("caps")
    if IN_CAMPAIGN then o:set_locked(true, LOCK_REASON) end
end

-- ----------------------------------------------------------------- display --
-- DISPLAY ONLY, so never locked and never frozen into the save: the panel reads it live on
-- every open. On top of the automatic size, which already grows the panel on screens
-- larger than 1080p. Three sizes and not a slider: each is its own set of panel files with
-- real font sizes, because stretching text drew it soft (2026-10-08).
local o_size = m:add_new_option("ui_size", "dropdown")
o_size:set_text("Panel size")
o_size:set_tooltip_text("Size of the Great Guilds panel and its text. Takes effect the next "
    .. "time you open the panel. Large needs a screen at least 1080 pixels tall at your "
    .. "UI scale; on a smaller one the panel opens at Medium. On a screen larger than "
    .. "1080p the panel already grows to fit, so some sizes look the same there: at 1440p "
    .. "Medium and Large match, and at 4K all three do.")
-- Keys must match GGUI.SIZES in zzz_derpy_guilds_ui.lua; gen_guilds_ui.check_sizes pins them.
o_size:add_dropdown_value("small", "Small", "About a seventh smaller than the standard size.", false)
o_size:add_dropdown_value("medium", "Medium", "The standard size.", true)
o_size:add_dropdown_value("large", "Large", "A third larger than the standard size.", false)
o_size:set_default_value("medium")
o_size:set_assigned_section("display")
-- Each player's own in multiplayer, like the log switch below: it only changes this
-- machine's screen.
o_size:set_is_global(true)

-- ------------------------------------------------------------------- debug --
-- The debug class is deliberately NOT snapshotted: the campaign script reads it
-- live, which is what makes it usable mid-campaign.

local o_log = m:add_new_option("log_accrual", "checkbox")
o_log:set_text("Log every Reputation gain")
o_log:set_tooltip_text("Writes to script_log.txt whenever a faction earns Reputation. "
    .. "Produces many entries; you can switch it on during a campaign.")
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
local o_dump = m:add_new_action("dump_standings", "Write every Reputation to the log", function()
    if core and core.trigger_custom_event then
        core:trigger_custom_event("DerpyGGDumpStandings", {})
    end
end)
o_dump:set_tooltip_text("Writes every faction's Reputation to script_log.txt. Does "
    .. "nothing outside a campaign.")
o_dump:set_assigned_section("debug")

-- ------------------------------------------------------- locking the numbers --
-- THIS BLOCK MUST COME LAST. m:get_option_by_key answers nil for an option that has not
-- been registered yet, and the loop below would then silently lock nothing.
--
-- The list is every numeric key a preset sets, which is exactly the set GG.PRESETS is
-- allowed to name; rotate_turns and hall_off are read on every preset (GG.EVERY_PRESET).
-- If a slider is added above without being added here it stays editable under a preset
-- that overrides it - the player sets a number, the preset wins, and nothing says so.
local PRESET_OWNED = {
    "rate_brass", "rate_immortals", "rate_daemonsmiths",
    "rate_khanate", "rate_overseers", "rate_slavers",
    "cap_brass", "cap_immortals", "cap_daemonsmiths",
    "cap_khanate", "cap_overseers", "cap_slavers",
    "rate_missions", "rate_bounty", "rate_rivalry", "rate_patron",
    "demand_every", "demand_turns", "demand_reward", "demand_penalty",
    "rate_decay", "decay_from", "rate_bounty_fail", "rate_bounty_stake",
    "hall_rep",
    "rate_temple_devout", "rate_temple_chaos", "rate_temple_holy", "cap_temple",
    "rate_temple_taint",
}
-- SAYS THE NUMBER IS NOT THE ONE USED: a greyed slider keeps showing its Default (or an
-- earlier Custom) value while the preset plays its own (logic audit, 2026-09-29).
local CUSTOM_ONLY = "The chosen difficulty sets this value; the number shown here "
    .. "is not used. Choose Custom to edit it."

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
