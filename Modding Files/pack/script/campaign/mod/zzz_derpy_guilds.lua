-- The Great Guilds - the ladder.
--
-- Standing is Lua save state, never a pooled resource. A pooled resource would
-- need a campaign_group_pooled_resources row per campaign group for universal
-- coverage, and a missed culture gets nothing with clean diagnostics. See
-- docs/superpowers/specs/2026-09-10-great-guilds-design.md section 2.
--
-- NO LOC CALL MAY EVER HAPPEN IN THIS FILE. A loc call from a turn handler is a
-- CTD at turn 1 and pcall does not catch it. This file stores keys; the panel
-- resolves names at draw time.

GG = GG or {}

GG.GUILDS = {"brass", "immortals", "daemonsmiths", "khanate", "overseers", "slavers"}
GG.RANKS  = {0, 100, 300, 700, 1500}

GG.state = GG.state or {}          -- [faction_key][guild] = {rep, fav}
GG.turn_gain = GG.turn_gain or {}  -- [faction_key][guild] = gained this turn

local function blank()
    local t = {}
    for i = 1, #GG.GUILDS do t[GG.GUILDS[i]] = {rep = 0, fav = 0} end
    return t
end

function GG.rank_of(rep)
    local r = 1
    for i = 1, #GG.RANKS do
        if rep >= GG.RANKS[i] then r = i end
    end
    return r
end

-- THE HOLDER'S FLAVOUR TAG ON THE END: derpy_gg_rank_brass_3 for a Chaos Dwarf faction,
-- derpy_gg_rank_brass_3_emp for an Empire one. A nil faction is the untagged key.
function GG.bundle_key(guild, rank, faction)
    if rank < 2 then return nil end
    return "derpy_gg_rank_" .. guild .. "_" .. rank .. GG.tag(faction)
end

function GG.get(faction, guild)
    local f = GG.state[faction]
    if not f then return 0, 0 end
    local g = f[guild]
    if not g then return 0, 0 end
    return g.rep, g.fav
end

-- WHICH RANK BUNDLE WE BELIEVE IS ON EACH FACTION, this session only.
--
-- DELIBERATELY NOT SAVED. GG.apply_rank fires on a rank CHANGE, which is correct
-- while a campaign runs and useless in every other case: add the mod to a campaign
-- in progress, swap the pack, or load a save written by a build where the bundle
-- never landed, and the state restores at rank 2 with no transition left to detect.
-- Measured at turn 10 on 2026-09-10: daemonsmiths rep 120, rank 2, and NONE of the
-- faction's 23 effect bundles was ours - the row exists, the key resolves, nothing
-- had ever asked for it.
--
-- Because this table starts empty on every load, the first turn start after loading
-- re-asserts each guild's current bundle once and then goes quiet. A saved copy
-- would restore the same wrong belief and heal nothing.
GG.asserted = {}


function GG.assert_ranks(faction)
    local f = GG.state[faction]
    if not f then return end
    GG.asserted[faction] = GG.asserted[faction] or {}
    local seen = GG.asserted[faction]
    for _, guild in ipairs(GG.GUILDS) do
        local g = f[guild]
        if g then
            local rank = GG.rank_of(g.rep)
            if seen[guild] ~= rank then
                -- Clear any other rung's bundle before applying this one: a faction
                -- that reached rank 3 under a build that never removed rank 2 would
                -- otherwise carry both.
                for r = 2, 5 do
                    if r ~= rank then
                        local k = GG.bundle_key(guild, r, faction)
                        if k then cm:remove_effect_bundle(k, faction) end
                    end
                    -- AND THE UNTAGGED COPY, EVERY RANK, on a flavoured faction: a save
                    -- from the build that covered all three races at once has Empire and
                    -- Dwarf AIs wearing it, and it would stack with the tagged one forever.
                    if GG.tag(faction) ~= "" then
                        local k = GG.bundle_key(guild, r)
                        if k then cm:remove_effect_bundle(k, faction) end
                    end
                end
                local key = GG.bundle_key(guild, rank, faction)
                if key then cm:apply_effect_bundle(key, faction, -1) end
                seen[guild] = rank
            end
        end
    end
end


function GG.apply_rank(faction, guild, old_rank, new_rank)
    if new_rank == old_rank then return end
    local old_key = GG.bundle_key(guild, old_rank, faction)
    if old_key then cm:remove_effect_bundle(old_key, faction) end
    local new_key = GG.bundle_key(guild, new_rank, faction)
    -- -1 is indefinite. CA's episodic_scripting doc, verbatim: "-1 may be
    -- supplied to apply the effect indefinitely." 0 means zero turns, which
    -- applies the bundle and then does nothing, silently, forever.
    if new_key then cm:apply_effect_bundle(new_key, faction, -1) end
    GG.asserted[faction] = GG.asserted[faction] or {}
    GG.asserted[faction][guild] = new_rank
end

-- WHO SITS ACROSS THE TABLE FROM WHOM. Three pairs, each written both ways, so the
-- table is its own inverse and a half-declared rivalry is impossible. The pairings are
-- the ones the guilds argue about: the Brass Tablets keep the ledgers the Khanate's
-- hobgoblins rob, the Daemonsmiths want the work the Immortals want the bodies for, and
-- the Overseers want hands where the Slavers want a column that marches away.
GG.RIVALS = {
    brass        = "khanate",      khanate      = "brass",
    immortals    = "daemonsmiths", daemonsmiths = "immortals",
    overseers    = "slavers",      slavers      = "overseers",
}

-- Reputation lost by a guild whose rival just earned, as a percentage of that earning.
-- Applied AFTER the gain, so a turn that pays both sides of a pair nets out rather than
-- depending on which listener happened to fire first.
--
-- A rank can fall through this. GG.apply_rank is symmetric - it removes the old bundle
-- and applies the new whichever direction the move is - so a demotion takes the ladder
-- buff away exactly as a promotion granted it.
function GG.rival_cost(faction, guild, amount)
    local rival = GG.RIVALS[guild]
    if not rival or not amount or amount <= 0 then return 0 end
    local share = GG.setting("rate_rivalry")
    if not share or share <= 0 then return 0 end

    local tracks = GG.state[faction]
    local t = tracks and tracks[rival]
    if not t or t.rep <= 0 then return 0 end

    -- Floor of 1, so a small gain still costs something rather than rounding to free.
    local loss = math.floor(amount * share / 100)
    if loss < 1 then loss = 1 end

    -- NEVER BELOW THE RANK ALREADY REACHED.
    --
    -- The three pairs are symmetric on paper and are not in play. GG.on_turn_start
    -- grants brass from net income EVERY TURN to EVERY faction and nothing else in this
    -- mod pays out passively, so brass's rival the khanate took 40% of that income
    -- forever against an income of its own that an AI essentially never earns. Measured
    -- against this file with default tunables: a rival with income and nothing else was
    -- on khanate 0 by turn 50 and stayed there, and one winning a battle every other
    -- turn, raising a building every third and finishing a technology every sixth still
    -- ended turn 60 with khanate 8 and slavers 0. Every rival read as a column of zeros
    -- on the Standings tab, which is what sent somebody looking.
    --
    -- So rivalry may push a guild DOWN WITHIN the rank it holds and no further.
    -- Standing that has been earned stays earned; rivalry costs progress, not history.
    --
    -- HERE AND NOT IN GG.penalise, which is the one funnel every loss goes through and
    -- is therefore the tempting place for it. GG.decay is the clock this mod was
    -- deliberately given - dawdling is meant to reverse a guild, not merely delay one -
    -- and a floor in the funnel would make GG.apply_rank's demotion path dead code and
    -- the ladder a ratchet nothing could ever undo. The harness tests the two apart for
    -- exactly that reason.
    --
    -- AND BELOW INDEBTED, NOTHING AT ALL (2026-09-23, the author's choice). Rank 1's
    -- threshold is 0, so the floor alone let rivalry take an Unmarked guild to nothing -
    -- and brass earns from income every turn, so the khanate never left 0: the Conclave
    -- player held khanate 0 with 200 unspendable favour at turn 83, and every AI faction
    -- the same. Once buildings began paying (same date) the overseers did it to the
    -- slavers too. Soaked over 83 turns: khanate 0 -> 69, slavers 13 -> 102, the other
    -- four within 20. Upkeep is untouched and still bites from decay_from.
    if GG.rank_of(t.rep) < 2 then return 0 end
    -- ONE TURN'S UPKEEP ABOVE THE THRESHOLD, not on it. A floor ON the threshold left the
    -- next turn start's upkeep to finish the job: pinned at 100, charged 2, demoted at 98,
    -- then re-promoted by the next earn with a second popup (Azeros, turns 31-33, 2026-09-23).
    local rank = GG.rank_of(t.rep)
    local floor_at = (GG.RANKS[rank] or 0) + GG.decay_amount(rank)
    if t.rep <= floor_at then return 0 end
    if loss > t.rep - floor_at then loss = t.rep - floor_at end
    return GG.penalise(faction, rival, loss)
end

-- THE ONLY ROUTINE THAT TAKES REPUTATION AWAY. Rivalry used to own this arithmetic and
-- demands need the identical thing - clamp to what is actually held, then re-apply the
-- rank, because a fall through a threshold must remove the bundle exactly as a rise
-- granted it. GG.apply_rank is symmetric, so this is the whole of a demotion.
function GG.penalise(faction, guild, amount)
    if not amount or amount <= 0 then return 0 end
    local f = GG.state[faction]
    local t = f and f[guild]
    if not t or t.rep <= 0 then return 0 end
    if amount > t.rep then amount = t.rep end
    local before = GG.rank_of(t.rep)
    t.rep = t.rep - amount
    local after = GG.rank_of(t.rep)
    GG.apply_rank(faction, guild, before, after)
    -- The only record a fall gets: GG.announce_rank announces promotions only.
    if after ~= before then GG.log_add(faction, "rank", guild, before, after) end
    return amount
end

-- ------------------------------------------------------------------- upkeep --
-- WHAT STANDING COSTS TO HOLD, per guild, per turn.
--
-- Taken from Medieval 2, which bleeds every guild in every city 1 point a turn from turn
-- 25 on. It reads as nothing and it is not: by turn 125 that is 100 points gone, a whole
-- tier's worth. What it buys is that guild progress is a RACE - dawdling does not merely
-- delay a guild, it reverses one - and this mod had no clock at all. Reputation only ever
-- fell to a rival earning or a demand going unanswered, so an AI that banked 400 with the
-- Brass Tablets on turn 30 held the guild, its bundle and its monopoly for the rest of the
-- campaign unless somebody out-earned it outright.
--
-- SCALED BY RANK, where Medieval 2 charges a flat point. Its tiers are 100/250/500 and
-- ours are 0/100/300/700/1500, so a flat 1 a turn is 1% of the first rank and 0.07% of the
-- last - the top of the ladder would be the one place the clock stopped. Charging the rank
-- index (1 at Unmarked, 5 at Exalted) keeps the pressure proportional the whole way up and
-- makes the top expensive to sit on, which is the same thing said from the guild's side.
--
-- REPUTATION ONLY, NEVER FAVOUR. Favour is the currency and it is already capped at twice
-- the rank threshold, which is its own pressure to spend; charging upkeep against it would
-- punish the same turn twice and make a saved-up purchase impossible rather than costly.
function GG.decay_amount(rank)
    local share = GG.setting("rate_decay")
    if not share or share <= 0 then return 0 end
    if not rank or rank < 1 then return 0 end
    local n = math.floor(rank * share / 100)
    -- Floor of 1, so a low rate still costs something rather than rounding to free - the
    -- same rule GG.rival_cost uses, for the same reason.
    if n < 1 then n = 1 end
    return n
end

-- A GRACE PERIOD, because an upkeep running from turn 1 is not a clock, it is a tax on
-- the opening. Medieval 2 starts at turn 25 and that number is kept.
function GG.decay_due(turn)
    local from = GG.setting("decay_from")
    if not from or from <= 0 then return false end
    if type(turn) ~= "number" then return false end
    return turn >= from
end

-- Called once per faction turn, for every faction with standing. Returns the total taken,
-- so a test and the trace can read it without a panel.
--
-- WALKS GG.state, NOT THE ROSTER. A faction only enters GG.state once it has earned, so
-- this charges exactly the factions that have something to lose and touches nothing else.
-- It is deliberately NOT gated on GG.covered: a save carried over from a build with a
-- different scope holds rows for factions outside the race, and those should drain away
-- rather than sit at a rank forever with a leadership bundle attached.
function GG.decay(faction, turn)
    if not GG.decay_due(turn) then return 0 end
    local tracks = GG.state[faction]
    if not tracks then return 0 end
    local took = 0
    for i = 1, #GG.GUILDS do
        local guild = GG.GUILDS[i]
        local t = tracks[guild]
        if t and t.rep > 0 then
            -- Read the rank BEFORE the charge. GG.penalise floors at the reputation held
            -- and handles the demotion, so a guild at 2 reputation loses 2 and not 5.
            took = took + GG.penalise(faction, guild, GG.decay_amount(GG.rank_of(t.rep)))
        end
    end
    return took
end

-- `source` is which of GG.LEDGER_SOURCES paid it, for the panel's "Reputation this turn"
-- line. Every caller names one; a caller that forgets shows up there as "other".
function GG.grant(faction, guild, amount, source)
    if not amount or amount <= 0 then return end
    GG.state[faction] = GG.state[faction] or blank()
    local g = GG.state[faction][guild]
    if not g then return end          -- unknown guild is a no-op, never an error
    GG.ledger_add(faction, guild, source, amount)
    local before = GG.rank_of(g.rep)
    g.rep = g.rep + amount
    local after = GG.rank_of(g.rep)
    -- Cap favour at twice the current rank's threshold. Self-scaling, and it
    -- pressures spending rather than banking. Rank 1's threshold is 0, so the
    -- floor keeps a brand new faction able to hold a tier-1 service price.
    local cap = GG.RANKS[after] * 2
    if cap < 200 then cap = 200 end
    g.fav = g.fav + amount
    if g.fav > cap then g.fav = cap end
    GG.apply_rank(faction, guild, before, after)
    -- AFTER apply_rank, so the bundle the message promises is already on the faction when
    -- the player clicks through to look. Before rival_cost, which can only subtract and
    -- therefore cannot promote anyone.
    GG.announce_rank(faction, guild, before, after)
    if after ~= before then GG.log_add(faction, "rank", guild, before, after) end
    -- THE OPENING. Both are one-time and both are cheap to skip: notice_once returns on a
    -- saved flag before it touches anything else, and the halfway test is one comparison.
    --
    -- `before` is the rank BEFORE this grant, so the halfway notice cannot fire for a
    -- faction that is already past the first rank - which is what stops it appearing at
    -- turn 40 for the fifth guild a large empire happens to start earning with.
    GG.notice_once(faction, "first", guild)
    -- before < 2 is "below Indebted": ranks are 1-based and rank 1 is Unmarked.
    if before < 2 then
        local half = GG.RANKS[2] / 2
        if g.rep >= half and (g.rep - amount) < half then
            GG.notice_once(faction, "half", guild)
        end
    end
    -- Last, and never recursive: rival_cost only ever SUBTRACTS, so it cannot re-enter
    -- here. Putting it before apply_rank would let a demotion on the rival fight a
    -- promotion on this guild for the same faction in the same call.
    GG.rival_cost(faction, guild, amount)
end

function GG.spend(faction, guild, amount)
    local f = GG.state[faction]
    if not f or not f[guild] then return false end
    if f[guild].fav < amount then return false end
    f[guild].fav = f[guild].fav - amount
    return true
end

-- Per-turn ceilings. 0 means no cap. These mirror RATES in
-- tools/gen_great_guilds.py; if one changes, change both.
--
-- The caps are not decoration. Without them, income-scaled reputation lets a
-- large empire max brass passively while a small one never climbs.
GG.CAP = {brass = 40, immortals = 60, daemonsmiths = 0,
          khanate = 40, overseers = 40, slavers = 80}

function GG.reset_turn(faction)
    GG.turn_gain[faction] = {}
end

-- READ LIVE FROM MCT, not through GG.setting. Every other setting is frozen into the
-- save at the first turn - that is deliberate, an economy that changes under a running
-- campaign is not an economy - but this one is a debug switch whose whole point is being
-- turned on midway, and its own tooltip promises exactly that.
--
-- The MCT walk costs a pcall and three calls per grant. Grants are a handful per faction
-- per turn, so this is cheaper than caching it correctly would be.
function GG.logging()
    local ok, on = pcall(function()
        local mct = get_mct and get_mct()
        if not mct then return false end
        local mod = mct:get_mod_by_key("derpy_great_guilds")
        if not mod then return false end
        local opt = mod:get_option_by_key("log_accrual")
        if not opt then return false end
        return opt:get_finalized_setting() == true
    end)
    return ok and on == true
end

function GG.capped_grant(faction, guild, amount, source)
    if not amount or amount <= 0 then return end
    -- THE ONE FUNNEL EVERY PASSIVE EARN ROUTE GOES THROUGH, which is why the culture
    -- gate lives here rather than in six listeners. The bounty payout calls GG.grant
    -- directly and is human-only, so it needs no gate of its own.
    if not GG.covered(faction) then return end
    -- THE PATRON'S SHARE, applied BEFORE the cap. A patron earns you more of what a
    -- guild pays; it does not let you outrun that guild's per-turn ceiling, which is
    -- the one thing keeping a large empire from maxing a guild passively.
    local p = GG.patrons[faction]
    if p and p.guild == guild then
        local share = GG.setting("rate_patron") or 0
        if share > 0 then amount = amount + math.floor(amount * share / 100) end
    end
    -- The MCT-tunable cap, falling back to GG.CAP when no snapshot exists yet.
    local cap = GG.setting("cap_" .. guild)
    if cap == nil then cap = GG.CAP[guild] or 0 end
    if cap > 0 then
        GG.turn_gain[faction] = GG.turn_gain[faction] or {}
        local so_far = GG.turn_gain[faction][guild] or 0
        -- WHAT THE CAP KEPT BACK IS WRITTEN DOWN. Without it a market finished on a turn
        -- the income already filled the Brass cap pays nothing and says nothing.
        if so_far >= cap then
            GG.ledger_add(faction, guild, "withheld", amount)
            return
        end
        if so_far + amount > cap then
            GG.ledger_add(faction, guild, "withheld", so_far + amount - cap)
            amount = cap - so_far
        end
        GG.turn_gain[faction][guild] = so_far + amount
    end
    GG.grant(faction, guild, amount, source)
    -- The line the MCT's debug checkbox promises. Behind GG.logging() because it is one
    -- line per grant per faction per turn, which is noise nobody wants by default.
    if GG.logging() then
        GG.trace(tostring(faction) .. " earned " .. amount .. " with " .. tostring(guild)
                 .. " (now " .. tostring(select(1, GG.get(faction, guild))) .. ")")
    end
end

-- The six earn signals. Every hook name was confirmed present in CA's own docs
-- on 2026-09-10. math.floor everywhere: WH3 Lua is float32, so 1.05 evaluates
-- as 1.0499999523163 and a .5 boundary falls the wrong way.

function GG.on_turn_start(faction, net_income)
    if not net_income or net_income <= 0 then return end
    GG.capped_grant(faction, "brass",
                    math.floor(net_income / (GG.setting("rate_brass") or 250)), "income")
end

function GG.on_battle(faction, outnumbered)
    local base = GG.setting("rate_immortals") or 15
    GG.capped_grant(faction, "immortals", outnumbered and (base * 2) or base, "battles")
end

function GG.on_tech(faction)
    GG.capped_grant(faction, "daemonsmiths", GG.setting("rate_daemonsmiths") or 60,
                    "research")
end

-- THE AI'S DAEMONSMITHS, off faction:num_completed_technologies() at its own turn start.
--
-- ResearchCompleted NEVER REACHES AN AI FACTION. Measured 2026-09-23: gg_tech saves
-- derpy_gg_research_<faction> unconditionally, and across two campaigns (turns 24 and 83)
-- only the human ever had the key, while every AI faction of the player's culture sat at
-- Daemonsmiths 0,0 - so the player led the guild unopposed for the whole game. The count
-- is the one documented reading that reaches the AI; the event stays the human's route,
-- because it lands the moment the research does and the panel is open to see it.
--
-- THE FIRST COUNT IS A BASELINE, NOT INCOME. Without that, the first turn after this
-- shipped would pay every AI faction for every technology it already had.
function GG.on_tech_count(faction, n)
    if not faction or type(n) ~= "number" or n < 0 then return end
    local key = "derpy_gg_techs_" .. faction
    local seen = cm:get_saved_value(key)
    cm:set_saved_value(key, n)
    if type(seen) ~= "number" then return end
    -- One grant per technology, not one grant of the product, so each pays its own
    -- rivalry share exactly as a ResearchCompleted would.
    for _ = 1, n - seen do GG.on_tech(faction) end
end

function GG.on_agent_action(faction, success)
    if not success then return end
    GG.capped_grant(faction, "khanate", GG.setting("rate_khanate") or 8, "agents")
end

-- WHICH GUILD A BUILDING BELONGS TO.
--
-- Every completed building used to pay the Overseers and nothing else, so a forge going up
-- was invisible to the Daemonsmiths and a dock to the Brass Tablets. Medieval 2 scores a
-- building toward ITS OWN guild - a Merchants Wharf is worth 20 to the Merchants and
-- nothing to anyone else - and that is the half of its system that makes what you build a
-- choice rather than a counter.
--
-- MATCHED ON SUBSTRINGS OF THE CHAIN KEY, which is the only signal here that is both
-- culture-agnostic and stable. Three routes were measured against all 5,259 vanilla
-- building levels before this one was picked:
--
--   * THE SUPERCHAIN KEY is useless: 799 of 804 keys are unique, so there is no shared
--     vocabulary to match at all.
--   * THE BUILDING'S EFFECTS look ideal - effect keys ARE shared across cultures - and
--     are not: a chain's higher levels gain effects its first level does not have, so the
--     guild CHANGED AS YOU UPGRADED. Measured: wh3_dlc23_chd_resource_gold_1 read as
--     trade and _2 and _3 as military. Counting effects fails for a second reason - the
--     commonest effects are the least meaningful, so a farm carrying growth and
--     replenishment tied 1-1 and was decided by whichever list claimed replenishment.
--   * THE CHAIN KEY is one string per chain, identical at every level, and its words are
--     shared across cultures by CA's own naming: `resource` appears in 386 chains,
--     `settlement` in 202, `port` in 61, `military` in 29.
--
-- SO A MOD'S BUILDINGS WORK WITHOUT BEING LISTED. No chain key appears below - only words
-- - so a chain some mod invents tomorrow is themed the moment its name contains one, which
-- is the same reason the culture scope is read off the player rather than listed.
--
-- LONGEST MATCH WINS, not list order. The keys are compounds and the tokens collide inside
-- them: `wh3_dlc23_chd_factory_port` holds both `factory` and `port`, and
-- `wh3_dlc23_chd_military_kdaai` holds both `military` and a unit name. Order alone
-- decided those by accident of position; length decides them by specificity, with order
-- only as a tie-break. Verified against all 44 Chaos Dwarf chains, of which 43 land where
-- a player would put them and one - allied_outpost - falls through to the default.
-- EVERY TOKEN HERE MATCHES A CHAIN CA ACTUALLY SHIPS, and check_building_theme refuses
-- any that does not. Twenty-seven words were cut on that rule - coffle, warehouse, bank,
-- mint, spy, thief, foundry, granary and the rest - all of them invented for mod chains
-- nobody had looked at. A token aimed at a chain that might exist somewhere is
-- indistinguishable from a typo, and the cost of being wrong is silent: the building pays
-- the wrong guild forever with nothing on screen to say so. An unmatched chain falls back
-- to the Overseers, which is what every building paid before this table existed, so being
-- sparing here costs nothing.
--
-- THREE TOKENS ARE UNDERSCORED OR LENGTHENED because the bare word matched INSIDE a longer
-- one. `port` is the sharp one: it is buried in `support_artillery` and `ship_gunports`, so
-- it is `_port`, which still catches factory_port, outpost_port and tower_port. `tribute`
-- is buried in `secondary_attributes`, so it is `tribute_hall`. `amber` was buried in
-- `chamber_of_visions` and is gone entirely - there is no amber chain to catch.
--
-- MATCHED AGAINST A LOWERCASED CHAIN. Some of CA's chain keys carry uppercase segments -
-- wh2_main_EMPIRE_academy, and NORSCA, DWARFS, VAMPIRES and GREENSKIN elsewhere - so a
-- case-sensitive match would miss any token that landed on one.
GG.BUILDING_THEME = {
    {"slavers", {"slave", "scavanger", "prison", "dungeon"}},
    {"daemonsmiths", {"forge", "smith", "furnace", "workshop", "engineer", "library",
                      "research", "assembly", "refinery", "drills", "alchem", "magic",
                      "arcane", "observator", "college"}},
    {"khanate", {"watch", "patrol", "assassin"}},
    {"immortals", {"military", "barracks", "infantry", "cavalry", "ranged", "beast",
                   "monster", "garrison", "academy", "walls", "defence", "fortress",
                   "ballistic", "guardhouse", "gate", "drill", "war_machine",
                   "artillery"}},
    {"brass", {"resource", "_port", "harbour", "market", "trade", "caravan",
               "tribute_hall", "treasur", "gold", "iron", "furs", "marble", "obsidian",
               "pottery", "salt", "spices", "wine", "ivory", "gems", "timber", "dyes",
               "animals", "medicine", "pastures"}},
    {"overseers", {"settlement", "growth", "city", "farm", "mine", "quarry", "living",
                   "residence", "overseer", "temple", "altar", "shrine", "camp",
                   "horde", "public", "road"}},
}

-- The guild a chain belongs to, or nil when no word matches. nil is a real answer and the
-- caller decides what to do with it - 39% of vanilla chains match nothing, most of them
-- `special_*` landmarks and race-specific names like `tmb_ushabti` that share no
-- vocabulary with anything.
function GG.guild_of_chain(chain)
    if type(chain) ~= "string" or chain == "" then return nil end
    chain = string.lower(chain)
    local best, best_len = nil, 0
    for rank = 1, #GG.BUILDING_THEME do
        local guild = GG.BUILDING_THEME[rank][1]
        local toks = GG.BUILDING_THEME[rank][2]
        for i = 1, #toks do
            local t = toks[i]
            -- MATCHED AS A PATTERN, WITH NO PLAIN FLAG. string.find's fourth argument
            -- would turn off pattern matching and is BANNED here: one such call corrupts
            -- the string subsystem process-wide for the whole game - CA's own lookups
            -- included - with no error and no recovery short of a restart. So every token
            -- has to be free of Lua pattern magic instead, which check_building_theme in
            -- the generator refuses to let ship otherwise.
            if string.find(chain, t) and #t > best_len then
                best, best_len = guild, #t
            end
        end
    end
    return best
end

-- WHAT A COMPLETED BUILDING PAYS, and to whom.
--
-- THE LEVEL FINALLY COUNTS. This function always took a level and multiplied by it, and
-- the listener always passed a hardcoded 1 - so the parameter was dead, a tier-one hut
-- paid exactly what a tier-five fortress did, and the panel's own earning line promised
-- "more at higher levels" for a build that could not deliver it.
--
-- THE BASE OF building_level() IS NOT DOCUMENTED. CA says only "Level of this building",
-- returning card32, and the DB's own `level` column on building_levels is 0-based - 1,943
-- of 5,259 rows sit at 0. So the number is floored at 1 rather than trusted: if it is
-- 0-based the first two tiers both pay the base rate and everything above scales, and if
-- it is 1-based every tier scales. Higher pays more either way, and nothing pays nothing,
-- which is what the promise on screen actually needs. Ceiling at 10 so a modded building
-- reporting something strange cannot pay a hundred times the rate.
function GG.on_building(faction, level, chain)
    local tier = tonumber(level) or 1
    if tier < 1 then tier = 1 end
    if tier > 10 then tier = 10 end
    -- The Overseers are the default and not merely a fallback: they are the guild of
    -- building things, so a chain whose name says nothing still belongs to them.
    local guild = GG.guild_of_chain(chain) or "overseers"
    GG.capped_grant(faction, guild, (GG.setting("rate_overseers") or 10) * tier,
                    "buildings")
end

function GG.on_settlement(faction, razed)
    -- Settlement events come in tense pairs and only the past-tense one carries
    -- usable data; a razed region answers with nothing at all. The listener
    -- reads the completed event, never the headline one.
    local sack = GG.setting("rate_slavers") or 25
    -- A raze pays the sack rate times 8/5. Written as an integer multiply THEN a
    -- divide, never as " * 1.6": WH3 Lua is float32, 1.6 is not exact in binary,
    -- and floor(25 * 1.6) can land on 39 instead of 40. 25*8=200 and 200/5=40 are
    -- both exactly representable.
    GG.capped_grant(faction, "slavers", razed and math.floor(sack * 8 / 5) or sack,
                    "settlements")
end

function GG.on_mission(faction)
    -- GG.setting falls back to TUNE_DEFAULTS, so the number lives in exactly one
    -- place. 0 is the off switch the MCT slider offers.
    local rate = GG.setting("rate_missions") or 0
    if rate <= 0 then return end
    for i = 1, #GG.GUILDS do
        GG.capped_grant(faction, GG.GUILDS[i], rate, "missions")
    end
end

-- ---------------------------------------------------------------------------
-- THE BOUNTY BOARD.
--
-- A clone of CA's own Ogre contracts - the global in
-- script/campaign/wh3_campaign_ogre_contracts.lua is literally called
-- `ogre_bounties`. CA's shape, read off that file on 2026-09-11: pick a target in
-- Lua, issue it as a real mission with cm:trigger_custom_mission_from_string, and
-- pay with a `money` payload. The reputation half is ours, and it is paid in the
-- MissionSucceeded handler rather than in the payload, because no payload statement
-- can reach a number this mod keeps in a saved value.
--
-- WHAT DIFFERS FROM CA'S, and why:
--   * CA issues contracts unasked, three at a time. Ours are OFFERS: they sit on the
--     board until the player takes one. A bounty you did not agree to is a chore;
--     one you chose is a decision, and the panel exists to make that choice readable.
--   * CA targets the ISSUER's enemies while you are at peace with them. A guild is
--     not a faction and has no enemies of its own, so ours target factions YOU are
--     already at war with. No guild ever asks you to open a new war.
--   * Pay is flat per kind rather than scaled by distance. Distance scaling is CA's
--     way of pricing travel time; it is not worth a second set of numbers to tune.
--
-- The three mirrored tables below MUST match BOUNTY_KINDS / BOUNTIES in
-- tools/gen_great_guilds.py, which owns the DB rows and the loc.
-- tools/import_great_guilds.py refuses to pack if they disagree.

GG.BOUNTY_SLOTS = 3          -- how many offers the board holds at once
GG.BOUNTY_TURN_LIMIT = 20    -- turns the issued mission allows
GG.BOUNTY_OFFER_LIFE = 6     -- turns an UNTAKEN offer stays before it is withdrawn

-- otype is the objective type written into the mission string. It is NOT the DB row's
-- mission_type column, and CA's own contracts prove the two differ: every
-- wh3_main_mission_ogre_contract_defeat_lord_* row says ELIMINATE_CHARACTER_IN_BATTLE
-- while the script issues KILL_CHARACTER_BY_ANY_MEANS. The string is what the game
-- evaluates, so the string is what lives here.
GG.BOUNTY_KINDS = {
    region_take = {otype = "CAPTURE_REGIONS", obj = "region %s",
                   gold = 3000, target = "region"},
    region_sack = {otype = "RAZE_OR_SACK_N_DIFFERENT_SETTLEMENTS_INCLUDING",
                   obj = "region %s;total 1", gold = 2000, target = "region"},
    lord_kill   = {otype = "KILL_CHARACTER_BY_ANY_MEANS", obj = "family_member %s",
                   gold = 1500, target = "lord"},
}

GG.BOUNTIES = {
    brass = "region_take", immortals = "lord_kill", daemonsmiths = "region_sack",
    khanate = "lord_kill", overseers = "region_take", slavers = "region_sack",
}

GG.bounties = GG.bounties or {}   -- [faction] = { offer, ... }, at most BOUNTY_SLOTS

-- One line into the script log. The bounty path is built out of pcall-wrapped model
-- walks, so without this every different failure looks like the same empty board.
function GG.trace(msg)
    pcall(function() out("derpy_gg: " .. tostring(msg)) end)
end

-- Per holder: an Empire faction's bounty is derpy_gg_bounty_brass_emp, which is the row
-- whose title and picture are the Empire's. A nil faction is the untagged key.
function GG.bounty_mission_key(guild, faction)
    return "derpy_gg_bounty_" .. guild .. GG.tag(faction)
end

-- One live mission per key per faction, so one bounty per guild at a time. The board
-- holds three of six guilds, which sits well inside that.
function GG.bounty_for_guild(faction, guild)
    local list = GG.bounties[faction]
    if not list then return nil end
    for i = 1, #list do
        if list[i].guild == guild then return list[i], i end
    end
    return nil
end

-- WHO LEADS A GUILD, or nobody. Lives in the model rather than the panel so the
-- harness can hold it to the two rules that matter: a faction needs reputation above
-- zero to be named at all, and a tie resolves the same way every draw. pairs() order is
-- not stable between runs, so leaving ties to it made the league table flicker.
-- FACTIONS WE HAVE SEEN DIE. Session-only and ONE-WAY: a faction that reads as dead
-- is never asked about again, and a faction that reads as alive is asked every time,
-- because the answer only ever changes in that direction. Empty after a load, which
-- costs one engine call per guild on the first draw and nothing afterwards.
GG.dead = GG.dead or {}

-- is_dead IS on the faction interface - CA's scripting_doc, "Returns true if the
-- faction is dead" - unlike the character interfaces, where no such call exists at all.
-- GG.bounty_target already calls it on the factions it walks.
--
-- AN UNREADABLE ANSWER IS NOT A DEATH. A faction whose interface cannot be reached is
-- already excluded by GG.covered, which caches an unreadable culture as not-covered, so
-- there is nothing to gain here by guessing and a permanent wrong cache to lose.
function GG.faction_dead(faction)
    if not faction then return false end
    if GG.dead[faction] then return true end
    local ok, dead = pcall(function()
        local f = cm:get_faction(faction)
        -- cm:get_faction returns FALSE, not nil, for a key it does not know.
        if not f or f:is_null_interface() then return nil end
        return f:is_dead() == true
    end)
    if not ok or dead ~= true then return false end
    GG.dead[faction] = true
    return true
end

-- WHO LEADS A GUILD, or nobody. Lives in the model rather than the panel so the
-- harness can hold it to the two rules that matter: a faction needs reputation above
-- zero to be named at all, and a tie resolves the same way every draw. pairs() order is
-- not stable between runs, so leaving ties to it made the league table flicker.
--
-- A DEAD FACTION LED ITS GUILD FOREVER. Nothing here asked whether the top faction was
-- still in the campaign, and everything about leading a guild runs through this one
-- function: GG.reassert_leaders hangs the leader's bundle off it and GG.can_buy sells
-- each guild's dearest service to nobody else. So wiping out the faction that led the
-- Brass Tablets - an ordinary thing to do to a faction with high standing, since high
-- standing means an active warring faction - locked that guild's best service away from
-- every living faction including the player, permanently, and left a dead name on the
-- Standings tab. Six services, one per guild, could each be removed from a campaign this
-- way, in silence. Same shape as the bounty whose target lord had died: state that
-- outlives the world it was picked from.
--
-- THE DEAD ARE PEELED OFF THE TOP rather than filtered inside the scan. The scan runs
-- over every faction holding standing and the engine call is the expensive part, so it
-- is made once, on the winner, and only repeated if the winner turns out to be dead -
-- which marks them and cannot happen twice for the same faction.

-- THE WHOLE LEAGUE TABLE for one guild, best first, as {faction=, rep=, pos=} rows.
-- Six names were being computed and five thrown away: the scan below has always run
-- over every faction holding standing, and GG.leader_of kept the maximum and discarded
-- the rest. So the Standings tab could say who held a guild and nothing else - no
-- second place, no sense of whether a rival was forty reputation ahead or four
-- thousand, and no way for a player to see their own position at all. The race had a
-- leaderboard with one row on it.
--
-- FILTERED ON THE GG.dead CACHE, NOT WITH A FRESH is_dead PER ROW. This is a draw-time
-- read and a save carried across builds can hold rows for factions well outside the
-- race, so a real engine call per row would be six guilds times everything in GG.state
-- on every panel refresh. GG.leader_of below does make the real call, on the top row, and caches
-- what it finds - and GGUI.leaders calls it for every guild before drawing, so the one
-- row whose correctness is load-bearing (it carries the bundle and the monopoly) is
-- always verified, and the rows under it self-correct as the cache fills.
--
-- pos IS CARRIED ON THE ROW rather than left to the caller to count, because "you are
-- 4th" and "there are 9" are the two numbers the panel exists to show and an off-by-one
-- in either is exactly the kind of thing that reads as correct.
function GG.standings(guild, culture)
    local rows = {}
    -- THE PRESENT FACTIONS OF THIS CULTURE, as a lookup. GG.present was filtering the
    -- ROSTER, which is only where the zero-reputation padding comes from - a faction
    -- that has actually banked something arrives here through GG.state and skipped the
    -- check entirely. Measured in a dry run: wh3_dlc23_chd_chaos_dwarfs_qb1, a
    -- quest-battle faction with no region and no army, sat at the head of the Brass
    -- Tablets on 5000 reputation and pushed the player to second. A scripted
    -- placeholder held a guild, its bundle, and its monopoly.
    --
    -- ONLY WHEN THE ROSTER CAN BE READ. An empty roster means the world was unreadable,
    -- not that the culture has no factions, and filtering everything out there would
    -- strip every leadership bundle in the campaign. So an unreadable world falls back
    -- to the old behaviour rather than to silence.
    local present, gate = nil, false
    if culture then
        local r = GG.roster(culture)
        if #r > 0 then
            present, gate = {}, true
            for i = 1, #r do present[r[i]] = true end
        end
    end
    for faction, tracks in pairs(GG.state) do
        local t = tracks[guild]
        -- ONE CULTURE'S LEAGUE. Filtered here rather than in the callers so that
        -- GG.leader_of, GG.contenders and the panel all read the same list - three
        -- copies of this rule is how an Empire faction came to lead the Daemonsmiths.
        if culture and GG.CULTURE_OF[faction] ~= culture then t = nil end
        if gate and not present[faction] then t = nil end
        -- GG.covered is checked HERE as well as at the grant, because a save made
        -- before that gate already holds rows for factions this mod does not cover,
        -- and they would otherwise sit at the top of the standings forever.
        if t and t.rep > 0 and not GG.dead[faction] and GG.covered(faction) then
            rows[#rows + 1] = {faction = faction, rep = t.rep}
        end
    end
    -- THE SAME TIE-BREAK GG.leader_of ALWAYS USED, kept here so the table and its top
    -- row can never disagree: reputation first, then the faction key. pairs() order is
    -- not stable between runs, so leaving ties to it made the league table flicker.
    table.sort(rows, function(a, b)
        if a.rep ~= b.rep then return a.rep > b.rep end
        return a.faction < b.faction
    end)
    for i = 1, #rows do rows[i].pos = i end
    return rows
end

-- WHO LEADS A GUILD, or nobody. Lives in the model rather than the panel so the
-- harness can hold it to the two rules that matter: a faction needs reputation above
-- zero to be named at all, and a tie resolves the same way every draw.
-- PER CULTURE. This used to answer world-wide, and in a Chaos Dwarf campaign it put
-- The Golden Order at the head of the Daemonsmiths and Clan Angrund at the head of the
-- Khanate - an Empire province and a Dwarf hold running Chaos Dwarf institutions. One
-- screenshot was enough to show it.
--
-- TWO SEPARATE RULES KEEP IT FIXED and both are load-bearing. The race is the player's
-- culture, so in a single-player campaign nobody else is in GG.standings at all - and
-- leadership is still asked per culture on top of that, because a save written under the
-- build that let everyone race still has their rows in it, and because a head-to-head
-- multiplayer campaign genuinely has two races running at once.
--
-- A nil or uncovered culture leads nothing. That is deliberate: every caller knows whose
-- guild it is asking about, and guessing a default here is how a faction ends up holding
-- a seat in a race it is not running in.
function GG.leader_of(guild, culture)
    -- A NAMED CULTURE, not a known one. Requiring it to be in the scanned set would put
    -- every leadership bundle behind one engine walk succeeding.
    if type(culture) ~= "string" or culture == "" then return nil, 0 end
    local rows = GG.standings(guild, culture)
    local top, top_rep = nil, 0
    for i = 1, #rows do
        -- THE REAL ENGINE CALL, top down, stopping at the first faction still in the
        -- campaign. Every dead faction it walks past is cached by GG.faction_dead, so
        -- the next GG.standings call has already dropped it and this loop cannot walk
        -- the same corpse twice.
        if not GG.faction_dead(rows[i].faction) then
            top, top_rep = rows[i].faction, rows[i].rep
            break
        end
    end
    if not top then return nil, 0 end
    return GG.hold_lead(guild, culture, rows, top, top_rep)
end

-- A LEAD SMALLER THAN ONE TURN'S UPKEEP IS NOT A LEAD.
--
-- WHY THIS EXISTS. Every faction is charged its upkeep at its OWN turn start and
-- GG.reassert_leaders runs at every faction's turn start after it, so for most of a
-- round the world is HALF-CHARGED: whoever has already paid sits temporarily below
-- whoever has not. A gap smaller than one upkeep tick therefore inverts twice every
-- round - once when the leader pays, once when the challenger does - with neither
-- faction having earned anything. Measured in a live campaign at turns 9-13: the Brass
-- Tablets left the player and came back seven times in one sitting, each move taking a
-- permanent effect bundle off one faction and putting it on another, revoking a
-- service monopoly, and firing a feed popup.
--
-- IN GG.leader_of AND NOT IN GG.reassert_leaders, which is the only other place that
-- could hold it. The sweep owns the bundle and the message, but the panel's "Led by"
-- line, the Standings crown and GG.can_buy's monopoly gate all read GG.leader_of
-- directly - so a rule applied at the sweep would put the bundle on one faction while
-- three other readers named a different one.
--
-- THE MARGIN IS THE UPKEEP ITSELF, not a new tunable: it is exactly the quantity that
-- causes the inversion, it scales with the rank and with rate_decay for free, and it
-- needs no MCT option, no loc and no DB row. The larger of the two ranks is used
-- because a challenger one point below a rank threshold pays the smaller tick, and it
-- is the BIGGER of the two that sets how far the half-charged world can swing.
--
-- Ties are already resolved by GG.standings' faction-key order, so a challenger that
-- merely draws level never takes it either.
function GG.hold_lead(guild, culture, rows, top, top_rep)
    local held = GG.leaders_now[GG.lead_slot(guild, culture)]
    -- Nobody held it, or the holder IS the top row: nothing to hold against. `false`
    -- is what GG.reassert_leaders stores for "nobody leads this", so it is not a key.
    if not held or held == top then return top, top_rep end
    for i = 1, #rows do
        if rows[i].faction == held then
            -- The holder is still standing. It keeps the guild unless the top row is
            -- ahead by more than one turn's upkeep. A holder that has fallen out of
            -- the rows entirely - dead, drained to zero, out of this culture - never
            -- reaches here and the top row takes it, which is correct.
            if GG.faction_dead(held) then return top, top_rep end
            local margin = math.max(GG.decay_amount(GG.rank_of(top_rep)),
                                    GG.decay_amount(GG.rank_of(rows[i].rep)))
            if top_rep - rows[i].rep <= margin then return held, rows[i].rep end
            return top, top_rep
        end
    end
    return top, top_rep
end

-- EVERY FACTION THIS MOD COVERS THAT IS IN THIS CAMPAIGN, by key, sorted.
--
-- THE STANDINGS TAB WAS EMPTY FOR THE FIRST STRETCH OF EVERY CAMPAIGN and it read as a
-- broken panel. GG.state is not a roster: GG.load returns early for a faction with no
-- saved value, so a faction appears in it only once it has already EARNED something.
-- At turn two that is the player and nobody else, so the tab said "1/1" and "Nobody
-- yet" six times - which is exactly when a player opens it to find out what the mod
-- does. The thirteen rival Chaos Dwarf factions were real, covered and playing; they
-- simply had not banked anything yet, and nothing on screen said they existed.
--
-- CACHED FOR THE SESSION. A faction's culture does not change and the campaign's faction
-- list does not grow, so this walk happens once and every later draw reads the table.
-- Death is handled by the GG.dead filter at the point of use rather than by rebuilding,
-- so a faction wiped out mid-campaign leaves the list without this being redone.
--
-- THE CULTURE IS READ OFF THE INTERFACE THE WALK ALREADY HAS, and cached into
-- GG.CULTURE_OF, which saves GG.covered a cm:get_faction call per faction afterwards.
-- ONE FACTION PER pcall: a single faction whose interface misbehaves must cost its own
-- row and not the whole roster, which is the difference between a short list and a
-- panel that silently goes back to being empty.
GG.roster_cache = nil

-- [faction key] = the folder its crest lives in, e.g. "ui/flags/wh3_dlc23_chd_astragoth".
-- Filled by the scan from faction:flag_path(); the panel appends the size it wants.
GG.FLAG_OF = GG.FLAG_OF or {}

-- IS THIS FACTION ACTUALLY IN THE CAMPAIGN? Eleven factions carry the Chaos Dwarf culture
-- in vanilla and five of them are not rivals in any sense a player would recognise:
-- _qb1, _qb2 and _qb3 exist to fight one scripted quest battle each, _rebels is the
-- rebellion pool, and wh3_dlc25_chd_chaos_dwarfs_invasion does not exist until its event
-- fires. They sit in faction_list from turn one regardless.
--
-- A FACTION IS PRESENT IF IT HOLDS SOMETHING. has_home_region covers everyone who owns
-- territory and the military force check covers a horde that owns none - both are on
-- FACTION_SCRIPT_INTERFACE. Unreadable answers count as NOT present, because the panel
-- listing too few real rivals is a smaller wrong than it listing scripted placeholders.
function GG.present(f)
    if not f then return false end
    local ok, present = pcall(function()
        if f:has_home_region() then return true end
        -- A horde owns no region. military_force_list counts garrisons too, which is
        -- fine here: a faction with a garrison is a faction that is in the campaign.
        local mf = f:military_force_list()
        return mf and mf:num_items() > 0
    end)
    return ok and present == true
end

-- ONE WALK OF THE CAMPAIGN, filling everything that depends on it: which cultures exist,
-- who is present in each, what culture each faction is, and where its crest lives.
--
-- ONE WALK, NOT ONE PER CULTURE. The previous shape took a culture and walked the whole
-- faction list looking for it, so six guilds across a modded install's dozen cultures
-- meant a dozen walks of ~190 factions. The list is the same list every time; walking it
-- once and bucketing is the same information for a twelfth of the work.
--
-- CACHED FOR THE SESSION. A faction's culture does not change and the campaign's faction
-- list does not grow. Death is handled by the GG.dead filter at the point of use rather
-- than by rebuilding, so a faction wiped out mid-campaign leaves without this being redone.
function GG.scan_world()
    if GG.roster_cache then return GG.roster_cache end
    local buckets, seen = {}, false
    local ok = pcall(function()
        local fl = cm:model():world():faction_list()
        for i = 0, fl:num_items() - 1 do
            -- ONE pcall PER FACTION: the walk crosses every faction in the campaign,
            -- most of them nothing to do with any one culture, and a single interface
            -- that throws must cost its own row rather than the whole scan.
            pcall(function()
                local f = fl:item_at(i)
                if not f or f:is_null_interface() then return end
                local name, c = f:name(), f:culture()
                if type(name) ~= "string" or name == "" then return end
                if type(c) ~= "string" or c == "" then return end
                GG.CULTURE_OF[name] = c
                -- THE CULTURE COUNTS EVEN IF THIS FACTION IS A PLACEHOLDER. A culture
                -- whose only present faction dies still exists; what changes is who is
                -- in its roster, and GG.dead already handles that.
                GG.CULTURES[c] = true
                if not GG.present(f) then return end
                local fp
                local okf, got = pcall(function() return f:flag_path() end)
                if okf then fp = got end
                if type(fp) == "string" and fp ~= "" then GG.FLAG_OF[name] = fp end
                buckets[c] = buckets[c] or {}
                table.insert(buckets[c], name)
                seen = true
            end)
        end
    end)
    -- NOT CACHED ON FAILURE, and not cached empty. The world is unreadable before the
    -- campaign is built and the interfaces can be briefly unready inside it, and caching
    -- nothing there would leave every table empty for the rest of the session.
    if not ok or not seen then return {} end
    for _, list in pairs(buckets) do table.sort(list) end
    GG.roster_cache = buckets
    return buckets
end

-- WHOSE RACE THIS IS. The player's culture, and nobody else's.
--
-- THE SCOPE IS THE PLAYER, AND THE LOOKUP IS DYNAMIC. Those are two different things and
-- conflating them is what produced the two wrong builds before this one. A hardcoded list
-- of three culture keys was wrong because it could not see a culture any mod added - Old
-- World, Immortal Empires Expanded, the Hobgoblin Khanates and the rest were all silently
-- inert. Opening it to EVERY culture in the campaign was wrong in the other direction: it
-- is six guilds of Chaos Dwarf flavour, and a campaign does not want the Empire and the
-- Lizardmen quietly running their own copies of them.
--
-- So the culture is READ OFF THE PLAYER rather than listed here. A Chaos Dwarf campaign
-- races Chaos Dwarfs, a Dwarf campaign races Dwarfs, and a campaign whose player belongs
-- to a culture some mod invented races that - without this file ever naming it.
--
-- EVERY HUMAN, not just the first: a multiplayer campaign can have two players of
-- different cultures, and each is entitled to their own league.
GG.player_cultures_cache = nil

function GG.player_cultures()
    if GG.player_cultures_cache then return GG.player_cultures_cache end
    local out, any = {}, false
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if ok and humans then
        for i = 1, #humans do
            -- Read straight off the faction rather than through GG.covered, which asks
            -- this function and would recurse.
            local c = GG.CULTURE_OF[humans[i]]
            if c == nil then
                local okc, got = pcall(function()
                    local f = cm:get_faction(humans[i])
                    -- cm:get_faction returns FALSE, not nil, for a key it does not know.
                    if not f or f:is_null_interface() then return nil end
                    return f:culture()
                end)
                if okc and type(got) == "string" and got ~= "" then
                    c = got
                    GG.CULTURE_OF[humans[i]] = c
                end
            end
            if type(c) == "string" and c ~= "" then out[c], any = true, true end
        end
    end
    -- NOT CACHED UNTIL IT ANSWERS. The local faction is not readable during loading, and
    -- caching an empty set there would leave the mod inert for the whole session.
    if not any then return {} end
    GG.player_cultures_cache = out
    return out
end

-- EVERY CULTURE WITH A RACE RUNNING. The player's, plus any culture already holding
-- standing in the save - the second half matters because a save made under a build with
-- a different scope still has rows in it, and the leadership sweep has to be able to
-- take those bundles back off rather than leaving them on a faction nobody can see.
function GG.cultures_in_play()
    local out = {}
    for c, _ in pairs(GG.player_cultures()) do out[c] = true end
    for f, _ in pairs(GG.state) do
        local c = GG.CULTURE_OF[f]
        if type(c) == "string" and c ~= "" then out[c] = true end
    end
    return out
end

-- THE PRESENT FACTIONS OF ONE CULTURE, sorted by key.
function GG.roster(culture)
    if not culture or culture == "" then return {} end
    return GG.scan_world()[culture] or {}
end

-- THE CULTURE A FACTION RACES IN. Its own, when this mod covers it; nothing otherwise.
function GG.culture_of(faction)
    if not faction then return nil end
    if not GG.covered(faction) then return nil end
    return GG.CULTURE_OF[faction] or nil
end

-- WHO IS IN THE RACE, which is not the same question as who is winning it. The earners
-- first, in order, then every other covered faction still in the campaign at zero.
--
-- KEPT SEPARATE FROM GG.standings ON PURPOSE. Leadership reads GG.standings and must
-- keep its `rep > 0` rule - a faction with no reputation at all cannot hold a guild, or
-- every guild would be led from turn one by whichever key sorts first. This list is for
-- the panel, where a rival at zero is information and an absent rival is a bug report.
function GG.contenders(guild, culture)
    local rows = {}
    -- THE EARNERS OF THIS CULTURE, in order. GG.standings does the culture filtering
    -- and the presence filtering; this adds the rivals who have not earned yet.
    local all = GG.standings(guild, culture)
    for i = 1, #all do
        rows[#rows + 1] = {faction = all[i].faction, rep = all[i].rep, pos = #rows + 1}
    end
    local seen = {}
    for i = 1, #rows do seen[rows[i].faction] = true end
    local roster = GG.roster(culture)
    for i = 1, #roster do
        local f = roster[i]
        if not seen[f] and not GG.dead[f] then
            rows[#rows + 1] = {faction = f, rep = 0, pos = #rows + 1}
        end
    end
    return rows
end

-- WHERE ONE FACTION SITS, and how many are in the race at all. Counted over the
-- CONTENDERS and not the earners: "1/1" on turn two was true and told the player
-- nothing, where "1/14" says both that they lead and that thirteen rivals are coming.
-- nil means the faction is not covered by this mod at all, which is the only case where
-- there is no position to print.
function GG.position_of(faction, guild)
    local rows = GG.contenders(guild, GG.culture_of(faction))
    for i = 1, #rows do
        if rows[i].faction == faction then return i, #rows end
    end
    return nil, #rows
end

-- ---------------------------------------------------------------------------
-- LEADING A GUILD.
--
-- GG.leader_of has always picked the top faction per guild and the Standings tab has
-- always printed it. Nothing paid for it, so the league table was a scoreboard for a
-- race with no finish line. One bundle per guild now hangs off it, and each guild's
-- dearest service is sold to nobody else - which is what turns a number on a tab into
-- something a rival can take from you.

-- WHO WE BELIEVE HOLDS EACH GUILD, this session only. Not saved, for the same reason
-- GG.asserted is not: a belief restored from a save is a belief that heals nothing.
-- Empty at load means the first turn start re-asserts every guild once and then the
-- comparison below goes quiet.
GG.leaders_now = {}

-- One bundle per guild PER CULTURE: an Empire foremost holds derpy_gg_lead_brass_emp.
-- The sweep in reassert_leaders is already scoped to one culture, so it passes it here.
function GG.lead_key(guild, culture)
    local f = GG.flavour_of_culture(culture)
    return "derpy_gg_lead_" .. guild .. (f and f.tag or "")
end

-- ONE FOREMOST PER GUILD PER CULTURE, so GG.leaders_now is keyed by both. The bundle
-- record is still one per guild and needs no new DB rows - three factions of three
-- cultures can each hold derpy_gg_lead_brass at once, because they are the foremost of
-- three separate institutions that happen to share a name in the table.
function GG.lead_slot(guild, culture)
    return tostring(culture) .. "/" .. tostring(guild)
end

function GG.reassert_leaders()
    for culture, _ in pairs(GG.cultures_in_play()) do
    for i = 1, #GG.GUILDS do
        local guild = GG.GUILDS[i]
        local slot = GG.lead_slot(guild, culture)
        -- `or false`, because nil and false must compare equal here or a guild nobody
        -- leads re-runs this whole block every turn forever.
        local who = GG.leader_of(guild, culture) or false
        if GG.leaders_now[slot] ~= who then
            local was = GG.leaders_now[slot]
            local key = GG.lead_key(guild, culture)
            -- SWEPT ACROSS EVERY FACTION OF THIS CULTURE, not just the one we believed
            -- held it. After a load we believe nothing, and the bundle from the previous
            -- session is still sitting on whoever had it then. Scoped to the culture
            -- because there is ONE derpy_gg_lead_brass row in the DB and a head-to-head
            -- multiplayer campaign has two races that can each have a foremost - an
            -- unscoped sweep strips one player's bundle the moment the other is crowned,
            -- and back again next turn, for the rest of the campaign.
            local stale = GG.lead_key(guild)
            for faction, _ in pairs(GG.state) do
                if faction ~= who and GG.CULTURE_OF[faction] == culture then
                    cm:remove_effect_bundle(key, faction)
                end
                -- The untagged lead a flavoured culture wore under the all-races build
                -- is wrong on EVERY faction of it, the foremost included.
                if stale ~= key and GG.CULTURE_OF[faction] == culture then
                    cm:remove_effect_bundle(stale, faction)
                end
            end
            if who then cm:apply_effect_bundle(key, who, -1) end
            GG.leaders_now[slot] = who
            -- AND SAY SO, if the player is one of the two parties. Losing a guild
            -- costs a permanent bundle and the monopoly on that guild's dearest
            -- service, and until now the only way to find out was to open the panel
            -- and notice that a name had changed.
            --
            -- `was ~= nil` skips the FIRST assertion of the session. GG.leaders_now is
            -- empty after a load, so the next sweep re-asserts all six guilds - a
            -- guild nobody leads is stored as `false`, never nil, so nil here means
            -- "we have not looked yet this session", not "nobody held it".
            if was ~= nil then GG.announce_lead(guild, who, was) end
        end
    end
    end
end

-- ---------------------------------------------------------------------------
-- THE WORLD RECORD - what the rivals did, so that the panel can show it.
--
-- The AI has had the player's whole toolkit since the Court shipped: it accrues, buys
-- services, answers demands, appoints patrons and takes guilds off you. All of it
-- happened in complete silence. The only trace was a name on the Standings tab that
-- was sometimes different from the last time you looked, with nothing to say it had
-- changed, when, or by how much - so a mod built around a contested race looked, from
-- the inside, like a solitaire game against six static numbers.
--
-- One record, written once a round by GGAI.run_turn and read by the panel. Counts are
-- for the round just past, not since the campaign began: "3 services bought" is a
-- world that is moving, "417 services bought" is a number.
GG.world = GG.world or {turn = 0, bought = 0, demands = 0, patrons = 0,
                        rep = {}, gain = {}, held = {}, moved = {}}

-- One saved value for the whole world, not one per faction: this is a global fact and
-- there is no faction it belongs to. `turn|bought|demands|patrons` then ";" then one
-- `rep,gain,held,moved` group per guild in GG.GUILDS order, joined by "|". Faction keys
-- carry no "|", "," or ";", which is what makes the flat packing safe.
function GG.save_world()
    -- ONE ENTRY PER CULTURE PER GUILD, each carrying its own slot key, so the order of
    -- pairs() over GG.CULTURES cannot shuffle the record between saves. An older save
    -- holds the guild-only keys; they simply do not match any slot and the next turn
    -- start overwrites the lot, which is what this record is for.
    local per = {}
    for culture, _ in pairs(GG.cultures_in_play()) do
        for i = 1, #GG.GUILDS do
            local g = GG.lead_slot(GG.GUILDS[i], culture)
            per[#per + 1] = table.concat({g, GG.world.rep[g] or 0,
                                          GG.world.gain[g] or 0,
                                          GG.world.held[g] or "",
                                          GG.world.moved[g] and 1 or 0}, ",")
        end
    end
    cm:set_saved_value("derpy_gg_world",
                       table.concat({GG.world.turn, GG.world.bought, GG.world.demands,
                                     GG.world.patrons}, "|")
                       .. ";" .. table.concat(per, "|"))
end

function GG.load_world()
    local ok, raw = pcall(function() return cm:get_saved_value("derpy_gg_world") end)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local head, body = string.match(raw, "^([^;]*);(.*)$")
    if not head then return end
    local h = {}
    for field in string.gmatch(head .. "|", "([^|]*)|") do
        h[#h + 1] = tonumber(field) or 0
    end
    GG.world.turn, GG.world.bought = h[1] or 0, h[2] or 0
    GG.world.demands, GG.world.patrons = h[3] or 0, h[4] or 0
    for chunk in string.gmatch(body .. "|", "([^|]*)|") do
        if chunk ~= "" then
            local f = {}
            for field in string.gmatch(chunk .. ",", "([^,]*),") do f[#f + 1] = field end
            -- THE SLOT KEY IS IN THE RECORD, not inferred from position. The old format
            -- carried four fields and took the guild from the index, which cannot survive
            -- a record that is now cultures x guilds in pairs() order.
            local g = f[1]
            if g and g ~= "" and #f >= 5 then
                GG.world.rep[g] = tonumber(f[2]) or 0
                GG.world.gain[g] = tonumber(f[3]) or 0
                GG.world.held[g] = f[4] or ""
                GG.world.moved[g] = (f[5] == "1")
            end
        end
    end
end

function GG.snapshot_world(turn, bought, demands, patrons)
    -- THE FIRST SNAPSHOT CLAIMS NO MOVEMENT. Against an empty record every guild's
    -- leader has "gained" their entire reputation and every guild has "changed hands"
    -- from nobody, so a fresh campaign's first round would light all six rows up with
    -- movement that did not happen.
    local first = (GG.world.turn == 0)
    -- KEYED BY CULTURE AND GUILD, the same slot GG.leaders_now uses. The panel's yellow
    -- "changed hands" mark and its "+N this round" both read the leader, and a leader is
    -- now a per-culture thing - so a record keyed by guild alone would mark a Chaos Dwarf
    -- row from an Empire faction's movement.
    for culture, _ in pairs(GG.cultures_in_play()) do
        for i = 1, #GG.GUILDS do
            local g = GG.lead_slot(GG.GUILDS[i], culture)
            local who, rep = GG.leader_of(GG.GUILDS[i], culture)
            who, rep = who or "", rep or 0
            GG.world.gain[g] = (not first) and (rep - (GG.world.rep[g] or 0)) or 0
            GG.world.moved[g] = (not first) and ((GG.world.held[g] or "") ~= who) or false
            GG.world.rep[g], GG.world.held[g] = rep, who
        end
    end
    GG.world.turn, GG.world.bought = turn, bought
    GG.world.demands, GG.world.patrons = demands, patrons
    GG.save_world()
end

-- ---------------------------------------------------------------------------
-- THE PATRON. One lord, one guild.
--
-- The bundle lands on an ARMY - cm:apply_effect_bundle_to_force - which is why there
-- is one bundle rather than six: the decision is which guild gets the reputation and
-- the discount, not which force buff a tooltip shows.
GG.patrons = GG.patrons or {}        -- [faction] = {guild = key, cqi = character cqi}
GG.PATRON_BUNDLE = "derpy_gg_patron"
GG.FAVOUR_PATRON = 10                -- % off that guild's services, mirrored in the gen

-- WHICH FORCE WE PUT IT ON, this session only. The saved half is the CHARACTER, because
-- a lord's military force cqi is not a stable identity - it changes when they are given
-- a new army - and the character is what the player appointed.
GG.patron_forces = {}

function GG.is_guild(key)
    for i = 1, #GG.GUILDS do
        if GG.GUILDS[i] == key then return true end
    end
    return false
end

-- A character cqi to their army's cqi, or nil. A lord with no army cannot carry this.
function GG.force_cqi_of(char_cqi)
    if not char_cqi then return nil end
    local ok, cqi = pcall(function()
        local c = cm:get_character_by_cqi(char_cqi)
        if not c or c:is_null_interface() then return nil end
        local mf = c:military_force()
        if not mf or mf:is_null_interface() then return nil end
        return mf:command_queue_index()
    end)
    if ok and type(cqi) == "number" then return cqi end
    return nil
end

function GG.set_patron(faction, guild, char_cqi)
    if not GG.is_guild(guild) then return false, "guild" end
    local force = GG.force_cqi_of(char_cqi)
    -- Refused, not applied blind. A patron with no army would hold the post, take the
    -- discount and show a bundle nothing carries.
    if not force then return false, "army" end
    GG.clear_patron(faction)
    GG.patrons[faction] = {guild = guild, cqi = char_cqi}
    GG.patron_forces[faction] = force
    cm:apply_effect_bundle_to_force(GG.PATRON_BUNDLE, force, -1)
    return true, nil
end

function GG.clear_patron(faction)
    local force = GG.patron_forces[faction]
    if force then
        cm:remove_effect_bundle_from_force(GG.PATRON_BUNDLE, force)
        GG.patron_forces[faction] = nil
    end
    GG.patrons[faction] = nil
end

-- Re-reads the post from the character every turn, because everything about it can
-- change without this mod hearing: the lord dies, loses their army, or is given a new
-- one. A post whose lord is gone is vacated rather than left pointing at nothing.
function GG.assert_patron(faction)
    local p = GG.patrons[faction]
    if not p then return end
    local force = GG.force_cqi_of(p.cqi)
    if not force then
        GG.patrons[faction] = nil
        GG.patron_forces[faction] = nil
        return
    end
    if GG.patron_forces[faction] ~= force then
        if GG.patron_forces[faction] then
            cm:remove_effect_bundle_from_force(GG.PATRON_BUNDLE,
                                               GG.patron_forces[faction])
        end
        cm:apply_effect_bundle_to_force(GG.PATRON_BUNDLE, force, -1)
        GG.patron_forces[faction] = force
    end
end

-- ------------------------------------------------------- what is being researched ---
--
-- BOUND BLUEPRINT NEEDED A TECHNOLOGY KEY AND THERE WAS NO WAY TO READ ONE. Nothing on
-- FACTION_SCRIPT_INTERFACE returns the technology a faction is currently researching:
-- it has is_currently_researching, research_queue_idle, has_technology,
-- has_available_technologies and num_completed_technologies, and not one of them names
-- the subject. So the service refused rather than charging for nothing, which was
-- honest and still left one of eighteen services unusable.
--
-- THE EVENT CARRIES THE KEY. ResearchStarted's context has faction() and technology(),
-- and CA's scripting_doc describes the second as "Access the technology key in the
-- event" with interface NONE - a plain string, not an interface. So the subject is
-- recorded when research begins and cleared when it completes, and the service reads
-- what the faction is actually working on. No picker UI, and no baked copy of the
-- technology tree.
--
-- SAVED, because a belief held only in a session is one a player loses by saving mid
-- research and coming back - which is most of how anyone plays. Same mechanism as
-- GG.save_patron and GG.save_demand.
--
-- THE ONE GAP, stated rather than hidden: research that began before this listener ever
-- ran has no record, so a campaign that adds the mod mid-flight sees the service refuse
-- until the next technology is queued. Guessing would be worse - a wrong technology key
-- fails silently and forever, and the player would have paid for it.
GG.researching = GG.researching or {}

function GG.save_research(faction)
    cm:set_saved_value("derpy_gg_research_" .. faction,
                       GG.researching[faction] or "")
end

function GG.load_research(faction)
    local k = cm:get_saved_value("derpy_gg_research_" .. faction)
    GG.researching[faction] = (type(k) == "string" and k ~= "") and k or nil
end

function GG.set_research(faction, tech)
    if not faction then return false end
    -- A NON-STRING IS NOT A TECHNOLOGY. context:technology() is documented as a key and
    -- an interface would stringify to something that fails silently at the payload.
    if type(tech) ~= "string" or tech == "" then return false end
    GG.researching[faction] = tech
    return true
end

function GG.clear_research(faction)
    if not faction then return end
    GG.researching[faction] = nil
end

-- THE TARGET Bound Blueprint buys. nil is a refusal the card shows in words, not a
-- reason to fire the payload blind.
function GG.research_target(faction)
    if not faction then return nil end
    local k = GG.researching[faction]
    if type(k) ~= "string" or k == "" then return nil end
    -- ALREADY HELD IS NOTHING TO BUY. ResearchCompleted never reaches an AI faction, so
    -- an AI's record outlives the research it names; the faction itself says whether it
    -- is done. An unreadable answer keeps the record, which is the player's case: their
    -- record is cleared by ResearchCompleted and never needs this.
    local ok, has = pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then return false end
        return f:has_technology(k)
    end)
    if ok and has == true then return nil end
    return k
end

-- THE FIRST LEGAL UPGRADE IN ONE OF THE FACTION'S OWN REGIONS, as the {slot, building}
-- pair the payload wants, from nothing but a region key. The panel passes the selected
-- settlement, the AI walks its own regions, and a multiplayer purchase sends the key and
-- rebuilds this on every machine - a slot interface cannot travel in an event string.
--
-- cm:region_slot_instantly_upgrade_building needs a slot interface AND a building key
-- that is a legal upgrade for the chain standing in that slot, and the legality lives in
-- building_upgrades_junction, which no script interface exposes. It does not need a copy
-- of that table: cm:get_building_level_upgrades(key) returns "a lua table containing a
-- list of building keys that are upgrades from a supplied building key", empty when
-- there are none. CA's own prologue achievement script walks settlements with exactly
-- this call - region:settlement():primary_slot():building():name().
--
-- THE PRIMARY SLOT IS TRIED FIRST, because the settlement chain is what raising a
-- ziggurat means and it is the tier gate every other slot in the region is capped by.
-- The rest of the settlement's slots are the fallback, so a region already at its
-- maximum tier still has something to sell.
--
-- ponytail: no construction-in-progress test. No slot or region member in CA's docs
-- says a building is being built, so a slot mid-construction can still be picked.
function GG.upgrade_target(faction, key)
    if not faction or type(key) ~= "string" or key == "" then return nil end
    local ok, out = pcall(function()
        -- cm:get_region returns FALSE, not nil, for a region key it does not know.
        local r = cm:get_region(key)
        if not r or r:is_null_interface() then return nil end
        -- YOUR OWN REGION ONLY. Upgrading a building for the faction that owns it is a
        -- gift to whoever holds the settlement, and the map's selection happily lands
        -- on someone else's city.
        if r:owning_faction():name() ~= faction then return nil end
        local st = r:settlement()
        if not st or st:is_null_interface() then return nil end
        local ordered = {st:primary_slot()}
        local slots = st:slot_list()
        for i = 0, slots:num_items() - 1 do
            ordered[#ordered + 1] = slots:item_at(i)
        end
        for i = 1, #ordered do
            local sl = ordered[i]
            if sl and not sl:is_null_interface() and sl:has_building() then
                local b = sl:building()
                if b and not b:is_null_interface() then
                    local ups = cm:get_building_level_upgrades(b:name())
                    -- AN EMPTY TABLE IS THE DOCUMENTED "no upgrades" ANSWER, and a key
                    -- that names no building returns nothing at all - so the type is
                    -- checked before the index.
                    if type(ups) == "table" and type(ups[1]) == "string" then
                        return {slot = sl, building = ups[1]}
                    end
                end
            end
        end
        return nil
    end)
    if ok then return out end
    return nil
end

function GG.save_patron(faction)
    local p = GG.patrons[faction]
    cm:set_saved_value("derpy_gg_patron_" .. faction,
                       p and (p.guild .. "," .. p.cqi) or "")
end

function GG.load_patron(faction)
    local packed = cm:get_saved_value("derpy_gg_patron_" .. faction)
    if not packed or packed == "" then
        GG.patrons[faction] = nil
        return
    end
    local guild, cqi = string.match(packed, "^([^,]*),(%-?%d+)$")
    if guild and cqi and GG.is_guild(guild) then
        GG.patrons[faction] = {guild = guild, cqi = tonumber(cqi)}
    else
        GG.patrons[faction] = nil
    end
end

-- ---------------------------------------------------------------------------
-- DEMANDS.
--
-- Reputation was a ratchet: every route added to it and only rivalry ever took any
-- away, so a guild courted once stayed courted for the rest of the campaign. A demand
-- is the guild asking for something back, with a deadline on it.
--
-- Two kinds, neither of them a new subsystem. A TRIBUTE is gold, which the engine
-- already tracks. A RENUNCIATION is favour held with the guild's rival, which this mod
-- already holds - and it makes the rivalry bite a second way, because the thing you are
-- asked to burn is the thing you spent the campaign building.
GG.demands = GG.demands or {}        -- [faction] = {guild, kind, amount, due}
GG.demand_last = GG.demand_last or {}  -- [faction] = turn the last demand was issued

GG.DEMAND_TRIBUTE_BASE = 1500
GG.DEMAND_TRIBUTE_PER_RANK = 750
GG.DEMAND_FAVOUR_BASE = 40
GG.DEMAND_FAVOUR_PER_RANK = 20

-- Scaled by the rank you hold with the guild asking. A guild that barely knows you asks
-- for little; one you are Exalted with asks for what an Exalted member can afford.
function GG.demand_amount(kind, rank)
    if kind == "tribute" then
        return GG.DEMAND_TRIBUTE_BASE + rank * GG.DEMAND_TRIBUTE_PER_RANK
    end
    return GG.DEMAND_FAVOUR_BASE + rank * GG.DEMAND_FAVOUR_PER_RANK
end

-- Only a guild that already knows you asks for anything: a demand from a guild at zero
-- reputation is a penalty for a relationship you never had.
function GG.roll_demand(faction, turn)
    if GG.demands[faction] then return nil end
    local pool = {}
    for i = 1, #GG.GUILDS do
        local g = GG.GUILDS[i]
        if (GG.get(faction, g)) > 0 then pool[#pool + 1] = g end
    end
    if #pool == 0 then return nil end
    local guild = pool[GG.roll(#pool)]
    local rival = GG.RIVALS[guild]
    local kind = "tribute"
    -- A renunciation needs something to renounce. Without favour held with the rival it
    -- would be a demand that is already satisfied, which reads as a bug.
    if rival and select(2, GG.get(faction, rival)) > 0 and GG.roll(2) == 2 then
        kind = "renounce"
    end
    local rank = GG.rank_of((GG.get(faction, guild)))
    GG.demands[faction] = {guild = guild, kind = kind,
                           amount = GG.demand_amount(kind, rank),
                           due = turn + (GG.setting("demand_turns") or 8)}
    return GG.demands[faction]
end

-- Returns "new" or "expired" and the demand, or nothing. One call per turn per human
-- faction; the panel reads the result, the feed announces it.
function GG.demand_tick(faction, turn)
    local d = GG.demands[faction]
    if d then
        if turn > d.due then
            GG.penalise(faction, d.guild, GG.setting("demand_penalty") or 0)
            GG.demands[faction] = nil
            return "expired", d
        end
        return nil
    end
    local every = GG.setting("demand_every") or 0
    if every <= 0 then return nil end
    if turn - (GG.demand_last[faction] or 0) < every then return nil end
    local new = GG.roll_demand(faction, turn)
    if not new then return nil end
    -- Stamped only when one was actually issued. A turn where no guild knew the player
    -- well enough to ask must not start the clock again.
    GG.demand_last[faction] = turn
    return "new", new
end

-- Returns a REASON KEY, never a sentence - the same rule as GG.can_buy, and for the
-- same reason: a loc call from a turn handler is a CTD at turn 1.
function GG.demand_payable(faction)
    local d = GG.demands[faction]
    if not d then return false, "none" end
    if d.kind == "tribute" then
        local ok, gold = pcall(function()
            local f = cm:get_faction(faction)
            if not f or f:is_null_interface() then return nil end
            return f:treasury()
        end)
        if not ok or type(gold) ~= "number" or gold < d.amount then
            return false, "gold"
        end
        return true, nil
    end
    local rival = GG.RIVALS[d.guild]
    if not rival then return false, "none" end
    if select(2, GG.get(faction, rival)) < d.amount then return false, "favour" end
    return true, nil
end

function GG.pay_demand(faction)
    local d = GG.demands[faction]
    if not d then return false, "none" end
    local ok, why = GG.demand_payable(faction)
    if not ok then return false, why end
    if d.kind == "tribute" then
        cm:treasury_mod(faction, -d.amount)
    else
        GG.spend(faction, GG.RIVALS[d.guild], d.amount)
    end
    -- Through GG.grant, so the reward climbs ranks and drains the rival exactly as any
    -- other earning does. A paid demand is a large, chosen, one-off earn.
    GG.grant(faction, d.guild, GG.setting("demand_reward") or 0, "demands")
    GG.demands[faction] = nil
    return true, nil
end

-- ITS OWN SAVED VALUE, like the bounties. The issue turn rides in front of the demand
-- itself and survives its resolution, because it is what paces the next one.
function GG.save_demand(faction)
    local d = GG.demands[faction]
    local body = ""
    if d then
        body = table.concat({d.guild, d.kind, d.amount, d.due}, ",")
    end
    cm:set_saved_value("derpy_gg_demand_" .. faction,
                       tostring(GG.demand_last[faction] or 0) .. ";" .. body)
end

function GG.load_demand(faction)
    local packed = cm:get_saved_value("derpy_gg_demand_" .. faction)
    GG.demands[faction] = nil
    if not packed or packed == "" then return end
    local last, body = string.match(packed, "^([^;]*);?(.*)$")
    GG.demand_last[faction] = tonumber(last) or 0
    if not body or body == "" then return end
    local guild, kind, amount, due =
        string.match(body, "^([^,]*),([^,]*),(%-?%d+),(%-?%d+)$")
    if guild and GG.is_guild(guild) and (kind == "tribute" or kind == "renounce") then
        GG.demands[faction] = {guild = guild, kind = kind,
                               amount = tonumber(amount), due = tonumber(due)}
    end
end

function GG.turn_now()
    local ok, n = pcall(function() return cm:model():turn_number() end)
    if ok and type(n) == "number" then return n end
    return 0
end

-- 1..n. A campaign without cm:random_number is the harness, not the game, and a
-- deterministic 1 there is a feature rather than a fallback to hide.
function GG.roll(n)
    if n <= 1 then return 1 end
    local ok, r = pcall(function() return cm:random_number(n) end)
    if ok and type(r) == "number" and r >= 1 and r <= n then return r end
    return 1
end

function GG.bounty_pay()
    local n = GG.setting("rate_bounty") or 0
    if n < 0 then return 0 end
    return n
end

-- The target, and the faction that owns it. Both are keys or numbers, never display
-- text: resolving a name here would mean a loc call from a turn handler, which CTDs
-- at turn 1 and is not catchable by pcall. The panel resolves names at draw time.
-- The target, and the faction that owns it. Both are keys or numbers, never display
-- text: resolving a name here would mean a loc call from a turn handler, which CTDs
-- at turn 1 and is not catchable by pcall. The panel resolves names at draw time.
--
-- `used` is the set of targets already on the board. WITHOUT IT TWO GUILDS POST THE SAME
-- WORK: both lord_kill guilds walked to the first general they found and stopped, so the
-- Immortals and the Khanate named the same character, and taking one left the other
-- offering an objective you already had. CA's own contract script keeps
-- used_general_targets and used_region_targets for the same reason.
--
-- Every candidate is gathered before one is picked, rather than stopping at the first
-- hit of the first enemy. That is what makes the dedupe possible at all, and it also
-- lets the board name several enemy factions instead of always the same one.
function GG.bounty_target(faction, kind, used)
    local k = GG.BOUNTY_KINDS[kind]
    if not k then return nil end
    used = used or {}
    -- Assigned inside the closure below and read after it: an upvalue survives the
    -- pcall, so the reason the walk came back empty survives with it.
    local why = "walk never started"
    local ok, target, owner = pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then
            why = "no faction interface"
            return nil
        end
        local wars = f:factions_at_war_with()
        if not wars then
            why = "factions_at_war_with returned nothing"
            return nil
        end
        local n = wars:num_items()
        if n == 0 then
            why = "at war with nobody, so no guild has anyone to send you after"
            return nil
        end

        local found = {}
        for i = 0, n - 1 do
            local e = wars:item_at(i)
            if not e:is_dead() then
                local ename = e:name()
                if k.target == "region" then
                    local rl = e:region_list()
                    for j = 0, rl:num_items() - 1 do
                        local key = rl:item_at(j):name()
                        if key and not used[key] then
                            found[#found + 1] = {key, ename}
                        end
                    end
                else
                    local mfl = e:military_force_list()
                    for j = 0, mfl:num_items() - 1 do
                        local mf = mfl:item_at(j)
                        -- is_armed_citizenry filters garrisons, whose general cannot be
                        -- hunted down on the map. CA's contract script filters the same
                        -- way, for the same reason.
                        if mf:has_general() and not mf:is_armed_citizenry() then
                            local gen = mf:general_character()
                            if gen:has_region() then
                                local cqi = tostring(gen:family_member()
                                                        :command_queue_index())
                                if not used[cqi] then
                                    found[#found + 1] = {cqi, ename}
                                end
                            end
                        end
                    end
                end
            end
        end

        if #found == 0 then
            why = "at war with " .. n .. ", but no unused " .. k.target
                  .. " among them"
            return nil
        end
        local pick = found[GG.roll(#found)]
        return pick[1], pick[2]
    end)
    if ok and target then return target, owner end
    if not ok then
        -- `target` holds the error message when pcall failed.
        GG.trace("bounty target walk ERRORED for " .. tostring(kind) .. ": "
                 .. tostring(target))
    else
        GG.trace("no " .. tostring(kind) .. " target: " .. tostring(why))
    end
    return nil
end

-- IS THIS OFFER STILL TRUE? Checked every post and every draw, because the board is
-- saved and an offer outlives the world it was picked from.
--
-- A region stops being a target the moment you own it - a guild paying you to sack your
-- own settlement is the fault that made this function necessary - and equally when its
-- owner is no longer an enemy, since no guild opens a war for you.
--
-- WHEN THE MODEL CANNOT ANSWER, THE OFFER STAYS. A null interface here means "not
-- found", which is true of a region key this campaign does not have, but it is also what
-- a call that threw looks like. Dropping on a question mark would churn the whole board
-- on any campaign where these lookups behave differently.
function GG.bounty_still_valid(faction, o)
    local k = GG.BOUNTY_KINDS[o and o.kind]
    if not k then return false end
    local ok, valid = pcall(function()
        if k.target == "region" then
            local r = cm:get_region(o.target)
            if not r or r:is_null_interface() then return false end
            local owner = r:owning_faction()
            if not owner or owner:is_null_interface() then return false end
            if owner:name() == faction then return false end
            local f = cm:get_faction(faction)
            if f and not f:is_null_interface() and not f:at_war_with(owner) then
                return false
            end
            return true
        end
        local fm = cm:get_family_member_by_cqi(tonumber(o.target) or 0)
        if not fm or fm:is_null_interface() then return false end
        local c = fm:character()
        if not c or c:is_null_interface() then return false end
        return true
    end)
    if not ok then return true end
    return valid == true
end

-- WHAT THE BOARD SHOWS: the index of every offer still worth showing, and the list left
-- exactly as it was. The panel is drawn on one machine, so purging from the draw changed
-- one machine's board - a desync. Withdrawing is turn start's job; the draw hides an
-- offer that stopped being true mid-turn, and the index it shows is the one a click
-- sends, which is why nothing may move under it.
function GG.bounty_view(faction)
    local list, out = GG.bounties[faction] or {}, {}
    local turn = GG.turn_now()
    for i = 1, #list do
        local o = list[i]
        if o.taken or (turn - (o.posted or 0) < GG.BOUNTY_OFFER_LIFE
                       and GG.bounty_still_valid(faction, o)) then
            out[#out + 1] = i
        end
    end
    return out
end

-- Everything that takes an offer off the board: it ran out of time, it names what
-- another offer already names, or it is no longer true. A TAKEN offer is left alone in
-- all three cases - it is a live mission now, and the game's own turn limit ends it.
function GG.purge_bounties(faction)
    local list = GG.bounties[faction]
    if not list then return 0 end
    local turn = GG.turn_now()
    local dropped = 0

    -- Taken offers claim their targets first, so an untaken duplicate is the one that
    -- goes rather than the mission you are already carrying.
    local seen = {}
    for i = 1, #list do
        if list[i].taken then seen[list[i].target] = true end
    end

    for i = #list, 1, -1 do
        local o = list[i]
        if not o.taken then
            local why = nil
            if turn - (o.posted or 0) >= GG.BOUNTY_OFFER_LIFE then
                why = "expired"
            elseif seen[o.target] then
                why = "duplicate of " .. tostring(o.target)
            elseif not GG.bounty_still_valid(faction, o) then
                why = "target " .. tostring(o.target) .. " is no longer a target"
            end
            if why then
                GG.trace("withdrew " .. tostring(o.guild) .. "'s bounty: " .. why)
                table.remove(list, i)
                dropped = dropped + 1
            else
                seen[o.target] = true
                -- RE-PRICED WHILE IT SITS ON THE BOARD, because the world moves under
                -- it: a lord levels up, a town builds, a stack garrisons the place. An
                -- offer you have TAKEN keeps the price you took it at - that is the
                -- deal you accepted, and re-pricing it under you would be sharp
                -- practice from a guild and a bug report from a player.
                local d = GG.bounty_difficulty(o.kind, o.target)
                if d ~= o.diff then
                    o.diff = d
                    o.gold, o.rep = GG.bounty_price(o.kind, d)
                end
            end
        end
    end
    return dropped
end

-- A DEAD LORD IS NOT A TARGET, AND NO INTERFACE WILL SAY SO. GG.bounty_still_valid can
-- only ask whether the family member and its character resolve, and CA documents the
-- family member as surviving the character outright - model_hierarchy, verbatim: "This
-- interface is persistent, even if the related character is destroyed and recreated."
-- There is no is_dead to poll instead, on FAMILY_MEMBER_SCRIPT_INTERFACE, on
-- CHARACTER_SCRIPT_INTERFACE or on CHARACTER_DETAILS_SCRIPT_INTERFACE; the is_dead CA
-- documents is on the FACTION interface. So that function answers yes over a corpse, and
-- an offer for a lord killed before the bounty was taken stayed on the board forever -
-- reported from play, 2026-09-12.
--
-- CharacterDestroyed is the engine's only notice, and its context carries the family
-- member itself, so this is driven by the event rather than polled.
--
-- ONLY UNTAKEN OFFERS GO. A taken bounty's target dying IS the mission being completed;
-- MissionSucceeded clears that one and pays for it, and withdrawing it here would delete
-- the contract at the moment it was earned.
function GG.drop_bounty_target(cqi)
    if not cqi then return 0 end
    local key = tostring(cqi)
    local dropped = 0
    for faction, list in pairs(GG.bounties) do
        local hit = false
        for i = #list, 1, -1 do
            local o = list[i]
            local k = GG.BOUNTY_KINDS[o.kind]
            if not o.taken and o.target == key and k and k.target == "lord" then
                GG.trace("withdrew " .. tostring(o.guild) .. "'s bounty: target " .. key
                         .. " was destroyed")
                table.remove(list, i)
                hit = true
                dropped = dropped + 1
            end
        end
        -- NOTHING IS WRITTEN WHEN NOTHING MATCHED. This runs for every general lost by
        -- every faction on the map, so a saved value per death would be a write per
        -- battle for a board that did not change.
        if hit then GG.save_bounties(faction) end
    end
    return dropped
end

-- HOW HARD IS THIS TARGET, as a percentage bonus on top of the kind's base pay.
-- 0 is the easiest thing the campaign can offer; GG.BOUNTY_DIFF_MAX is the ceiling, so
-- the hardest bounty pays three times the easiest rather than an unbounded number a
-- lucky roll could turn into a jackpot.
--
-- EVERY PROPERTY BELOW IS ONE CA'S OWN SCRIPTS CALL. Checked by decompressing
-- data_script.pack and grepping all 1,005 files, because the scripting reference is an
-- index of interfaces and not a list of their members: region:num_buildings(),
-- region:is_province_capital() (29 uses), region:garrison_residence(),
-- character:rank() (79 uses), military_force:unit_list().
GG.BOUNTY_DIFF_MAX = 200

GG.BOUNTY_DIFF = {
    per_building   = 25,    -- a region's buildings, the best proxy for its worth
    province_cap   = 40,    -- a provincial capital is a different job to a minor town
    defended       = 35,    -- a real army sits in it, not just the garrison
    per_rank       = 3,     -- a lord's level, which runs 1 to 45ish
    per_unit       = 6,     -- how much army he has around him
    faction_leader = 55,    -- killing the head of a faction
}

-- A dead target, a region this campaign does not have, a lord who left his army: all
-- read as 0 here, which prices the offer at base. NOT as a refusal - an offer that
-- cannot be priced is still a perfectly good offer, it is just worth the minimum.
function GG.bounty_difficulty(kind, target)
    local k = GG.BOUNTY_KINDS[kind]
    if not k then return 0 end
    local D = GG.BOUNTY_DIFF
    local ok, score = pcall(function()
        local n = 0
        if k.target == "region" then
            local r = cm:get_region(target)
            if not r or r:is_null_interface() then return 0 end
            n = n + (r:num_buildings() or 0) * D.per_building
            if r:is_province_capital() then n = n + D.province_cap end
            local gr = r:garrison_residence()
            if gr and not gr:is_null_interface() and gr:has_army() then
                n = n + D.defended
            end
            return n
        end
        local fm = cm:get_family_member_by_cqi(tonumber(target) or 0)
        if not fm or fm:is_null_interface() then return 0 end
        local c = fm:character()
        if not c or c:is_null_interface() then return 0 end
        n = n + (c:rank() or 0) * D.per_rank
        if c:is_faction_leader() then n = n + D.faction_leader end
        local mf = c:military_force()
        if mf and not mf:is_null_interface() then
            n = n + mf:unit_list():num_items() * D.per_unit
        end
        return n
    end)
    if not ok or type(score) ~= "number" or score < 0 then return 0 end
    if score > GG.BOUNTY_DIFF_MAX then return GG.BOUNTY_DIFF_MAX end
    return math.floor(score)
end

-- GOLD SCALES FULLY, REPUTATION AT HALF. Gold is the guild paying for a harder job and
-- can run 3x without touching anything else; reputation drives the rank ladder, whose
-- thresholds are fixed, and bounty reputation is the one grant that does NOT go through
-- the per-turn cap. Tripling it would make one lucky offer worth a whole rank.
function GG.bounty_price(kind, diff)
    local k = GG.BOUNTY_KINDS[kind]
    if not k then return 0, 0 end
    diff = diff or 0
    return math.floor(k.gold * (100 + diff) / 100),
           math.floor(GG.bounty_pay() * (100 + diff / 2) / 100)
end

function GG.make_bounty(faction, guild, turn, used)
    local kind = GG.BOUNTIES[guild]
    local k = kind and GG.BOUNTY_KINDS[kind]
    if not k then return nil end
    local target, owner = GG.bounty_target(faction, kind, used)
    if not target then return nil end
    -- diff is stored, not just the prices it produced: the panel names the job's
    -- difficulty from it, and a re-price on a later turn needs no second read.
    local diff = GG.bounty_difficulty(kind, target)
    local gold, pay = GG.bounty_price(kind, diff)
    return {guild = guild, kind = kind, target = target, owner = owner or "",
            gold = gold, rep = pay, diff = diff, posted = turn, taken = false}
end

-- Called once per faction turn. Withdraws stale offers, then fills the board.
function GG.post_bounties(faction)
    if GG.bounty_pay() <= 0 then
        GG.trace("board for " .. tostring(faction) .. " is off: rate_bounty is "
                 .. tostring(GG.setting("rate_bounty")))
        return
    end
    local list = GG.bounties[faction]
    if not list then list = {}; GG.bounties[faction] = list end
    local turn = GG.turn_now()

    -- Expired, duplicated and no-longer-true offers all leave here.
    GG.purge_bounties(faction)

    -- EVERY TARGET ALREADY ON THE BOARD, so no second guild posts it. This includes
    -- offers taken on an earlier turn: those are live missions, and re-offering the
    -- objective you are already carrying is precisely the fault this fixes.
    local used = {}
    for i = 1, #list do used[list[i].target] = true end

    -- Start from a rolled guild so the board is not always the first three in the
    -- list. Order is otherwise fixed, which keeps the harness deterministic.
    local n = #GG.GUILDS
    local start = GG.roll(n)
    for step = 0, n - 1 do
        if #list >= GG.BOUNTY_SLOTS then break end
        local guild = GG.GUILDS[((start + step - 1) % n) + 1]
        if not GG.bounty_for_guild(faction, guild) then
            local o = GG.make_bounty(faction, guild, turn, used)
            if o then
                list[#list + 1] = o
                used[o.target] = true
            end
        end
    end
    GG.trace("board for " .. tostring(faction) .. ": " .. #list .. " offer(s) on turn "
             .. turn .. ", paying " .. GG.bounty_pay())
end

function GG.bounty_string(faction, o)
    local k = GG.BOUNTY_KINDS[o.kind]
    if not k then return nil end
    -- CLAN_ELDERS is a vanilla mission_issuers row and the issuer this workspace's
    -- own Chaos Dwarf quests already ship. An unknown issuer fails the string parse,
    -- which raises MissionStringParseErrorEvent and nothing the player can see.
    return "mission{"
        .. "key " .. GG.bounty_mission_key(o.guild, faction) .. ";"
        .. "issuer CLAN_ELDERS;"
        .. "turn_limit " .. GG.BOUNTY_TURN_LIMIT .. ";"
        .. "primary_objectives_and_payload{"
        .. "objective{type " .. k.otype .. ";"
        .. string.format(k.obj, o.target) .. ";}"
        .. "payload{money " .. o.gold .. ";}"
        .. "}"
        .. "}"
end

function GG.take_bounty(faction, index)
    local list = GG.bounties[faction]
    local o = list and list[index]
    if not o or o.taken then return false end
    local str = GG.bounty_string(faction, o)
    if not str then return false end
    -- MARKED AND SAVED BEFORE THE ENGINE CALL, NOT AFTER. Marking afterwards is how
    -- one offer issued four missions in the 2026-09-12 session: the trigger can resolve
    -- the mission inside the call that creates it - a KILL_CHARACTER objective naming a
    -- lord who is already dead is exactly that - which raises MissionCancelled, whose
    -- handler calls GG.load_bounties and REPLACES GG.bounties[faction] with a new list
    -- built from the saved value. `o` is then a table nothing points at, the board still
    -- reads untaken, the button stays live and the next click issues the same mission
    -- again. Committing first means any reload inside the trigger reads the flag back.
    o.taken = true
    o.issued = GG.turn_now()
    GG.save_bounties(faction)

    local ok = pcall(function()
        cm:trigger_custom_mission_from_string(faction, str)
    end)
    if not ok then
        -- Nothing was issued, so the offer goes back on the board - found again through
        -- GG.bounties rather than through `o`, because the call may have replaced the
        -- list before it threw and clearing the flag on the old one is the fault this
        -- ordering exists to avoid.
        local now = GG.bounties[faction] or {}
        for i = 1, #now do
            if now[i].target == o.target and now[i].guild == o.guild then
                now[i].taken = false
                now[i].issued = nil
            end
        end
        GG.save_bounties(faction)
        return false
    end
    return true
end

-- Paid straight through GG.grant, NOT capped_grant. The per-turn cap exists to stop
-- one signal being farmed; a bounty is a one-off the player was invited to take, and
-- capping it would make the board lie about what it pays.
function GG.bounty_done(faction, mission_key)
    local list = GG.bounties[faction]
    if not list then return false end
    for i = #list, 1, -1 do
        local o = list[i]
        if o.taken and GG.bounty_mission_key(o.guild, faction) == mission_key then
            -- OFF THE BOARD AND SAVED BEFORE THE PAYOUT, for the reason spelled out in
            -- GG.take_bounty. GG.grant can rank the player up, which shows a message
            -- event; anything that re-enters script from there reloads the board and
            -- puts the offer being paid out back onto it - and the MissionSucceeded
            -- handler saves afterwards, so it would be back for good, unpayable and
            -- unremovable.
            local guild, rep = o.guild, o.rep or 0
            table.remove(list, i)
            GG.save_bounties(faction)
            GG.grant(faction, guild, rep, "bounties")
            return true
        end
    end
    return false
end

-- HANDED BACK. The slot clears and the guild may post again, and there is no penalty -
-- a guild that punishes you for declining work is a guild you would stop dealing with.
--
-- THAT REASONING IS ABOUT DECLINING AND IT WAS BEING APPLIED TO FAILING. This function
-- used to serve both, from one handler registered for MissionFailed and MissionCancelled
-- together, so taking a job and not delivering it cost precisely nothing. Medieval 2 draws
-- the line where it belongs: its guild missions pay +10 and +20 and charge -10 and -20 for
-- a failure, the same magnitude either way, and the guide's advice is simply "do not fail
-- them". GG.bounty_failed below is that half. Returning the offer rather than a boolean is
-- what lets the caller price the penalty off the job that was refused.
function GG.bounty_lost(faction, mission_key)
    return GG.take_bounty_slot(faction, mission_key) ~= nil
end

-- The taken offer matching a mission key, removed from the board. Shared by the two
-- outcomes so they cannot disagree about WHICH offer just ended.
function GG.take_bounty_slot(faction, mission_key)
    local list = GG.bounties[faction]
    if not list then return nil end
    for i = #list, 1, -1 do
        local o = list[i]
        if o.taken and GG.bounty_mission_key(o.guild, faction) == mission_key then
            table.remove(list, i)
            return o
        end
    end
    return nil
end

-- FAILED: taken, and the turn limit ran out or the objective became impossible. The slot
-- clears exactly as a hand-back does AND the guild takes reputation back.
--
-- PRICED OFF THE JOB, not off a flat number. Every offer stores the reputation it would
-- have paid - already scaled by its own difficulty at GG.make_bounty - so a failed hard
-- job costs more than a failed easy one without a second difficulty read, and the
-- symmetry Medieval 2 uses falls out of rate_bounty_fail = 100.
--
-- Returns the guild and the amount taken, or nil, so the caller can announce it. An
-- unannounced reputation loss is the exact fault this mod fixed on the demand clock.
function GG.bounty_failed(faction, mission_key)
    local o = GG.take_bounty_slot(faction, mission_key)
    if not o then return nil end
    local share = GG.setting("rate_bounty_fail")
    if not share or share <= 0 then return o.guild, 0 end
    local cost = math.floor((o.rep or 0) * share / 100)
    if cost <= 0 then return o.guild, 0 end
    return o.guild, GG.penalise(faction, o.guild, cost)
end

-- ITS OWN SAVED VALUE, not a third section of the standings string. GG.load splits
-- that one on the first ";" and reads everything after it as cooldowns, so appending
-- there would have fed a bounty into a cooldown slot.
--
-- Every field is a key or a number. No display text is stored, so no delimiter in the
-- data can ever collide with the "," and ";" used here.
function GG.save_bounties(faction)
    local list = GG.bounties[faction]
    if not list then return end
    local parts = {}
    for i = 1, #list do
        local o = list[i]
        -- APPENDED, like every other packed field in this mod. load_bounties walks
        -- these positionally, so diff goes on the END and a save written before it
        -- existed reads back with diff nil - which prices at base until the next
        -- purge re-reads the target, which is the right answer anyway.
        parts[#parts + 1] = table.concat({o.guild, o.kind, o.target, o.owner or "",
                                          o.gold, o.rep, o.posted,
                                          o.taken and 1 or 0, o.diff or 0}, ",")
    end
    cm:set_saved_value("derpy_gg_bounties_" .. faction, table.concat(parts, ";"))
end

function GG.load_bounties(faction)
    local packed = cm:get_saved_value("derpy_gg_bounties_" .. faction)
    if not packed then return end
    local list = {}
    for chunk in string.gmatch(packed, "[^;]+") do
        local f = {}
        for field in string.gmatch(chunk .. ",", "([^,]*),") do
            f[#f + 1] = field
        end
        if f[1] and GG.BOUNTY_KINDS[f[2]] then
            list[#list + 1] = {guild = f[1], kind = f[2], target = f[3],
                               owner = f[4] or "", gold = tonumber(f[5]) or 0,
                               rep = tonumber(f[6]) or 0,
                               posted = tonumber(f[7]) or 0,
                               taken = f[8] == "1",
                               diff = tonumber(f[9]) or 0}
        end
    end
    GG.bounties[faction] = list
end

function GG.save(faction)
    local f = GG.state[faction]
    if not f then return end
    local parts = {}
    for i = 1, #GG.GUILDS do
        local g = f[GG.GUILDS[i]]
        parts[#parts + 1] = g.rep .. "," .. g.fav
    end
    -- Cooldowns must survive a reload or every service is free after one save.
    -- Packed after the six standing pairs, separated by ";".
    local cds = {}
    local f_cd = GG.cooldowns[faction] or {}
    for i = 1, #GG.SERVICES do
        cds[#cds + 1] = tostring(f_cd[GG.SERVICES[i].key] or 0)
    end
    cm:set_saved_value("derpy_gg_" .. faction,
                       table.concat(parts, "|") .. ";" .. table.concat(cds, "|"))
end

-- ---------------------------------------------------------------------------
-- Services.
--
-- Mirrors SERVICES in tools/gen_great_guilds.py. rank gates it, cost is favour,
-- cd is the cooldown in turns, kind decides the payload. If one side changes,
-- change both - tools/import_great_guilds.py refuses to pack on a mismatch.
GG.SERVICES = {
    {key="caravan_levy",    guild="brass",        rank=2, cost=50,  cd=8,  kind="gold",     value=2500},
    {key="writ_monopoly",   guild="brass",        rank=3, cost=150, cd=12, kind="bundle",   turns=10},
    {key="long_ledger",     guild="brass",        rank=4, cost=400, cd=20, kind="bundle",   turns=15, lead=true},
    {key="oathbound_draft", guild="immortals",    rank=2, cost=50,  cd=6,  kind="bundle",   turns=5},
    {key="hire_immortals",  guild="immortals",    rank=3, cost=150, cd=10, kind="unit"},
    {key="astragoths_levy", guild="immortals",    rank=4, cost=400, cd=15, kind="bundle",   turns=10, lead=true},
    {key="forge_rite",      guild="daemonsmiths", rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="bound_blueprint", guild="daemonsmiths", rank=3, cost=150, cd=14, kind="research"},
    {key="bound_ordnance",  guild="daemonsmiths", rank=4, cost=400, cd=15, kind="bundle",   turns=10, lead=true},
    {key="hobgoblin_eyes",  guild="khanate",      rank=2, cost=50,  cd=6,  kind="shroud"},
    {key="knife_in_dark",   guild="khanate",      rank=3, cost=150, cd=10, kind="bundle",   turns=8},
    {key="khans_price",     guild="khanate",      rank=4, cost=400, cd=18, kind="bundle",   turns=10, hostile=true, lead=true},
    {key="lash_the_gangs",  guild="overseers",    rank=2, cost=50,  cd=6,  kind="bundle",   turns=6},
    {key="raise_ziggurat",  guild="overseers",    rank=3, cost=150, cd=12, kind="building"},
    {key="works_of_zharr",  guild="overseers",    rank=4, cost=400, cd=15, kind="bundle",   turns=12, lead=true},
    {key="coffle_drive",    guild="slavers",      rank=2, cost=50,  cd=8,  kind="bundle",   turns=8},
    {key="slave_tithe",     guild="slavers",      rank=3, cost=150, cd=10, kind="pooled"},
    {key="great_coffle",    guild="slavers",      rank=4, cost=400, cd=18, kind="bundle",   turns=12, lead=true},
}

-- ONE UNIT PER CULTURE, NOT ONE UNIT. This was a single Chaos Dwarf key, and it was the
-- ONLY thing in eighteen services with no path for anybody else - slave_tithe already
-- falls back to gold, and the other sixteen are culture-agnostic bundles, gold, research,
-- shroud and building calls. So "not race-locked", the mod's headline objective, was one
-- table away the whole time.
--
-- Every key below is verified present in vanilla main_units. Each is its race's elite
-- melee regiment at 850-1200 recruitment cost - tier 3 infantry for five of them, and
-- Bretonnia's tier 2 knights, below.
-- A unit key is an unvalidated string - a typo grants nothing, forever, in silence - so
-- check_hire_units() reads this table back out of the Lua and asserts each key against
-- the cached vanilla table.
GG.HIRE_UNIT_BY_CULTURE = {
    ["wh3_dlc23_chd_chaos_dwarfs"] = "wh3_dlc23_chd_inf_infernal_guard_great_weapons",
    ["wh_main_dwf_dwarfs"]         = "wh_main_dwf_inf_hammerers",
    ["wh_main_emp_empire"]         = "wh_main_emp_inf_greatswords",
    -- BRETONNIA HAS NO ELITE INFANTRY, so its guild sells its signature knights instead:
    -- tier 2, 950 gold, the Greatswords' price. Chosen by the user on 2026-09-24 over Foot
    -- Squires (tier 2, 750), which would have been the weakest hire in the mod.
    ["wh_main_brt_bretonnia"]      = "wh_main_brt_cav_knights_of_the_realm",
    ["wh3_main_cth_cathay"]        = "wh3_main_cth_inf_dragon_guard_0",
    ["wh3_main_ksl_kislev"]        = "wh3_main_ksl_inf_tzar_guard_1",
    ["wh2_main_def_dark_elves"]    = "wh2_main_def_inf_black_guard_0",
    -- Swordmasters over Phoenix Guard (1,400), chosen by the user on 2026-09-24.
    ["wh2_main_hef_high_elves"]    = "wh2_main_hef_inf_swordmasters_of_hoeth_0",
}

-- Kept because three other files still read it by name. It is the Chaos Dwarf entry of
-- the table above and nothing else - NOT a fallback for an unmapped culture, which is
-- the whole point of the refusal below.
GG.HIRE_UNIT = GG.HIRE_UNIT_BY_CULTURE["wh3_dlc23_chd_chaos_dwarfs"]

-- NO UNIT FOR AN UNMAPPED CULTURE, and that is a refusal rather than a fallback. This
-- used to hand back the Chaos Dwarf Infernal Guard for any culture not in the table,
-- which was harmless while coverage was three hardcoded keys and every one of them had
-- an entry here. The scope is the player's culture now and it is read at runtime, so the
-- player can perfectly well belong to a culture some mod added - and the fallback would
-- drop a Chaos Dwarf regiment into an Araby or Nippon army, a unit their roster cannot
-- support, bought with their own favour. GG.can_buy refuses the service instead, which
-- costs that culture one service of eighteen and gives it nothing wrong.
function GG.hire_unit(faction)
    return GG.HIRE_UNIT_BY_CULTURE[GG.CULTURE_OF[faction]]
end

GG.cooldowns = GG.cooldowns or {}   -- [faction][service_key] = turns remaining

-- The one place culture matters in this mod, and it is a branch, not a profile
-- table. CULTURE_OF is filled at turn start from the live faction; an unknown
-- faction defaults to Chaos Dwarf because phase 1 ships CHD content.
GG.CHD_CULTURE = "wh3_dlc23_chd_chaos_dwarfs"
GG.CULTURE_OF = GG.CULTURE_OF or {}

-- "missions" is the only factor BOTH Chaos Dwarf pools accept for a positive
-- grant. raw_materials has no "events" junction at all, so events would be a
-- silent no-op on half the payload. Read out of
-- pooled_resource_factor_junctions on 2026-09-10.
GG.TITHE_FACTOR = "missions"

-- EVERY CULTURE THE CAMPAIGN HAS, discovered by the world walk and never listed here.
--
-- NOT THE GATE, and the difference matters. This is what the campaign contains; the
-- gate is GG.player_cultures, which is what the campaign is ABOUT. Two questions that
-- got conflated twice in one day and produced a wrong build each time.
--
-- THE GATE WAS THREE HARDCODED KEYS FIRST, and that silently deleted most of a modded
-- install. A culture key is an unvalidated string like every other key in this game, so
-- a culture that is not in the list does not error - its factions simply never accrue
-- anything, never appear in a table and never lead, forever, with no log line. Measured
-- against one real load order: Old World, Immortal Empires Expanded, the Hobgoblin
-- Khanates, Araby, Albion, Tilea, Estalia, Marienburg, Nippon and Mixu all ship cultures
-- of their own, and not one was reachable. The Hobgoblins are the sharpest case, since
-- the Khanate guild is named for them.
--
-- THE GATE WAS THEN THIS TABLE, which was wrong the other way: it is six guilds of Chaos
-- Dwarf flavour, and a campaign does not want the Empire and the Lizardmen quietly
-- running their own copies of them.
--
-- SO THE SCAN STAYED DYNAMIC AND THE GATE MOVED TO THE PLAYER. This table is still worth
-- having: it is where the roster buckets and the discovered culture keys come from, and
-- it is how the scope reaches a culture invented tomorrow without this file naming it.
-- Populated by GG.scan_world below and empty until then.
GG.CULTURES = GG.CULTURES or {}

-- The cultures this mod ships flavour for. Not a gate - purely which ones have their own
-- guild names, rank names, art and hire unit rather than the Chaos Dwarf fallback.
--
-- `tag` goes on the end of every key the player reads (before the engine's own _title /
-- _primary / _secondary on a message), and `feed` is added to the four feed indexes.
-- tools/gen_great_guilds.py mints the rows behind both and check_flavour_mirror() there
-- compares this table against its own; a mismatch is a raw key or a message that draws
-- nothing, with no error either way.
GG.FLAVOURED = {
    [GG.CHD_CULTURE]       = {tag = "",     feed = 0},
    ["wh_main_emp_empire"] = {tag = "_emp", feed = 10},
    ["wh_main_dwf_dwarfs"] = {tag = "_dwf", feed = 20},
    ["wh_main_brt_bretonnia"] = {tag = "_brt", feed = 40},
    ["wh3_main_cth_cathay"] = {tag = "_cth", feed = 50},
    ["wh3_main_ksl_kislev"] = {tag = "_ksl", feed = 60},
    ["wh2_main_def_dark_elves"] = {tag = "_def", feed = 70},
    ["wh2_main_hef_high_elves"] = {tag = "_hef", feed = 80},
}

-- Cached in GG.CULTURE_OF, which until now was declared and never written to: a
-- faction's culture does not change, and this is asked once per grant per faction per
-- turn.
--
-- AN UNREADABLE CULTURE IS NOT COVERED. Defaulting the unknown case to Chaos Dwarf is
-- precisely the bug being fixed - every faction in the game read as Chaos Dwarf, so a
-- Lizardmen faction led the Brass Tablets in a live campaign. cm:get_faction returns
-- FALSE, not nil, for a key it does not know.
function GG.covered(faction)
    if not faction then return false end
    local c = GG.CULTURE_OF[faction]
    if c == nil then
        local ok, got = pcall(function()
            local f = cm:get_faction(faction)
            if not f or f:is_null_interface() then return false end
            return f:culture()
        end)
        c = false
        if ok and type(got) == "string" and got ~= "" then c = got end
        GG.CULTURE_OF[faction] = c
    end
    -- THE PLAYER'S CULTURE, and only a race GG.FLAVOURED writes guilds for. The first is
    -- read off the human faction by GG.player_cultures; the second is the list above,
    -- since 2026-09-24 - before that any culture a human played was covered.
    --
    -- AN UNREADABLE CULTURE IS NOT COVERED, which was never the bug and must not be lost.
    if c == false or type(c) ~= "string" or c == "" then return false end
    -- ONLY THE RACES THIS MOD WRITES GUILDS FOR. Any other culture gets nothing - no
    -- opener, no standing, no rank-up or demand messages for a panel it cannot open -
    -- even when a human plays it. Checked before the fallback below, so standing an
    -- older build handed every race cannot let one back in.
    if not GG.FLAVOURED[c] then return false end
    local mine = GG.player_cultures()
    -- AN UNREADABLE PLAYER IS NOT A REASON TO COVER NOBODY. get_human_factions is not
    -- answerable during loading, and returning false for everyone there is a turn where
    -- nothing accrues, silently. A faction already holding standing keeps earning.
    if not next(mine) then return GG.state[faction] ~= nil end
    return mine[c] == true
end

-- EVERY OTHER RACE: one race-neutral flavour for every culture this mod ships none for.
-- Since 2026-09-24 such a race gets no guilds at all (GG.covered, GGUI.place_opener), so
-- what still reads this is a message to an unsupported human that a hostile service hit
-- in multiplayer. Mirrored by the FLAVOURS entry whose culture is None in
-- tools/gen_great_guilds.py, which check_flavour_mirror() compares against this.
GG.GENERIC = {tag = "_gen", feed = 30}

-- A culture's flavour: its own entry, the generic one for any other readable culture, and
-- nil for one that cannot be read - an unknown culture is not a reason to guess.
function GG.flavour_of_culture(culture)
    if type(culture) ~= "string" or culture == "" then return nil end
    return GG.FLAVOURED[culture] or GG.GENERIC
end

-- WHICH FLAVOUR A FACTION READS. Fills GG.CULTURE_OF through GG.covered the first time.
function GG.flavour_of(faction)
    if not faction then return nil end
    if GG.CULTURE_OF[faction] == nil then GG.covered(faction) end
    return GG.flavour_of_culture(GG.CULTURE_OF[faction])
end

-- "" for Chaos Dwarfs and for an unreadable culture or nil - so every Chaos Dwarf key,
-- and every key built without a faction, is exactly what it was.
function GG.tag(faction)
    local f = GG.flavour_of(faction)
    return f and f.tag or ""
end

-- A feed index for the faction that RECEIVES the message: the base plus its offset.
function GG.feed(faction, base)
    local f = GG.flavour_of(faction)
    return base + (f and f.feed or 0)
end

local function is_chd(faction)
    return (GG.CULTURE_OF[faction] or GG.CHD_CULTURE) == GG.CHD_CULTURE
end

function GG.payload(faction, s, target)
    if s.kind == "bundle" then
        -- WRITTEN OUT, not as `(s.hostile and target) or faction`. That expression
        -- falls through to the BUYER when target is nil, so the one aggressive service
        -- in the mod applied its malus to the player who paid for it. A hostile bundle
        -- with nobody to put it on does nothing at all; GG.buy refuses the purchase
        -- before it gets here, and this is the second line of defence.
        if s.hostile then
            if not target then return end
            -- The BUYER's tag, on the target too: the victim reads who did it to them.
            cm:apply_effect_bundle("derpy_gg_svc_" .. s.key .. GG.tag(faction), target,
                                   s.turns)
        else
            cm:apply_effect_bundle("derpy_gg_svc_" .. s.key .. GG.tag(faction), faction,
                                   s.turns)
        end

    elseif s.kind == "gold" then
        cm:treasury_mod(faction, s.value)

    elseif s.kind == "unit" then
        -- No target means no grant. A targeted service is never fired blind.
        local unit = GG.hire_unit(faction)
        -- NO UNIT, NO GRANT. GG.can_buy refuses this service for a culture with no unit
        -- mapped, so this branch should be unreachable - but a payload that fires with a
        -- nil unit key is the silent-forever shape, and one `if` is cheaper than trusting
        -- two call sites to stay in step.
        if target and unit then cm:grant_unit_to_character(target, unit) end

    elseif s.kind == "research" then
        -- THREE ARGUMENTS, not two. CA documents the third as "Send a notification to
        -- the event feed that the research is completed, or not" - it was being left
        -- off, and an omitted boolean is nil. Notified for the player only: the AI runs
        -- this from a turn sweep, and a feed line per rival per technology would bury
        -- the player's own feed in other factions' research.
        if target then
            cm:instantly_research_technology(faction, target, GG.is_human(faction))
        end

    elseif s.kind == "shroud" then
        if target then cm:make_region_visible_in_shroud(faction, target) end

    elseif s.kind == "building" then
        -- There is no cm:instantly_upgrade_building. The real call is
        -- cm:region_slot_instantly_upgrade_building(slot, building_key) and it
        -- takes a SLOT object, not a region - so this target is a table of both.
        -- The building key must be a valid upgrade for the chain in that slot.
        if target and target.slot and target.building then
            cm:region_slot_instantly_upgrade_building(target.slot, target.building)
        end

    elseif s.kind == "pooled" then
        if is_chd(faction) then
            cm:faction_add_pooled_resource(faction, "wh3_dlc23_chd_armaments",
                                           GG.TITHE_FACTOR, 400)
            cm:faction_add_pooled_resource(faction, "wh3_dlc23_chd_raw_materials",
                                           GG.TITHE_FACTOR, 800)
        elseif GG.CULTURE_OF[faction] == "wh_main_dwf_dwarfs" then
            -- OATHGOLD, the Dwarfs' own scarce currency. dwf_oathgold is a FACTION pool
            -- every Dwarf faction has, and "missions" is the factor its
            -- dwf_oathgold_quest_rewards junction binds - the one of its nine that takes
            -- either sign. 250 is half what CA's Underdeep pays for one building.
            cm:faction_add_pooled_resource(faction, "dwf_oathgold", GG.TITHE_FACTOR, 250)
        else
            cm:treasury_mod(faction, 3000)
        end
    end
end

function GG.service(key)
    for i = 1, #GG.SERVICES do
        if GG.SERVICES[i].key == key then return GG.SERVICES[i] end
    end
    return nil
end

function GG.cooldown_left(faction, service_key)
    local f = GG.cooldowns[faction]
    if not f then return 0 end
    return f[service_key] or 0
end

function GG.tick_cooldowns(faction)
    local f = GG.cooldowns[faction]
    if not f then return end
    for k, v in pairs(f) do
        if v > 0 then f[k] = v - 1 end
    end
end

-- Returns a REASON KEY, never a sentence. A loc call from a turn handler is a
-- CTD at turn 1; the panel resolves these at draw time.
-- WHAT A SERVICE COSTS YOU, as against what it costs in the abstract. Returns the
-- price and the percentage modifier that produced it, so the panel can show both the
-- number and the reason for it.
--
-- Every input is already in the save: your rank with the guild, and your rank with its
-- rival. No new state, nothing to migrate, and a price that is always exactly derivable
-- from what the player can see on the Standings tab.
GG.FAVOUR_LOYALTY  = 12   -- % off per rank held above the service's own requirement
GG.FAVOUR_RIVALRY  = 10   -- % on per rank its rival holds above it
-- THESE BIND. Four ranks and a gate of 2 means the loyalty term reaches -36% and the
-- rivalry term +40%, so clamps at -45 and +60 were unreachable - two more guards that
-- read as careful and do nothing. At -30 and +30 both fire at the extremes, which is
-- also the better decision: a 36% discount was an accident of the arithmetic.
GG.FAVOUR_MIN_MOD  = -30  -- never cheaper than this
GG.FAVOUR_MAX_MOD  = 30   -- never dearer than this

function GG.service_cost(faction, service_key)
    local svc = GG.service(service_key)
    if not svc then return 0, 0 end

    local rank = GG.rank_of((GG.get(faction, svc.guild)))
    local mod = 0

    -- Loyalty. rank is never below svc.rank when this matters, because can_buy gates
    -- on it first - but a card draws the price before the gate, so clamp at 0 here.
    local above = rank - svc.rank
    if above > 0 then mod = mod - above * GG.FAVOUR_LOYALTY end

    -- Rivalry. Only the rival being AHEAD costs you; being behind is not a discount,
    -- because the loyalty term above already pays you for your own standing and
    -- counting it twice would make one guild free.
    local rival = GG.RIVALS[svc.guild]
    if rival then
        local their_rank = GG.rank_of((GG.get(faction, rival)))
        local ahead = their_rank - rank
        if ahead > 0 then mod = mod + ahead * GG.FAVOUR_RIVALRY end
    end

    -- The patron. A lord bound to this guild takes a flat cut off everything it
    -- sells - the reason to appoint them HERE rather than to the guild you merely have
    -- the most reputation with.
    local p = GG.patrons[faction]
    if p and p.guild == svc.guild then mod = mod - GG.FAVOUR_PATRON end

    if mod < GG.FAVOUR_MIN_MOD then mod = GG.FAVOUR_MIN_MOD end
    if mod > GG.FAVOUR_MAX_MOD then mod = GG.FAVOUR_MAX_MOD end

    -- No floor here. The cheapest base is 50 and the deepest discount 30%, so the
    -- cheapest a service can ever be is 35; a runtime `cost < 1` guard could not fire.
    -- check() asserts that invariant at build time, where it can actually fail.
    return math.floor(svc.cost * (100 + mod) / 100), mod
end

function GG.can_buy(faction, service_key)
    local s = GG.service(service_key)
    if not s then return false, "unknown" end
    if s.hostile and GG.setting("hostile_services") == false then
        return false, "disabled"
    end
    -- NOT IN THE RACE, NOTHING TO BUY. The earning gate alone is not enough here: a save
    -- written under the build that let every culture race still has their standing in it,
    -- so without this an Empire or Lizardmen faction keeps spending a balance it should
    -- never have had - and GGAI buys on behalf of the AI, so it happens with nobody
    -- watching. The lead services were already safe, because GG.leader_of answers nil for
    -- an uncovered culture; the other twelve were not.
    if not GG.covered(faction) then return false, "scope" end
    -- NOTHING TO SELL WHEN THERE IS NO UNIT FOR THIS CULTURE. The scope is the player's
    -- culture, read at runtime, so the player can perfectly well belong to a culture some
    -- mod added - and GG.HIRE_UNIT_BY_CULTURE maps only the three this mod ships flavour
    -- for. The old fallback handed back the Chaos Dwarf Infernal Guard for anything else,
    -- which was harmless while coverage was those same three keys and would now drop a
    -- Chaos Dwarf regiment into an Araby or Nippon army, bought with their own favour.
    -- Refusing costs that culture one service of eighteen; the fallback would cost them a
    -- unit their roster cannot support.
    if s.kind == "unit" and not GG.hire_unit(faction) then
        return false, "no_unit"
    end
    local rep, fav = GG.get(faction, s.guild)
    if GG.rank_of(rep) < s.rank then return false, "rank" end
    -- THE MONOPOLY. A guild's dearest service is sold to whoever leads it and to nobody
    -- else, which is the half that makes the league table a decision. Checked against
    -- the live leader rather than a cached one: leadership can change on any faction's
    -- turn, including while this panel is open.
    if s.lead and GG.setting("lead_monopoly") ~= false then
        -- The buyer's OWN culture. A Chaos Dwarf is not locked out of their guild's
        -- best service because an Empire province out-earned them in a different one.
        if GG.leader_of(s.guild, GG.culture_of(faction)) ~= faction then
            return false, "lead"
        end
    end
    if GG.cooldown_left(faction, service_key) > 0 then return false, "cooldown" end
    if fav < GG.service_cost(faction, service_key) then return false, "favour" end
    return true, nil
end

-- WHICH SERVICES NEED SOMETHING SELECTED ON THE MAP. Every payload shape below reads a
-- target and does nothing without one, so buying one with nothing selected charged the
-- favour, started the cooldown and delivered NOTHING - silently, every time.
--
-- Only `hostile` was guarded, because that one had a visible symptom (the malus landed on
-- the buyer). The other four had no symptom at all: Hire the Immortals with no army
-- selected, Bound Blueprint, Hobgoblin Eyes and Raise the Ziggurat took the payment and
-- returned nothing. Five of eighteen services, from the first build.
--
-- A PREDICATE, NOT A LIST AT EACH CALL SITE. GG.buy refuses on it and the panel greys the
-- card on it, so the button and the till cannot disagree - which is the fault that put
-- the hostile guard here in the first place.
function GG.needs_target(s)
    if not s then return false end
    if s.hostile then return true end
    return s.kind == "unit" or s.kind == "research" or s.kind == "shroud"
        or s.kind == "building"
end

function GG.buy(faction, service_key, target)
    local ok, why = GG.can_buy(faction, service_key)
    if not ok then return false, why end
    local s = GG.service(service_key)
    -- No target, no sale.
    if GG.needs_target(s) and not target then return false, "target" end
    -- THE SAME FUNCTION THE CARD DREW, not s.cost. A card showing 320 and a till
    -- charging 400 is the shape of complaint no check catches.
    local price = GG.service_cost(faction, service_key)
    if not GG.spend(faction, s.guild, price) then
        return false, "favour"
    end
    -- A human's own purchase. GG.log_add ignores the AI; GGAI.log_purchase reports an
    -- AI's to the player of its culture instead.
    GG.log_add(faction, "buy", s.guild, service_key, price)
    GG.cooldowns[faction] = GG.cooldowns[faction] or {}
    GG.cooldowns[faction][service_key] = s.cd
    -- WRITTEN DOWN BEFORE THE PAYLOAD FIRES, and this is the whole of the fix for
    -- "the instant research reverted".
    --
    -- Two of the eighteen payloads raise an event this mod listens for:
    -- cm:instantly_research_technology raises ResearchCompleted and
    -- cm:region_slot_instantly_upgrade_building raises BuildingCompleted. Every listener
    -- in this file opens with GG.load(name), which overwrites GG.state AND GG.cooldowns
    -- from the saved value - so if the engine raises the event inside the call, the
    -- favour just spent comes straight back and the cooldown never starts. Bound
    -- Blueprint completed the technology and refunded itself; Raise a Ziggurat did the
    -- same.
    --
    -- The save used to live in the CALLER - the panel's click handler and GGAI's two -
    -- so the purchase existed only in memory for exactly as long as the payload ran.
    -- Saving here costs one set_saved_value that the caller was about to make anyway,
    -- and it is correct whether the engine raises those events synchronously or not,
    -- which is the part no offline check can settle.
    GG.save(faction)
    GG.payload(faction, s, target)
    return true, nil
end

-- Guarded faction read. cm:get_faction returns FALSE, not nil, and a null
-- interface exposes only is_null_interface. One unguarded read kills every
-- later listener, because call_each has no pcall.
--
-- `get` returns the faction interface and defaults to context:faction(), which only SOME
-- events carry. Check the event's accessors in scripting_doc before relying on the
-- default: the pcall turns a missing member into a permanent, silent nil.
local function faction_name_of(context, get)
    local ok, f = pcall(get or function() return context:faction() end)
    if not ok or not f then return nil end
    if f.is_null_interface and f:is_null_interface() then return nil end
    local ok2, name = pcall(function() return f:name() end)
    if not ok2 then return nil end
    return name
end

-- ---------------------------------------------------------------- settings --
--
-- MCT's own campaign gating is DEAD CODE - set_context_specific has an empty
-- body and set_local_only is commented out end to end. So every economic value is
-- read once and frozen into the save at the first FactionTurnStart. The debug
-- class is deliberately excluded and read live, which is what makes it usable
-- mid-campaign.

GG.TUNE_DEFAULTS = {
    rate_brass = 250, rate_immortals = 15, rate_daemonsmiths = 60,
    rate_khanate = 8, rate_overseers = 10, rate_slavers = 25,
    cap_brass = 40, cap_immortals = 60, cap_daemonsmiths = 0,
    cap_khanate = 40, cap_overseers = 40, cap_slavers = 80,
    ai_spending = true, hostile_services = true,
    guild_notices = true,
    -- Paid to EVERY guild on a completed mission. No cap_missions to go with it:
    -- the grant runs through capped_grant, so each guild's own per-turn cap binds it.
    rate_missions = 10,
    -- Reputation a completed BOUNTY pays its own guild. An order of magnitude above
    -- rate_missions on purpose: a bounty is chosen, targeted and time-limited work.
    -- 0 empties the board - GG.post_bounties returns before it offers anything.
    rate_bounty = 80,
    -- Reputation a guild LOSES when its rival earns, as a percentage of that earning.
    -- 0 switches rivalry off entirely and the six guilds go back to being independent
    -- counters. 40 means a guild you never feed slides while one you do climbs.
    rate_rivalry = 40,
    -- LEADERSHIP. Off, the six leadership bundles still apply - leading is still worth
    -- something - but the top service goes back to being rank-gated only.
    lead_monopoly = true,
    -- DEMANDS. 0 switches them off entirely: GG.demand_tick returns before it rolls.
    demand_every = 12,       -- turns between demands
    demand_turns = 8,        -- turns you have to pay one
    demand_reward = 120,     -- reputation a paid demand pays
    demand_penalty = 60,     -- reputation an ignored one costs
    -- UPKEEP. Reputation every guild with standing loses per turn, as a percentage of the
    -- rank held - 100 means 1 a turn at Unmarked and 5 at Exalted. 0 switches it off and
    -- the ladder goes back to being a one-way ratchet.
    rate_decay = 100,
    -- The turn it starts. Medieval 2's own grace period, kept.
    decay_from = 25,
    -- Reputation a FAILED bounty costs, as a percentage of what completing it would have
    -- paid. 100 is Medieval 2's symmetry: the failure is worth what the success was.
    -- Handing a bounty back through the objectives panel is not a failure and is free.
    rate_bounty_fail = 100,
    -- THE PATRON. Extra reputation, as a percentage, for the guild the patron serves.
    rate_patron = 50,
}

-- Frozen order, so the packed string survives a defaults table that gains keys.
GG.TUNE_ORDER = {
    "rate_brass", "rate_immortals", "rate_daemonsmiths",
    "rate_khanate", "rate_overseers", "rate_slavers",
    "cap_brass", "cap_immortals", "cap_daemonsmiths",
    "cap_khanate", "cap_overseers", "cap_slavers",
    "ai_spending", "hostile_services",
    -- APPENDED, AND NEW KEYS MUST KEEP BEING APPENDED. unpack_tune walks this list
    -- positionally against a "|"-joined string held in the save, seeding from
    -- TUNE_DEFAULTS first. A key added at the END leaves older saves - which carry
    -- one field fewer - correctly on the default. A key inserted anywhere else
    -- shifts every value after it onto the wrong setting, silently.
    "rate_missions",
    "rate_bounty",
    "rate_rivalry",
    "lead_monopoly",
    "demand_every",
    "demand_turns",
    "demand_reward",
    "demand_penalty",
    "rate_patron",
    "guild_notices",
    "rate_decay",
    "decay_from",
    "rate_bounty_fail",
}

GG.TUNE = GG.TUNE or nil

-- ---------------------------------------------------------------------------
-- DIFFICULTY PRESETS.
--
-- Twenty-four tunable values is a wall for a player who only wants the climb slower. A
-- preset is one dropdown that resolves all of them.
--
-- A PRESET OWNS THE NUMBERS AND NEVER THE SWITCHES, which is where this deliberately
-- parts company with the Zharr Exchange. EX.opt_live reads PAST every per-key option
-- under any preset but custom, so all seven of that mod's checkboxes are inert unless the
-- player picks Custom. Two of the four switches here are not difficulty at all -
-- guild_notices is a notification preference and lead_monopoly is a rules toggle - and a
-- switch that silently does nothing is the exact defect this mod shipped once already.
-- check_presets() in tools/gen_great_guilds.py refuses the build if a preset names a
-- boolean key.
--
-- rate_brass IS A DIVISOR. Income reputation is floor(net_income / rate_brass), so LOWER
-- is faster and it runs the opposite way to the other five rates. The harness asserts the
-- direction of every rate across the four presets rather than trusting this comment.
--
-- cap_daemonsmiths IS ABSENT FROM ALL FOUR, deliberately: 0 there means UNCAPPED, so any
-- number would turn the one uncapped guild into a capped one - a restriction wearing a
-- tuning value's clothes. The harness asserts no preset names it.
--
-- These are shapes, not measurements, exactly as spec section 4.5 says of the defaults
-- they are derived from. Only a soak run settles them.
GG.PRESET_DEFAULT = "default"
GG.PRESET_CUSTOM = "custom"

GG.PRESETS = {
    -- EMPTY ON PURPOSE. GG.TUNE_DEFAULTS is the default; a second copy of those numbers
    -- here would be a second place to forget to update.
    default = {},

    -- A FASTER CLIMB AND A GENTLER COURT. Roughly a third more standing per event, caps
    -- raised to match so the rate is not immediately eaten by the ceiling, demands half as
    -- often with twice as long to answer and half the sting for missing one, and the
    -- rivalry drain halved so a wide spread of guilds stays viable.
    easy = {
        rate_brass = 180,
        rate_immortals = 22, rate_daemonsmiths = 90, rate_khanate = 12,
        rate_overseers = 15, rate_slavers = 38,
        cap_brass = 60, cap_immortals = 90, cap_khanate = 60,
        cap_overseers = 60, cap_slavers = 120,
        rate_missions = 15, rate_bounty = 120, rate_rivalry = 20, rate_patron = 75,
        demand_every = 18, demand_turns = 12, demand_reward = 150, demand_penalty = 30,
        -- Half upkeep and forty turns of grace, and a failed bounty costs a third of what
        -- it would have paid rather than all of it.
        rate_decay = 50, decay_from = 40, rate_bounty_fail = 35,
    },

    -- SLOWER, AND THE COURT PRESSES. About a quarter less per event against tighter caps,
    -- demands every nine turns with six to answer, and an ignored one costing half again
    -- what it does by default.
    hard = {
        rate_brass = 350,
        rate_immortals = 11, rate_daemonsmiths = 45, rate_khanate = 6,
        rate_overseers = 7, rate_slavers = 18,
        cap_brass = 30, cap_immortals = 45, cap_khanate = 30,
        cap_overseers = 30, cap_slavers = 60,
        rate_missions = 8, rate_bounty = 60, rate_rivalry = 60, rate_patron = 40,
        demand_every = 9, demand_turns = 6, demand_reward = 100, demand_penalty = 90,
        -- Half again the upkeep from turn 20, and a failed bounty costs its full worth.
        rate_decay = 150, decay_from = 20, rate_bounty_fail = 100,
    },

    -- CUTTHROAT. Standing is roughly half the default rate against caps to match, the
    -- rivalry drain is more than double, and the Court asks every six turns with five to
    -- answer and a penalty above its own reward - so an unpayable demand is a real loss of
    -- rank rather than a delay. Specialising in two or three guilds stops being a style
    -- and becomes the only way through.
    ultra = {
        rate_brass = 500,
        rate_immortals = 8, rate_daemonsmiths = 35, rate_khanate = 4,
        rate_overseers = 5, rate_slavers = 13,
        cap_brass = 22, cap_immortals = 34, cap_khanate = 22,
        cap_overseers = 22, cap_slavers = 45,
        rate_missions = 6, rate_bounty = 45, rate_rivalry = 85, rate_patron = 30,
        demand_every = 6, demand_turns = 5, demand_reward = 90, demand_penalty = 130,
        -- Double upkeep from turn 12, and a failed bounty costs half again what it would
        -- have paid - so taking a job you cannot finish is worse than never taking it.
        rate_decay = 200, decay_from = 12, rate_bounty_fail = 150,
    },
}

-- Apply a preset's numbers onto a settings table. PURE, so the harness can drive every
-- preset without MCT. An unknown name, an empty string and nil all resolve to the shipped
-- defaults rather than erroring: this runs before the first turn of a campaign, where a
-- raise would take the whole mod down with it.
function GG.apply_preset(t, preset)
    if type(preset) ~= "string" or preset == "" then preset = GG.PRESET_DEFAULT end
    if preset == GG.PRESET_CUSTOM then return t end
    local p = GG.PRESETS[preset]
    if type(p) ~= "table" then return t end
    for k, v in pairs(p) do t[k] = v end
    return t
end

-- MULTIPLAYER PLAYS ON THE HOST'S SETTINGS.
--
-- MCT IS A LOCAL REGISTRY, so each machine reading its own would freeze a DIFFERENT
-- economy into each save - a desync from the first grant. MCT does send the host's values
-- to the clients, but over two network round trips nothing orders against this mod's
-- snapshot. So the mod carries them itself: at the first tick of a campaign with no
-- settings yet, the host alone reads its MCT and sends the packed result (GG.send_tune).
-- It arrives as a UITrigger, which CA delivers to every machine in one order, and every
-- machine freezes it there (GG.MP_OPS.tune). Until then every machine plays the shipped
-- defaults and freezes nothing. A host without MCT sends nothing, and the campaign stays
-- on the defaults.
--
-- AN ENGINE CALL THAT ERRORS READS AS SINGLE PLAYER. `ok and v == true` is the safe way
-- round: locking a singleplayer campaign out of its own settings because a call failed is
-- a worse failure than the one being guarded.
function GG.is_mp()
    local ok, v = pcall(function() return cm:is_multiplayer() end)
    return ok and v == true
end

-- WHICH MACHINE IS THE HOST: the flag MCT sets in the multiplayer lobby, and the one its
-- own campaign sync reads to decide who sends (groovy_mct, systems/sync/main.lua).
function GG.is_mct_host()
    local ok, v = pcall(function() return core:svr_load_bool("mct_local_is_host") end)
    return ok and v == true
end


function GG.setting(key)
    if GG.TUNE and GG.TUNE[key] ~= nil then return GG.TUNE[key] end
    return GG.TUNE_DEFAULTS[key]
end

function GG.read_mct_or_defaults()
    local t = {}
    for k, v in pairs(GG.TUNE_DEFAULTS) do t[k] = v end
    -- In multiplayer only the host gets here - see GG.send_tune.
    local ok, mct = pcall(function() return get_mct and get_mct() end)
    if not ok or not mct then return t end
    pcall(function()
        local mod = mct:get_mod_by_key("derpy_great_guilds")
        if not mod then return end
        -- THE PRESET FIRST, and it decides whether the per-key NUMBER reads happen at all.
        local preset = GG.PRESET_DEFAULT
        local popt = mod:get_option_by_key("preset")
        if popt then
            local pv = popt:get_finalized_setting()
            if type(pv) == "string" and pv ~= "" then preset = pv end
        end
        -- THE SWITCHES ARE READ ON EVERY PRESET. Only the numbers belong to a preset; see
        -- the GG.PRESETS comment for why this parts company with the Exchange.
        --
        -- TYPE-CHECKED, NOT NIL-CHECKED. MCT hands back whatever the option holds, and a
        -- mis-registered option can hand back a number for a checkbox. Anything that is
        -- not the shape of the default is the default.
        for i = 1, #GG.TUNE_ORDER do
            local key = GG.TUNE_ORDER[i]
            if type(GG.TUNE_DEFAULTS[key]) == "boolean" then
                local opt = mod:get_option_by_key(key)
                if opt then
                    local val = opt:get_finalized_setting()
                    if type(val) == "boolean" then t[key] = val end
                end
            end
        end
        if preset ~= GG.PRESET_CUSTOM then
            GG.apply_preset(t, preset)
            return
        end
        for i = 1, #GG.TUNE_ORDER do
            local key = GG.TUNE_ORDER[i]
            if type(GG.TUNE_DEFAULTS[key]) == "number" then
                local opt = mod:get_option_by_key(key)
                if opt then
                    local val = opt:get_finalized_setting()
                    if type(val) == "number" then t[key] = val end
                end
            end
        end
    end)
    return t
end

function GG.pack_tune(t)
    local parts = {}
    for i = 1, #GG.TUNE_ORDER do
        local v = t[GG.TUNE_ORDER[i]]
        -- A KEY THE TABLE DOES NOT HOLD FALLS BACK TO ITS DEFAULT, not to 0. It used
        -- to write 0, which for a rate means OFF: packing a partial table silently
        -- switched off every setting it did not mention. Found when rate_missions was
        -- added and every mission paid nothing, because the table being packed had
        -- been built before that key existed - exactly the shape an older save has.
        if v == nil then v = GG.TUNE_DEFAULTS[GG.TUNE_ORDER[i]] end
        if v == true then v = 1 elseif v == false then v = 0 end
        parts[#parts + 1] = tostring(v or 0)
    end
    return table.concat(parts, "|")
end

function GG.unpack_tune(packed)
    local t, i = {}, 1
    for k, v in pairs(GG.TUNE_DEFAULTS) do t[k] = v end
    for chunk in string.gmatch(packed or "", "[^|]+") do
        local key = GG.TUNE_ORDER[i]
        if key then
            if type(GG.TUNE_DEFAULTS[key]) == "boolean" then
                t[key] = (tonumber(chunk) or 0) ~= 0
            else
                t[key] = tonumber(chunk) or GG.TUNE_DEFAULTS[key]
            end
        end
        i = i + 1
    end
    return t
end

function GG.snapshot_settings()
    local existing = cm:get_saved_value("derpy_gg_tuned")
    if existing and existing ~= "" then
        GG.TUNE = GG.unpack_tune(existing)
        return
    end
    -- MULTIPLAYER WAITS FOR THE HOST'S SETTINGS, on the defaults and freezing nothing.
    if GG.is_mp() then
        GG.TUNE = nil
        return
    end
    GG.TUNE = GG.read_mct_or_defaults()
    cm:set_saved_value("derpy_gg_tuned", GG.pack_tune(GG.TUNE))
end

-- THE LONGEST EVENT STRING SENT: MCT's MultiplayerCommunicator splits above 100, and it
-- is the only number anyone has committed to. CA documents none.
GG.TUNE_CHUNK = 100

-- The packed settings cut into parts that fit, each "i/n|v|v|..." so the far side knows
-- when it holds them all.
function GG.tune_chunks(packed)
    local room = GG.TUNE_CHUNK - #(GG.MP_TAG .. "|tune|99/99|")
    local chunks, cur, len = {}, {}, 0
    for v in string.gmatch(packed or "", "[^|]+") do
        local add = #v + (#cur > 0 and 1 or 0)
        if #cur > 0 and len + add > room then
            chunks[#chunks + 1] = table.concat(cur, "|")
            cur, len, add = {}, 0, #v
        end
        cur[#cur + 1] = v
        len = len + add
    end
    if #cur > 0 then chunks[#chunks + 1] = table.concat(cur, "|") end
    for i = 1, #chunks do chunks[i] = i .. "/" .. #chunks .. "|" .. chunks[i] end
    return chunks
end

-- THE HOST SENDS ITS SETTINGS, once, at the first tick of a campaign that has none.
function GG.send_tune()
    if not GG.is_mp() or not GG.is_mct_host() then return end
    local existing = cm:get_saved_value("derpy_gg_tuned")
    if existing and existing ~= "" then return end
    local ok, me = pcall(function() return cm:get_local_faction_name(true) end)
    if not ok or not me then return end
    local chunks = GG.tune_chunks(GG.pack_tune(GG.read_mct_or_defaults()))
    for i = 1, #chunks do GG.mp_send(me, "tune", chunks[i]) end
    GG.trace("sent this campaign's settings to every player, in " .. #chunks .. " parts")
end

-- The parts received so far, by index. Session only: they all arrive in one burst.
GG.tune_parts = GG.tune_parts or {}

function GG.register()
    -- Every condition below is the literal `true`. A listener condition that
    -- errors drops with no log line at all, so the work happens in the handler.

    -- THE MULTIPLAYER TRANSPORT'S RECEIVING END - see GG.mp_send. Registered and silent
    -- in single player, where nothing is ever broadcast.
    core:add_listener("gg_mp", "UITrigger", true, function(context)
        local ok, err = pcall(function()
            local f = GG.mp_receive(context:trigger(), context:faction_cqi())
            if f and GG.after_mp then GG.after_mp(f) end
        end)
        if not ok then GG.trace("UITrigger failed: " .. tostring(err)) end
    end, true)

    core:add_listener("gg_turn", "FactionTurnStart", true, function(context)
        local name = faction_name_of(context)
        if not name then return end
        GG.snapshot_settings()
        GG.load(name)
        GG.assert_ranks(name)
        GG.reset_turn(name)
        -- UPKEEP BEFORE INCOME, so the line below is what the turn NETTED. Charged before
        -- GG.on_turn_start rather than after because the two read as one transaction on the
        -- panel and the panel shows income; a turn that earns more than it owes still ends
        -- up ahead either way, since GG.penalise and GG.capped_grant touch different
        -- fields and neither is capped against the other.
        GG.decay(name, GG.turn_now())
        GG.tick_cooldowns(name)
        local ok, income = pcall(function() return context:faction():net_income() end)
        GG.on_turn_start(name, ok and income or 0)
        local human = false
        local okh, h = pcall(function() return context:faction():is_human() end)
        if okh then human = h end
        -- THE AI'S ONLY ROUTE TO THE DAEMONSMITHS - see GG.on_tech_count. Before the save
        -- below, so the grant is written down with everything else this turn earned.
        -- COVERED FACTIONS ONLY: this listener fires for every faction in the world, and
        -- the first live round wrote 277 counts for the ~15 the grant can ever reach.
        if not human and GG.covered(name) then
            local okn, n = pcall(function()
                return context:faction():num_completed_technologies()
            end)
            if okn then GG.on_tech_count(name, n) end
        end
        GG.save(name)
        -- HUMAN FACTIONS ONLY. The board is a panel the AI never opens: GGAI spends
        -- favour on services and knows nothing about bounties. Posting for everyone
        -- would walk every enemy faction's region list once per faction per turn and
        -- write a saved value per faction, to build a board nothing ever reads.
        -- CA's own contracts gate on is_human() for the same reason.
        if human then
            GG.load_bounties(name)
            GG.post_bounties(name)
            GG.save_bounties(name)

            -- THE PATRON, re-read from the character every turn. The lord can die, lose
            -- their army or be given a new one without this mod hearing about any of
            -- it, and a post pointing at a force that no longer exists is a discount
            -- with no bundle behind it.
            GG.load_patron(name)
            GG.assert_patron(name)
            GG.save_patron(name)

            -- RE-READ FROM THE SAVE, not trusted from the session. GG.researching is a
            -- plain table and a load starts it empty, so without this a player who
            -- saved mid-research and came back would find Bound Blueprint refusing
            -- until they queued something new.
            GG.load_research(name)

            -- THE DEMAND. This branch is the PLAYER's half only - the AI runs the same
            -- two calls from GGAI.court_step, so a rival faces the same demands and
            -- appoints the same patron. Split by file rather than shared here because
            -- the player's half has a panel and a feed message on it and the AI's has
            -- neither.
            GG.load_demand(name)
            local what, d = GG.demand_tick(name, GG.turn_now())
            GG.save_demand(name)
            -- SAVED AGAIN. An expired demand takes reputation, and the GG.save above
            -- ran before that happened - so without this the penalty is applied to the
            -- live table and thrown away at the next load.
            GG.save(name)
            if what then GG.announce_demand(name, what, d) end
        end

        -- WHO LEADS EACH GUILD, on every faction's turn start rather than the player's.
        -- Leadership is global: an AI out-earning you on its own turn takes the bundle
        -- and the monopoly off you there and then, and the panel has to be able to say
        -- so the next time it is opened.
        GG.reassert_leaders()
    end, true)

    core:add_listener("gg_tech", "ResearchCompleted", true, function(context)
        local name = faction_name_of(context)
        if not name then return end
        -- HUMANS ONLY. The AI is paid off the technology count at its turn start, so an
        -- AI reaching here - a mod calling cm:instantly_research_technology on one would
        -- raise this - must not be paid a second time.
        if not GG.is_human(name) then return end
        GG.load(name); GG.on_tech(name); GG.save(name)
        -- THE SUBJECT IS DONE, so Bound Blueprint has nothing to buy until the next one
        -- is queued. Cleared unconditionally rather than compared against the finished
        -- key: the service completing the research is itself what raises this event, so
        -- the two are the same technology in the case that matters.
        GG.clear_research(name); GG.save_research(name)
    end, true)

    -- WHAT BOUND BLUEPRINT BUYS. context:technology() is the key, per CA's
    -- scripting_doc - interface NONE, "Access the technology key in the event".
    core:add_listener("gg_research_started", "ResearchStarted", true, function(context)
        local ok, name = pcall(function() return context:faction():name() end)
        if not ok or not name then return end
        -- THE PLAYER'S CULTURE ONLY: the humans, and the AI factions of their race -
        -- about fifteen in Immortal Empires - which buy Bound Blueprint off this record.
        -- The event fires for every faction in the campaign, about 190, and a saved value
        -- for each would be keys in the save for factions that can never buy anything.
        if not GG.covered(name) then return end
        -- WHETHER THE EVENT REACHES THE AI AT ALL is unmeasured - ResearchCompleted does
        -- not - so the first time it does is said once a session. No line in a log that
        -- has an AI turn in it means the AI never gets a record and never buys this.
        if not GG.research_seen_ai and not GG.is_human(name) then
            GG.research_seen_ai = true
            GG.trace("ResearchStarted reached AI faction " .. tostring(name)
                     .. " - the AI can buy Bound Blueprint")
        end
        local okt, tech = pcall(function() return context:technology() end)
        if not okt then return end
        if GG.set_research(name, tech) then GG.save_research(name) end
    end, true)

    -- BuildingCompleted carries `building` - BUILDING_SCRIPT_INTERFACE - verified in CA's
    -- scripting_doc: "Access the building in the event". That interface is where both of
    -- the things this needs live: building_level() ("Level of this building", card32) and
    -- chain() ("The key for the building chain (building_chain_record key)"). The old
    -- handler read neither and passed a hardcoded level of 1.
    --
    -- READ IT, DO NOT DERIVE IT. The building's own key ends in a number and that number
    -- is NOT the level - three different numbers disagree across the key suffix, the DB
    -- column and the panel - so building_level() is the only honest source.
    --
    -- ONE pcall EACH, and a failure of either is survivable: no level means the base rate,
    -- and no chain means the Overseers, which is exactly what every building paid before.
    -- THE OWNER COMES OFF THE BUILDING. BuildingCompleted has NO context:faction() -
    -- scripting_doc lists building and garrison_residence and nothing else, and every one
    -- of CA's handlers reads context:building():faction(). This listener used to call the
    -- member that is not there, the pcall ate it, and no building paid any guild for any
    -- faction from the day the mod shipped until 2026-09-23. The garrison is the second
    -- route, so a building() that fails to answer still finds who to pay.
    core:add_listener("gg_building", "BuildingCompleted", true, function(context)
        local name = faction_name_of(context, function()
                         return context:building():faction() end)
                     or faction_name_of(context, function()
                         return context:garrison_residence():faction() end)
        if not name then return end
        local level, chain
        local okb, b = pcall(function() return context:building() end)
        if okb and b and not b:is_null_interface() then
            local okl, lv = pcall(function() return b:building_level() end)
            if okl then level = lv end
            local okc, ch = pcall(function() return b:chain() end)
            if okc then chain = ch end
        end
        GG.load(name); GG.on_building(name, level, chain); GG.save(name)
    end, true)

    -- MissionSucceeded carries `faction` itself - verified in CA's scripting_doc,
    -- 2026-09-11: mission, faction, campaign_model. No walk from a character, and
    -- no repeat of the BattleCompleted trap described below.
    core:add_listener("gg_mission", "MissionSucceeded", true, function(context)
        local ok, name = pcall(function() return context:faction():name() end)
        if not ok or not name then return end
        -- mission_record_key() is the mission's own key - one of exactly five
        -- functions on CAMPAIGN_MISSION_SCRIPT_INTERFACE (is_null_interface, model,
        -- faction, mission_record_key, mission_issuer_record_key), verified in CA's
        -- scripting_doc on 2026-09-11.
        local _, mkey = pcall(function()
            return context:mission():mission_record_key()
        end)
        GG.load(name); GG.load_bounties(name)
        -- A BOUNTY IS NOT ALSO A GENERIC MISSION. It pays its own guild properly, and
        -- paying the blanket rate on top would pay five guilds for work they never
        -- asked for.
        if not (mkey and GG.bounty_done(name, mkey)) then
            GG.on_mission(name)
        end
        GG.save(name); GG.save_bounties(name)
    end, true)

    -- THE ONLY DEATH NOTICE THE ENGINE GIVES. CharacterDestroyed's context carries
    -- `family_member` - CA's own words, "Family Member of the character that was
    -- destroyed" - which is the same cqi a lord bounty stores as its target. There is no
    -- is_dead anywhere to poll instead; see GG.drop_bounty_target.
    core:add_listener("gg_character_destroyed", "CharacterDestroyed", true,
        function(context)
            local ok, cqi = pcall(function()
                local fm = context:family_member()
                if not fm or fm:is_null_interface() then return nil end
                return fm:command_queue_index()
            end)
            if ok and cqi then GG.drop_bounty_target(cqi) end
        end, true)

    -- TWO OUTCOMES, AND THEY ARE NOT THE SAME THING. Both free the slot so the guild can
    -- post again; only one of them costs reputation.
    --
    -- CA DOCUMENTS THE CONTEXT OF BOTH EVENTS AND THE MEANING OF NEITHER. scripting_doc
    -- gives MissionFailed and MissionCancelled identical members - mission, faction,
    -- campaign_model - and says nothing about which fires when, and CA's own Iron Favour
    -- script uses MissionCancelled purely to unregister a mission manager, which does not
    -- settle it either. So the split below is an INFERENCE from the names: failed means
    -- taken and not delivered, which is what a turn limit running out produces, and
    -- cancelled means withdrawn. That is why the penalty is a setting - if play shows the
    -- two events the other way round, rate_bounty_fail = 0 turns it off without a patch.
    core:add_listener("gg_bounty_MissionCancelled", "MissionCancelled", true,
        function(context)
            local ok, name = pcall(function() return context:faction():name() end)
            if not ok or not name then return end
            local _, mkey = pcall(function()
                return context:mission():mission_record_key()
            end)
            if not mkey then return end
            GG.load_bounties(name)
            if GG.bounty_lost(name, mkey) then GG.save_bounties(name) end
        end, true)

    core:add_listener("gg_bounty_MissionFailed", "MissionFailed", true,
        function(context)
            local ok, name = pcall(function() return context:faction():name() end)
            if not ok or not name then return end
            local _, mkey = pcall(function()
                return context:mission():mission_record_key()
            end)
            if not mkey then return end
            GG.load_bounties(name)
            local guild, took = GG.bounty_failed(name, mkey)
            if not guild then return end
            GG.save_bounties(name)
            -- THE REPUTATION LIVES IN A DIFFERENT SAVED VALUE from the board, so both
            -- have to be written. Without the second, the penalty lands on the live table
            -- and is thrown away at the next load - the same fault the demand clock had.
            GG.save(name)
            if took and took > 0 then GG.announce_bounty_fail(name, guild, took) end
        end, true)

    -- THE KHANATE'S OWN SIGNAL, and it had none: GG.on_agent_action existed, was
    -- commented and was harness-tested, and nothing in the game ever called it. Two
    -- events because an action against a CHARACTER and one against a GARRISON are
    -- separate events - a hero sabotaging a settlement raises the second, never the
    -- first - and they carry the same five result flags.
    --
    -- `mission_result_critial_success` is spelled that way in CA's own context. It is
    -- their typo, not one here, and the correctly-spelled name returns nothing.
    for _, event in ipairs({"CharacterCharacterTargetAction",
                            "CharacterGarrisonTargetAction"}) do
        core:add_listener("gg_agent_" .. event, event, true, function(context)
            local ok, name = pcall(function()
                return context:character():faction():name()
            end)
            if not ok or not name then return end
            local won = false
            pcall(function()
                won = context:mission_result_success()
                      or context:mission_result_critial_success()
            end)
            GG.load(name); GG.on_agent_action(name, won); GG.save(name)
        end, true)
    end

    -- THE SLAVERS' OWN SIGNAL, likewise dead. PAST TENSE on both names:
    -- CharacterSacksSettlement and CharacterRazesSettlement are the present-tense pair
    -- and carry only `loot`, while these two carry the character - which is the only
    -- way to reach the faction that did it.
    for _, event in ipairs({"CharacterSackedSettlement",
                            "CharacterRazedSettlement"}) do
        core:add_listener("gg_sack_" .. event, event, true, function(context)
            local ok, name = pcall(function()
                return context:character():faction():name()
            end)
            if not ok or not name then return end
            GG.load(name)
            GG.on_settlement(name, event == "CharacterRazedSettlement")
            GG.save(name)
        end, true)
    end

    -- CharacterCompletedBattle, NOT BattleCompleted. BattleCompleted's context
    -- carries only `model` - no faction, no winner - so context:faction() on it
    -- would throw and kill every listener registered after it. Verified against
    -- CA's scripting_doc on 2026-09-10:
    --   CharacterCompletedBattle -> pending_battle, character
    --   character:won_battle()   -> bool, "was the character in the winning alliance"
    core:add_listener("gg_battle", "CharacterCompletedBattle", true, function(context)
        local ok, char = pcall(function() return context:character() end)
        if not ok or not char then return end
        if char.is_null_interface and char:is_null_interface() then return end
        local okw, won = pcall(function() return char:won_battle() end)
        if not okw or not won then return end
        local okf, name = pcall(function() return char:faction():name() end)
        if not okf or not name then return end
        -- One award per faction per battle: a battle with three of your generals
        -- in it is one win, not three. The per-turn cap of 60 bounds it anyway,
        -- but the guard keeps a single battle from eating the whole turn's cap.
        GG.battle_award(name, GG.was_outnumbered(context))
    end, true)
end

-- Reads the pending battle to decide whether the win was against the odds.
-- Returns false on anything unreadable rather than guessing, so a bad read costs
-- the doubled award and nothing else.
-- Did this faction win against the odds? THE ENGINE ANSWERS THIS ITSELF:
-- pending_battle:attacker_is_stronger() is its own verdict on the two sides, so there is
-- no unit counting here and no argument about what "outnumbered" means.
--
-- This used to `return false` unconditionally while the Immortals' description promised
-- "doubles when you win outnumbered". It never doubled.
--
-- Which side the character was on decides how to read that verdict: an attacker was
-- outnumbered when the attacker was NOT the stronger, a defender when the attacker WAS.
-- Secondary attackers count as attackers - an ally joining your assault is still an
-- assault.
-- THE FEED. A demand that arrives silently is a deadline nobody saw, and one that
-- expires silently is a rank lost with no cause on screen. Loc KEYS only - this runs
-- from a turn handler, where resolving a name is a CTD.
--
-- 5002 is the second of this mod's two event_feed_message_events indices, minted by
-- tools/gen_great_guilds.py along with the four rows behind it. An index with no record
-- makes show_message_event log the call and draw nothing.
GG.FEED_INDEX_DEMAND = 5002

function GG.announce_demand(faction, what, _demand)
    local stem = "message_event_text_text_derpy_gg_demand"
    if what == "expired" then stem = stem .. "_fail" end
    stem = stem .. GG.tag(faction)
    pcall(function()
        cm:show_message_event(faction, stem .. "_title", stem .. "_primary",
                              -- true, not false: the record is a
                              -- scripted_persistent_event and the flag has to agree
                              -- with it or nothing draws.
                              stem .. "_secondary", true,
                              GG.feed(faction, GG.FEED_INDEX_DEMAND))
    end)
end

-- A BOUNTY FAILED. Reputation taken back, so it gets said out loud: this mod's one
-- standing rule about bad news is that the cause has to be on screen, which is why the
-- demand clock announces its own expiry two functions up and why the rank line names the
-- rival in red. Decay is the other half of that rule and is shown on the panel rather than
-- the feed, because it arrives every turn and an interrupt every turn is not information.
--
-- ON THE DEMAND RECORD, not a new one. A feed record is presentation - icon, sound,
-- layout - and the text is the keys passed here; a guild taking reputation back for work
-- not done is the same presentation whether the work was a demand or a bounty.
--
-- ONE KEY SET, not one per guild. The twelve-per-guild sets above exist because a
-- promotion names the rank it reached and there is nowhere in cm:show_message_event to
-- interpolate one. This message names neither guild nor number, so it needs no variants.
function GG.announce_bounty_fail(faction, _guild, _took)
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    for i = 1, #humans do
        if humans[i] == faction then
            local stem = "message_event_text_text_derpy_gg_bounty_fail" .. GG.tag(faction)
            pcall(function()
                cm:show_message_event(faction, stem .. "_title", stem .. "_primary",
                                      -- true, not false: the record is a
                                      -- scripted_persistent_event and the flag has to
                                      -- agree with it or nothing draws.
                                      stem .. "_secondary", true,
                                      GG.feed(faction, GG.FEED_INDEX_DEMAND))
            end)
            return
        end
    end
end

-- 5003, the third and last of this mod's feed indices, minted by the same generator
-- alongside the four rows that resolve it.
GG.FEED_INDEX_LEAD = 5003

-- A GUILD CHANGING HANDS. Called from GG.reassert_leaders the moment the holder moves,
-- which is on some faction's turn start - so loc KEYS only, never a resolved name.
-- That is why there are twelve pairs of keys rather than one pair and a guild name
-- substituted in: cm:show_message_event takes keys and there is nowhere to put a name.
-- --------------------------------------------------------------- the ledger --
-- WHAT EACH GUILD EARNED, AND FROM WHAT: the Guilds tab's "Reputation this turn" line.
-- A finished building pays in script, not through an effect, so this line is the only
-- place a player sees that the forge they built paid the smiths.
--
-- TWO TURNS, this one and the last. A battle fought on an enemy's turn lands after your
-- own turn has ended, so "this turn" alone would never show it.
--
-- KEYED BY TURN NUMBER, not cleared at FactionTurnStart. The order between that event
-- and BuildingCompleted is undocumented, and a clear that ran second would wipe out the
-- building it was meant to show.
--
-- IN THE SAVE AND NOWHERE ELSE, like the log below, so a reload of the turn-start
-- autosave still shows what the turn paid. HUMANS ONLY: the AI opens no panel.
-- Packed as `turn;guild.source=n,...;turn;guild.source=n,...` - this turn, then the one
-- before. "withheld" is what the per-turn cap kept back; every other source was paid.
GG.LEDGER_SOURCES = {"income", "battles", "research", "agents", "buildings",
                     "settlements", "missions", "bounties", "demands", "other",
                     "withheld"}
GG.LEDGER_KNOWN = {}
for i = 1, #GG.LEDGER_SOURCES do GG.LEDGER_KNOWN[GG.LEDGER_SOURCES[i]] = true end

function GG.ledger_read(faction)
    local L = {t1 = -1, now = {}, t0 = -1, last = {}}
    local raw = cm:get_saved_value("derpy_gg_earned_" .. tostring(faction))
    if type(raw) ~= "string" then return L end
    local t1, a, t0, b = string.match(raw, "^(%-?%d+);([^;]*);(%-?%d+);([^;]*)$")
    if not t1 then return L end
    local function parse(s, into)
        for g, src, n in string.gmatch(s, "(%a+)%.(%a+)=(%d+)") do
            into[g] = into[g] or {}
            into[g][src] = tonumber(n)
        end
    end
    L.t1, L.t0 = tonumber(t1), tonumber(t0)
    parse(a, L.now)
    parse(b, L.last)
    return L
end

local function ledger_pack(t)
    local out = {}
    for i = 1, #GG.GUILDS do
        local by = t[GG.GUILDS[i]]
        if by then
            for j = 1, #GG.LEDGER_SOURCES do
                local s = GG.LEDGER_SOURCES[j]
                if by[s] then out[#out + 1] = GG.GUILDS[i] .. "." .. s .. "=" .. by[s] end
            end
        end
    end
    return table.concat(out, ",")
end

function GG.ledger_add(faction, guild, source, amount)
    if not faction or not guild or type(amount) ~= "number" or amount < 1 then return end
    if not GG.is_human(faction) then return end
    local L = GG.ledger_read(faction)
    local now = GG.turn_now()
    if L.t1 ~= now then
        L.t0, L.last, L.t1, L.now = L.t1, L.now, now, {}
    end
    local src = GG.LEDGER_KNOWN[source] and source or "other"
    L.now[guild] = L.now[guild] or {}
    L.now[guild][src] = (L.now[guild][src] or 0) + math.floor(amount)
    cm:set_saved_value("derpy_gg_earned_" .. faction, L.t1 .. ";" .. ledger_pack(L.now)
                       .. ";" .. L.t0 .. ";" .. ledger_pack(L.last))
end

-- {guild = {source = n}} for this turn and for the one before; empty tables when nothing.
function GG.earned(faction)
    local L = GG.ledger_read(faction)
    local t = GG.turn_now()
    local now = (L.t1 == t) and L.now or {}
    local last = (L.t1 == t - 1 and L.now) or (L.t0 == t - 1 and L.last) or {}
    return now, last
end

-- ------------------------------------------------------------------ the log --
-- WHAT THE LOG TAB READS. The panel had a Log tab once and it was replaced by Bounties,
-- because nothing ever wrote a record for it to draw. This is the record.
--
-- ONE SAVED VALUE PER HUMAN FACTION, newest first, capped. Read straight from the save
-- on every draw rather than cached, so there is no session state for a load to lose.
--
-- KEYS AND NUMBERS ONLY. Every writer runs from a turn handler or a click, and a loc call
-- from a turn handler is a CTD - the panel turns these into words at draw time. Entry:
-- `turn,kind,guild,a,b`; entries joined by "|". Keys never contain either separator.
--
--   rank       a = rank before, b = rank after (either direction)
--   buy        a = service key, b = favour paid
--   ai_buy     a = service key, b = the buying faction
--   hit        a = service key, b = the faction that used it on you
--   lead_won   a = the faction it was taken from, or ""
--   lead_lost  a = the faction that took it
GG.LOG_MAX = 100

function GG.log_add(faction, kind, guild, a, b)
    if not faction or not GG.is_human(faction) then return end
    local key = "derpy_gg_log_" .. faction
    local out = {table.concat({tostring(GG.turn_now()), kind, guild or "",
                               tostring(a or ""), tostring(b or "")}, ",")}
    local old = cm:get_saved_value(key)
    if type(old) == "string" then
        for e in string.gmatch(old, "[^|]+") do
            if #out >= GG.LOG_MAX then break end
            out[#out + 1] = e
        end
    end
    cm:set_saved_value(key, table.concat(out, "|"))
end

function GG.log_entries(faction)
    local out = {}
    local s = faction and cm:get_saved_value("derpy_gg_log_" .. faction)
    if type(s) ~= "string" then return out end
    for e in string.gmatch(s, "[^|]+") do
        local t, kind, guild, a, b =
            string.match(e, "^(%d+),([^,]*),([^,]*),([^,]*),([^,]*)$")
        if t then
            out[#out + 1] = {turn = tonumber(t), kind = kind, guild = guild, a = a, b = b}
        end
    end
    return out
end

function GG.announce_lead(guild, who, was)
    -- ONLY WHEN THE PLAYER IS ONE OF THE TWO PARTIES. An AI taking a guild off another
    -- AI is a fact for the Standings tab, not an interrupt over the campaign map - and
    -- with six guilds and a world of rivals it would be several interrupts a round.
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    for i = 1, #humans do
        local me = humans[i]
        local stem = nil
        if who == me then
            stem = "won"
        elseif was == me then
            stem = "lost"
        end
        if stem then
            -- Before the feed call, and whatever guild_notices says: the log is the
            -- record, the popup is only the interrupt.
            GG.log_add(me, "lead_" .. stem, guild,
                       stem == "won" and (was or "") or (who or ""))
            local k = "message_event_text_text_derpy_gg_lead_" .. stem .. "_" .. guild
                      .. GG.tag(me)
            pcall(function()
                cm:show_message_event(me, k .. "_title", k .. "_primary",
                                      k .. "_secondary", true,
                                      GG.feed(me, GG.FEED_INDEX_LEAD))
            end)
        end
    end
end

-- 5004, the fourth feed index and the first that carries good news. Minted by
-- tools/gen_great_guilds.py alongside the four rows that resolve it; check_feed_mirror
-- there pins this number against the one in the DB.
GG.FEED_INDEX_RANK = 5004

-- IS THIS ONE OF OURS, ANSWERED ONCE. cm:get_human_factions is an engine call behind a
-- pcall, and GG.notice_once is reached on EVERY grant for every faction in the world -
-- about 190 of them a round, times every accrual event - so asking the engine each time is
-- the one genuinely hot thing in this path. The human list cannot change during a
-- campaign, so it is cached for the session.
--
-- ONLY A NON-EMPTY ANSWER IS CACHED. A grant that lands before the campaign is fully up
-- would otherwise freeze an empty list in for the rest of the session, and every
-- announcement in this mod would go quiet with nothing to show why.
GG.humans = GG.humans or nil

function GG.is_human(faction)
    if not faction then return false end
    if not GG.humans then
        local ok, humans = pcall(function() return cm:get_human_factions() end)
        if not ok or not humans or #humans == 0 then return false end
        GG.humans = humans
    end
    for i = 1, #GG.humans do
        if GG.humans[i] == faction then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- MULTIPLAYER. A model change made on one machine and not the others is a desync, so
-- nothing the panel does may change the model straight off a click. The click goes
-- through GG.mp_send, which broadcasts with CampaignUI.TriggerCampaignScriptEvent; CA
-- delivers the resulting UITrigger to every machine in one order, and GG.mp_receive
-- applies the same op on all of them. The Zharr Exchange's transport, same shape.
--
-- SINGLE PLAYER RUNS THE SAME OPS, called directly instead of broadcast, so every op is
-- exercised by ordinary play and only the round trip is multiplayer-only.
--
-- EACH OP READS ITS STATE BACK FROM THE SAVE FIRST. The machine that drew the panel has
-- the board, the demand and the patron in memory; after a reload mid-turn the others do
-- not. The save is the one copy every machine agrees on.
--
-- NOT VERIFIED IN A MULTIPLAYER CAMPAIGN - no two-machine run has happened.
GG.MP_TAG = "gg1"
GG.MP_OPS = {}

-- CQI -> HUMAN FACTION. Only a human can send one of these.
function GG.faction_by_cqi(cqi)
    if not cqi then return nil end
    local found = nil
    pcall(function()
        local humans = cm:get_human_factions()
        for i = 1, #humans do
            local f = cm:get_faction(humans[i])
            if f and not f:is_null_interface() and f:command_queue_index() == cqi then
                found = humans[i]
                return
            end
        end
    end)
    return found
end

function GG.mp_send(faction, op, arg)
    if not faction or not GG.MP_OPS[op] then return end
    if not GG.is_mp() then
        GG.MP_OPS[op](faction, arg)
        return
    end
    local cqi = nil
    pcall(function()
        local f = cm:get_faction(faction)
        if f and not f:is_null_interface() then cqi = f:command_queue_index() end
    end)
    -- REFUSE RATHER THAN FALL BACK. A local apply here would change one machine only,
    -- which is the fault this whole section exists to prevent.
    if not cqi then
        GG.trace("no command_queue_index for " .. tostring(faction) .. " - " .. op
                 .. " not sent")
        return
    end
    pcall(function()
        CampaignUI.TriggerCampaignScriptEvent(cqi, GG.MP_TAG .. "|" .. op .. "|"
                                              .. tostring(arg or ""))
    end)
end

-- THE RECEIVING END. Returns the faction it acted for, nil for anything not ours -
-- every other mod's UITrigger comes through the same listener.
function GG.mp_receive(id, cqi)
    if type(id) ~= "string" then return nil end
    if string.sub(id, 1, #GG.MP_TAG + 1) ~= GG.MP_TAG .. "|" then return nil end
    local op, arg = string.match(id, "^" .. GG.MP_TAG .. "|([^|]*)|(.*)$")
    local fn = op and GG.MP_OPS[op]
    if not fn then return nil end
    local faction = GG.faction_by_cqi(cqi)
    if not faction then
        GG.trace("UITrigger " .. tostring(op) .. " from unknown cqi " .. tostring(cqi))
        return nil
    end
    fn(faction, arg)
    return faction
end

-- A TARGET OFF THE WIRE. A slot interface cannot travel in an event string, so a building
-- target travels as its region key and is rebuilt here; research travels as nothing,
-- because every machine holds the same ResearchStarted record.
function GG.target_from_wire(faction, s, t)
    if not s then return nil end
    if s.kind == "research" then return GG.research_target(faction) end
    if type(t) ~= "string" or t == "" then return nil end
    if s.hostile then return t end
    if s.kind == "building" then return GG.upgrade_target(faction, t) end
    if s.kind == "unit" then return tonumber(t) end
    return t
end

-- "service_key|target"
GG.MP_OPS.buy = function(faction, arg)
    local key, t = string.match(arg or "", "^([^|]*)|?(.*)$")
    local s = GG.service(key)
    if not s then return end
    GG.load(faction)
    GG.load_research(faction)
    GG.buy(faction, key, GG.target_from_wire(faction, s, t))
    GG.save(faction)
end

-- "i/n|v|v|..." - one part of the host's settings. Every machine freezes them once the
-- last part is in; a campaign that already has settings keeps them.
GG.MP_OPS.tune = function(_faction, arg)
    local existing = cm:get_saved_value("derpy_gg_tuned")
    if existing and existing ~= "" then return end
    local i, n, body = string.match(arg or "", "^(%d+)/(%d+)|(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not i or not n or i < 1 or i > n then return end
    GG.tune_parts[i] = body
    for k = 1, n do
        if not GG.tune_parts[k] then return end
    end
    local parts = {}
    for k = 1, n do parts[k] = GG.tune_parts[k] end
    GG.tune_parts = {}
    GG.TUNE = GG.unpack_tune(table.concat(parts, "|"))
    cm:set_saved_value("derpy_gg_tuned", GG.pack_tune(GG.TUNE))
    GG.trace("froze the host's settings for this campaign")
end

-- The board index the card showed, which GG.bounty_view keeps equal to the list's.
GG.MP_OPS.bounty = function(faction, arg)
    local n = tonumber(arg)
    if not n then return end
    GG.load_bounties(faction)
    if GG.take_bounty(faction, n) then GG.save_bounties(faction) end
end

GG.MP_OPS.demand = function(faction)
    GG.load(faction)
    GG.load_demand(faction)
    if GG.pay_demand(faction) then
        GG.save_demand(faction)
        GG.save(faction)
    end
end

-- "guild|character cqi". The sitting guild's button dismisses, any other appoints -
-- decided here, on every machine, from the saved post.
GG.MP_OPS.patron = function(faction, arg)
    local guild, cqi = string.match(arg or "", "^([^|]*)|?(.*)$")
    if not GG.is_guild(guild) then return end
    GG.load(faction)
    GG.load_patron(faction)
    local p = GG.patrons[faction]
    if p and p.guild == guild then
        GG.clear_patron(faction)
    else
        GG.set_patron(faction, guild, tonumber(cqi))
    end
    GG.save_patron(faction)
end

-- A PROMOTION. Called from GG.grant, which runs from six different turn handlers for
-- every faction in the world - so loc KEYS only, never a resolved name, and the cheap
-- tests come first.
--
-- 72 key sets rather than one generic pair: cm:show_message_event takes keys and there is
-- nowhere to interpolate the guild or the rank into one. The same reason announce_lead
-- above ships 36.
function GG.announce_rank(faction, guild, old_rank, new_rank)
    -- FIRST, AND IN THIS ORDER. GG.grant is the hottest function in the mod - every
    -- accrual route on every faction passes through it - and the overwhelming majority of
    -- calls cross no threshold at all. Nothing below this line runs on those.
    if not new_rank or not old_rank then return end
    if new_rank <= old_rank then return end
    -- RANK 1 IS UNMARKED, where every faction already starts - announcing it would fire
    -- six times on the first turn of every campaign. GG.RANKS is {0, 100, 300, 700, 1500}
    -- and GG.rank_of returns 1..5, which is why this reads 2 and not 1; GG.bundle_key uses
    -- the same boundary. Demotions fall out at the line above: rivalry and an expired
    -- demand both take reputation back, and this mod already has three records' worth of
    -- bad news.
    if new_rank < 2 then return end
    if not GG.is_guild(guild) then return end
    if GG.setting then
        local v = GG.setting("guild_notices")
        if v ~= nil and not v then return end
    end
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    for i = 1, #humans do
        if humans[i] == faction then
            -- ONLY THE FIRST TIME THIS RANK IS REACHED. Upkeep demotes a guild the player
            -- stops feeding, so a faction hovering at a threshold crosses it again and
            -- again; each crossing popped the same promotion (Azeros, turns 31 and 33,
            -- 2026-09-23). The bundle swap and the Log still record every crossing. Humans
            -- only, so the AI writes no key.
            local best_key = "derpy_gg_best_" .. guild .. "_" .. faction
            if new_rank <= (tonumber(cm:get_saved_value(best_key)) or 0) then return end
            cm:set_saved_value(best_key, new_rank)
            local k = "message_event_text_text_derpy_gg_rank_"
                      .. guild .. "_" .. new_rank .. GG.tag(faction)
            pcall(function()
                cm:show_message_event(faction, k .. "_title", k .. "_primary",
                                      -- true, not false: the record is a
                                      -- scripted_persistent_event and the flag has to
                                      -- agree with it or nothing draws.
                                      k .. "_secondary", true,
                                      GG.feed(faction, GG.FEED_INDEX_RANK))
            end)
            return
        end
    end
end

-- A ONE-TIME NOTICE, on the same feed record as a promotion: both are good news, and a
-- record is presentation - icon, sound, layout - while the text is the keys passed here.
--
-- THE FLAG LIVES IN THE SAVE. A flag held only in memory fires the message again on every
-- load, and a player loads far more often than they first meet a guild. cm:set_saved_value
-- is the same mechanism GG.save_patron and GG.save_demand already use.
--
-- Returns true only when it actually fired, so a caller can tell "already seen" from
-- "not eligible" and a test can read it without a UI.
function GG.notice_once(faction, tag, guild)
    if not faction or not tag or not GG.is_guild(guild) then return false end
    if GG.setting then
        local v = GG.setting("guild_notices")
        if v ~= nil and not v then return false end
    end
    -- THE SAVED FLAG FIRST. It is a table lookup and it is false exactly once per campaign
    -- per tag, so on every call after the first this returns before touching anything else.
    local flag = "derpy_gg_notice_" .. tag .. "_" .. faction
    if cm:get_saved_value(flag) == "1" then return false end
    if not GG.is_human(faction) then return false end
    cm:set_saved_value(flag, "1")
    -- `tag` is this notice's own "first"/"half"; GG.tag is the reader's flavour.
    local k = "message_event_text_text_derpy_gg_notice_" .. tag .. "_" .. guild
              .. GG.tag(faction)
    pcall(function()
        cm:show_message_event(faction, k .. "_title", k .. "_primary",
                              k .. "_secondary", true,
                              GG.feed(faction, GG.FEED_INDEX_RANK))
    end)
    return true
end

function GG.was_outnumbered(context)
    local ok, outnumbered = pcall(function()
        local pb = context:pending_battle()
        if not pb or pb:is_null_interface() then return false end
        local me = context:character():command_queue_index()

        local attacking = false
        if pb:has_attacker() then
            local a = pb:attacker()
            if a and not a:is_null_interface()
                    and a:command_queue_index() == me then
                attacking = true
            end
        end
        if not attacking then
            local sec = pb:secondary_attackers()
            if sec then
                for i = 0, sec:num_items() - 1 do
                    local c = sec:item_at(i)
                    if c and not c:is_null_interface()
                            and c:command_queue_index() == me then
                        attacking = true
                        break
                    end
                end
            end
        end

        local stronger = pb:attacker_is_stronger()
        if attacking then return stronger ~= true end
        return stronger == true
    end)
    if not ok then return false end
    return outnumbered == true
end

function GG.battle_award(winner, outnumbered)
    if not winner then return end
    GG.load(winner)
    GG.on_battle(winner, outnumbered)
    GG.save(winner)
end

-- EVERY HUMAN'S BOARD, AT THE FIRST TICK. It is posted at the human's turn start, so a
-- campaign that adds the mod mid-turn has none until the next one. It used to be posted
-- when the panel was drawn, which runs on one machine - a desync in multiplayer. The
-- first tick runs on every machine, in the same order.
function GG.first_boards()
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    for i = 1, #humans do
        local h = humans[i]
        GG.load_bounties(h)
        if #(GG.bounties[h] or {}) == 0 then
            GG.post_bounties(h)
            GG.save_bounties(h)
        end
    end
end

-- THE SETTINGS FIRST, so turn 1 and the first boards play on them rather than on the
-- defaults. MCT has loaded the player's values by now (its LoadingGame runs earlier).
cm:add_first_tick_callback(function()
    GG.snapshot_settings()
    GG.load_all()
    GG.register()
    GG.send_tune()
    GG.first_boards()
end)

function GG.load(faction)
    local packed = cm:get_saved_value("derpy_gg_" .. faction)
    if not packed or packed == "" then return end
    local body, cdpart = string.match(packed, "^([^;]*);?(.*)$")
    local f, i = blank(), 1
    for chunk in string.gmatch(body or "", "[^|]+") do
        local rep, fav = string.match(chunk, "(%-?%d+),(%-?%d+)")
        local key = GG.GUILDS[i]
        if key and rep then f[key] = {rep = tonumber(rep), fav = tonumber(fav)} end
        i = i + 1
    end
    GG.state[faction] = f
    if cdpart and cdpart ~= "" then
        local j = 1
        GG.cooldowns[faction] = {}
        for chunk in string.gmatch(cdpart, "[^|]+") do
            local s = GG.SERVICES[j]
            if s then GG.cooldowns[faction][s.key] = tonumber(chunk) or 0 end
            j = j + 1
        end
    end
end

-- EVERY FACTION'S STANDING, ONCE, AT THE FIRST TICK.
--
-- GG.state is session memory and a load starts it empty. It was refilled lazily and
-- only lazily: GG.load at a faction's OWN FactionTurnStart, and GGAI.run_turn once a
-- round for the AI half. Neither has happened when a save is loaded mid-turn, which is
-- every save a player makes - so for the rest of that turn GG.state was `{}`.
-- GG.standings reads GG.state, which made every guild's table empty and GG.leader_of
-- name nobody: "the rankings reset and no guild has a leader", reported from a live
-- campaign on 2026-09-16.
--
-- It is worse than a blank panel. GG.reassert_leaders runs at the next faction turn
-- start against whatever fraction of the world has reloaded by then, so the crown lands
-- on the first faction to take its turn and walks down the table as the round refills
-- it - moving a permanent bundle and a service monopoly each time.
--
-- Every OTHER record already had a restore path outside the turn handler: bounties, the
-- demand, the patron, the research subject and the world record are all re-read when the
-- panel opens. The standings, the one record this mod is about, were the only ones that
-- were not.
--
-- AT THE TICK, NOT INSIDE GG.standings. Standings is a draw-time read that runs once per
-- guild per refresh; a saved-value read per faction per row is the same work several
-- hundred times over on every panel open. GG.scan_world is the walk the mod already does
-- and caches, so this costs one get_saved_value per present faction, once a session.
function GG.load_all()
    for _, list in pairs(GG.scan_world()) do
        for i = 1, #list do GG.load(list[i]) end
    end
end
