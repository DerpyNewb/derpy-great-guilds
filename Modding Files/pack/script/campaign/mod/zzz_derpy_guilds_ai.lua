-- The Great Guilds - AI.
--
-- Accrual is SHARED with the player and lives in zzz_derpy_guilds.lua: the six
-- listeners there run for every faction, so AI factions already hold standing
-- before this file does anything. This file only spends it.
--
-- No loc call anywhere in here. Everything below runs from a turn handler.

GGAI = GGAI or {}

-- ALL EIGHTEEN. Three were cut until 2026-09-24 because each needed a target the AI had
-- no way to pick; GGAI.pick_target has one for every kind now.

-- One purchase per faction per turn. A hard cap, not a tuning value.
GGAI.bought_this_turn = GGAI.bought_this_turn or {}

-- Test seams. The harness sets these; in game they stay nil and the real
-- interfaces are read instead.
GGAI.TEST_FORCES = nil
GGAI.TEST_WARS = nil
GGAI.TEST_REGIONS = nil          -- the buyer's own region keys
GGAI.TEST_ENEMY_REGIONS = nil    -- [enemy faction] = {region key, ...}

function GGAI.reset_turn()
    GGAI.bought_this_turn = {}
end

-- THE LAST SERVICE THIS FACTION BOUGHT, kept in the save rather than the session: every
-- machine in a multiplayer game runs this sweep, and a value one of them lost on a reload
-- is a different purchase on each.
function GGAI.last_bought(faction)
    local k = cm:get_saved_value("derpy_gg_ai_last_" .. faction)
    if type(k) == "string" and k ~= "" then return k end
    return nil
end

-- RETURNS THE KEY AND ITS TARGET. A service that needs a target is a candidate only once
-- it has one: choosing it blind spent the faction's one purchase of the turn on a sale
-- GG.buy then refused.
function GGAI.choose(faction)
    local cands = {}
    for i = 1, #GG.SERVICES do
        local s = GG.SERVICES[i]
        if GG.can_buy(faction, s.key) then
            local target = nil
            if GG.needs_target(s) then target = GGAI.pick_target(faction, s) end
            if target ~= nil or not GG.needs_target(s) then
                cands[#cands + 1] = {s = s, target = target}
            end
        end
    end
    -- NEVER THE SAME SERVICE TWICE IN A ROW while anything else is affordable. A faction
    -- whose only open guild sells one service bought it every time its cooldown ran out
    -- and nothing else - the Daemonsmiths below rank 4 sell only the Forge-Rite.
    local last = GGAI.last_bought(faction)
    if last and #cands > 1 then
        local rest = {}
        for i = 1, #cands do
            if cands[i].s.key ~= last then rest[#rest + 1] = cands[i] end
        end
        if #rest > 0 then cands = rest end
    end
    local pool = {}
    for i = 1, #cands do
        -- Weight by cost, so a faction that can afford a tier-3 service
        -- usually takes it rather than dribbling on tier-1s.
        for _ = 1, math.floor(cands[i].s.cost / 50) do pool[#pool + 1] = cands[i] end
    end
    if #pool == 0 then return nil end
    local c = pool[GGAI.roll(#pool)]
    return c.s.key, c.target
end

-- cm:random_number is the multiplayer-safe roll. A plain math.random would
-- diverge between machines.
function GGAI.roll(n)
    if n <= 1 then return 1 end
    local ok, v = pcall(function() return cm:random_number(n) end)
    if ok and v and v >= 1 and v <= n then return v end
    return 1
end

-- RETURNS TRUE ON A PURCHASE, so run_turn can count them for the panel's activity
-- line. Nothing else reads the return.
function GGAI.step(faction)
    if GGAI.bought_this_turn[faction] then return false end
    local key, target = GGAI.choose(faction)
    if not key then return false end
    local s = GG.service(key)
    if not s then return false end
    if target == nil then target = GGAI.pick_target(faction, s) end
    -- A targeted service with no target is skipped, never fired blind.
    --
    -- GG.needs_target, NOT a copy of the rule. This line used to read
    -- `(s.kind == "unit") or s.hostile`, which was the same incomplete list that let
    -- four services take the player's favour and deliver nothing - a third copy of a
    -- rule that had already been wrong in two places.
    if GG.needs_target(s) and not target then return false end
    if GG.buy(faction, key, target) then
        GGAI.bought_this_turn[faction] = true
        cm:set_saved_value("derpy_gg_ai_last_" .. faction, key)
        GG.save(faction)
        GGAI.report(faction, s, target)
        GGAI.log_purchase(faction, s, target)
        return true
    end
    return false
end

-- ---------------------------------------------------------------- pickers ---

-- `s`, when given, is the service the army is for: the pick is the first army the till
-- would accept for it, not the first army. The first one used to be the pick whatever it
-- held, so a rival whose first army was full never hired again (2026-09-29).
function GGAI.pick_army(faction, s)
    -- military_force_list COUNTS GARRISONS, so this filter is not optional:
    -- without it the hired regiment can land in a city garrison instead of a
    -- field army. is_armed_citizenry and command_queue_index both confirmed
    -- present in CA's scripting_doc, 2026-09-10.
    local list = GGAI.TEST_FORCES
    if not list then
        local ok, f = pcall(function() return cm:get_faction(faction) end)
        if not ok or not f then return nil end
        if f.is_null_interface and f:is_null_interface() then return nil end
        local ok2, mfl = pcall(function() return f:military_force_list() end)
        if not ok2 or not mfl then return nil end
        list = {}
        local ok3 = pcall(function()
            for i = 0, mfl:num_items() - 1 do
                local mf = mfl:item_at(i)
                list[#list + 1] = {armed_citizenry = mf:is_armed_citizenry(),
                                   cqi = mf:general_character():command_queue_index()}
            end
        end)
        if not ok3 then return nil end
    end
    for i = 1, #list do
        if not list[i].armed_citizenry
           and (s == nil or GG.target_ok(faction, s, list[i].cqi)) then
            return list[i].cqi
        end
    end
    return nil
end

-- A LIVING ENEMY, NEVER "rebels": CA's own crisis script filters both out of this same
-- list (wh3_crisis_scenarios.lua:399-408), and The Khan's Price was spent on them for
-- nothing. With `need_regions`, only an enemy holding a region (logic audit, 2026-09-29).
function GGAI.pick_enemy(faction, need_regions)
    local wars = GGAI.TEST_WARS
    if not wars then
        wars = {}
        local ok, f = pcall(function() return cm:get_faction(faction) end)
        if not ok or not f then return nil end
        if f.is_null_interface and f:is_null_interface() then return nil end
        pcall(function()
            local fl = f:factions_at_war_with()
            for i = 0, fl:num_items() - 1 do
                local e = fl:item_at(i)
                pcall(function()
                    if e:is_dead() or e:name() == "rebels" then return end
                    if need_regions and e:region_list():num_items() == 0 then return end
                    wars[#wars + 1] = e:name()
                end)
            end
        end)
    end
    if #wars == 0 then return nil end
    return wars[GGAI.roll(#wars)]
end

-- A REGION OF A FACTION AT WAR WITH THE BUYER, for Hobgoblin Eyes: the one thing an AI
-- wants to see through the shroud is where its enemy is.
function GGAI.pick_enemy_region(faction)
    local enemy = GGAI.pick_enemy(faction, true)
    if not enemy then return nil end
    local keys = GGAI.TEST_ENEMY_REGIONS and GGAI.TEST_ENEMY_REGIONS[enemy]
    if not keys then
        keys = {}
        pcall(function()
            local f = cm:get_faction(enemy)
            if not f or f:is_null_interface() then return end
            local rl = f:region_list()
            for i = 0, rl:num_items() - 1 do keys[#keys + 1] = rl:item_at(i):name() end
        end)
    end
    if #keys == 0 then return nil end
    return keys[GGAI.roll(#keys)]
end

-- WHAT THE AI IS RESEARCHING, for Bound Blueprint - read back from the save, because
-- GG.researching starts empty on a load and only the player's turn start refills it.
function GGAI.pick_research(faction)
    GG.load_research(faction)
    return GG.research_target(faction)
end

-- THE AI'S OWN REGION KEYS, for the two services that take one of its settlements.
function GGAI.own_regions(faction)
    if GGAI.TEST_REGIONS then return GGAI.TEST_REGIONS end
    local keys = {}
    pcall(function()
        local f = cm:get_faction(faction)
        if not f or f:is_null_interface() then return end
        local rl = f:region_list()
        for i = 0, rl:num_items() - 1 do keys[#keys + 1] = rl:item_at(i):name() end
    end)
    return keys
end

-- THE FIRST UPGRADE IN ANY OF THE AI'S OWN REGIONS, for Raise the Ziggurat, through the
-- same GG.upgrade_target the panel uses.
function GGAI.pick_building(faction)
    local keys = GGAI.own_regions(faction)
    for i = 1, #keys do
        local t = GG.upgrade_target(faction, keys[i])
        if t then return t end
    end
    return nil
end

-- ONE OF THE AI'S OWN REGIONS, rolled, for a settlement service.
function GGAI.pick_own_region(faction)
    local keys = GGAI.own_regions(faction)
    if #keys == 0 then return nil end
    return keys[GGAI.roll(#keys)]
end

function GGAI.pick_target(faction, s)
    if not s then return nil end
    if GG.CHAR_KINDS[s.kind] then
        return GGAI.pick_army(faction, s)
    end
    if s.kind == "settlement" then return GGAI.pick_own_region(faction) end
    if s.kind == "enemy_settlement" then return GGAI.pick_enemy_region(faction) end
    if s.hostile then return GGAI.pick_enemy(faction) end
    if s.kind == "shroud" then return GGAI.pick_enemy_region(faction) end
    if s.kind == "research" then return GGAI.pick_research(faction) end
    if s.kind == "building" then return GGAI.pick_building(faction) end
    return nil
end

-- ------------------------------------------------------------------ court ---
-- The two tools the player has on the Court tab. An AI faction faces the same demands
-- and appoints the same patron, because the alternative is a leadership race the player
-- cannot lose: paying a demand is a net reputation GAIN (the reward is twice the
-- penalty) and a patron is +50% on one guild, and neither was available to a rival.

-- WHICH GUILD AN AI SERVES: the one it already has the most reputation with. A patron
-- multiplies what that guild pays, so putting it anywhere else is a worse play - and
-- ties break on GG.GUILDS order rather than on pairs(), which is not stable between
-- runs and would move the post every turn for no reason.
function GGAI.best_guild(faction)
    local best, best_rep = nil, 0
    for i = 1, #GG.GUILDS do
        local g = GG.GUILDS[i]
        local rep = select(1, GG.get(faction, g))
        if rep > best_rep then best, best_rep = g, rep end
    end
    return best
end

-- RETURNS TRUE WHEN IT PAID A DEMAND, for the same reason GGAI.step does.
function GGAI.court_step(faction, turn)
    -- A faction no guild has ever paid has nothing to be demanded of and nothing worth
    -- patronising. This is also what keeps the whole block off the other ~190 factions
    -- in the world: GG.load leaves GG.state[faction] nil for anyone who never earned,
    -- so nothing below writes a saved value for them.
    if not GG.state[faction] then return false end
    -- COVERED RIVALS ONLY, as the till and the bounty pass already are: rows an older
    -- build left for another race were given a demand and a patron every round and
    -- climbed for ever (logic audit, 2026-09-29).
    if not GG.covered(faction) then return false end

    -- THE DEMAND. Paid whenever it can be paid, which is the same offer the player's
    -- button makes and the correct play besides - demand_reward is twice
    -- demand_penalty, so refusing an affordable demand is never better. When it cannot
    -- be paid the deadline runs out and the standing falls, exactly as it would for a
    -- player who let it.
    GG.load_demand(faction)
    GG.demand_tick(faction, turn)
    local paid = false
    if GG.demands[faction] and GG.demand_payable(faction) then
        paid = GG.pay_demand(faction) and true or false
    end
    GG.save_demand(faction)
    -- SAVED HERE. Both halves of a demand move reputation - the reward on paying, the
    -- penalty on expiry - and GGAI.step only saves when it buys something, so without
    -- this the whole demand is applied to the live table and thrown away on the next
    -- load. The same trap the player's path hit, one file over.
    GG.save(faction)

    -- THE PATRON. Filled when the post is vacant and never moved once filled: ranks
    -- move every turn, and a post that chased the top guild would take its bundle off
    -- one army and put it on another indefinitely. GG.assert_patron vacates the post
    -- when the lord dies or loses their army, and the next turn fills it again.
    GG.load_patron(faction)
    GG.assert_patron(faction)
    if not GG.patrons[faction] then
        local guild = GGAI.best_guild(faction)
        -- pick_army returns a CHARACTER cqi, which is what set_patron wants, and nil
        -- for a faction with no field army - which set_patron refuses rather than
        -- filling the post with nobody.
        if guild then GG.set_patron(faction, guild, GGAI.pick_army(faction)) end
    end
    GG.save_patron(faction)
    return paid
end

-- ---------------------------------------------------------------- reports ---

-- The index into event_feed_message_events. A WRONG INDEX DRAWS NOTHING - no
-- error, no feed entry, just a log line saying it showed one.
--
-- 5001 is minted by tools/gen_great_guilds.py, which also ships the four rows the
-- index resolves through (campaign_groups, campaign_group_members,
-- campaign_group_member_criteria_values, event_feed_message_events) and refuses
-- to build if 5001 ever collides with a vanilla index. Vanilla runs -1..1960.
--
-- `persistent` in the call below is true, which must agree with the DB row's
-- event column: scripted_persistent_event. It does.
GG = GG or {}
GG.FEED_INDEX = 5001

-- WHO A SERVICE LANDED ON: the faction a hostile one names, or the owner of the region an
-- enemy-settlement one struck, read at the purchase (final review, 2026-09-29). Nil for a
-- service that lands on the buyer.
function GGAI.victim(s, target)
    if not s or not target then return nil end
    if s.hostile then return target end
    if s.kind ~= "enemy_settlement" then return nil end
    local ok, owner = pcall(function()
        local r = cm:get_region(target)
        if not r or r:is_null_interface() then return nil end
        local o = r:owning_faction()
        if not o or o:is_null_interface() then return nil end
        return o:name()
    end)
    if ok then return owner end
    return nil
end

function GGAI.report(faction, s, target)
    -- Only a service that landed on a HUMAN is announced. An AI buffing itself
    -- is Log content, not a feed interrupt.
    target = GGAI.victim(s, target)
    if not target then return end
    if not GG.FEED_INDEX then return end
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    for i = 1, #humans do
        if humans[i] == target then
            -- IN THE RECEIVER'S WORDS: the target is who reads it.
            local k = "message_event_text_text_derpy_gg_hit" .. GG.tag(target)
            pcall(function()
                cm:show_message_event(target, k .. "_title", k .. "_primary",
                                      k .. "_secondary", true,
                                      GG.feed(target, GG.FEED_INDEX))
            end)
            return
        end
    end
end

-- WHAT THE PLAYER'S LOG TAB SAYS ABOUT IT. Every human of the buyer's culture hears of
-- the purchase - the Standings league is per culture, so those are the rivals it is
-- about. A hostile service that landed on that human is a HIT instead: one line, not two
-- lines saying the same thing. Keys only; the panel names them at draw time.
function GGAI.log_purchase(faction, s, target)
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans or not s then return end
    local theirs = GG.culture_of(faction)
    local victim = GGAI.victim(s, target)
    for i = 1, #humans do
        local h = humans[i]
        if victim == h then
            GG.log_add(h, "hit", s.guild, s.key, faction)
        elseif theirs and GG.culture_of(h) == theirs then
            GG.log_add(h, "ai_buy", s.guild, s.key, faction)
        end
    end
end

-- --------------------------------------------------------------- bounties ---
-- RIVALS TAKE BOUNTIES (docs/superpowers/specs/2026-09-29-great-guilds-ai-bounties-design.md).
-- One at a time, scored by this file rather than by an engine mission: nothing measured
-- says the engine tracks objectives for an AI faction, and CA's contracts go to humans only.
--
-- KEPT OUT OF GG.bounties. GG.drop_bounty_target, GG.hero_progress and GG.void_bounty walk
-- every list in there and call the mission functions on what they find; a rival's bounty
-- has no mission behind it.

GGAI.bounty = GGAI.bounty or {}          -- [faction] = one taken offer
GGAI.by_target = GGAI.by_target or {}    -- [map target] = the rival holding it
GGAI.indexed = false                     -- by_target built this session?
-- No script call counts battle captives, so Fill the Pens could never be scored. Harry
-- and sabotage need two hits on one named target from heroes nobody aims, which is close
-- to never (final review, 2026-09-29). A strike needs only the target's death.
GGAI.SKIP_KINDS = {job_captives = true, hero_harry = true, hero_sabotage = true}

-- THE WARNING'S RECORD: scripted_transient_located_event, so it lands in the feed strip
-- with a zoom button. persistent must be false to agree with it (gen_great_guilds.py).
GG.FEED_INDEX_HUNTED = 5005

function GGAI.bounty_key(faction) return "derpy_gg_ai_bounty_" .. faction end

-- A target on the map, which is what the one-rival-per-target rule and the death lookup
-- index. A job's "target" is its kind key or a tech, and two rivals may share those.
function GGAI.on_map(o)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    return k ~= nil and (k.target == "region" or k.target == "lord"
                         or k.target == "character")
end

function GGAI.load_bounty(faction)
    local s = cm:get_saved_value(GGAI.bounty_key(faction))
    local o = nil
    if type(s) == "string" and s ~= "" then o = GG.unpack_offer(s) end
    GGAI.bounty[faction] = o
    if o and GGAI.on_map(o) then GGAI.by_target[o.target] = faction end
    return o
end

function GGAI.save_bounty(faction)
    local o = GGAI.bounty[faction]
    cm:set_saved_value(GGAI.bounty_key(faction), o and GG.pack_offer(o) or "")
end

function GGAI.clear_bounty(faction)
    local o = GGAI.bounty[faction]
    if o and GGAI.by_target[o.target] == faction then GGAI.by_target[o.target] = nil end
    GGAI.bounty[faction] = nil
    GGAI.save_bounty(faction)
end

-- Every held target, loaded fresh. names nil walks the world: the listeners' first use in
-- a session, so a lord killed between a load and the first sweep still counts.
function GGAI.index(names)
    GGAI.by_target = {}
    if not names then
        names = {}
        pcall(function()
            local fl = cm:model():world():faction_list()
            for i = 0, fl:num_items() - 1 do
                local f = fl:item_at(i)
                if not f:is_null_interface() and not f:is_human() and not f:is_dead() then
                    names[#names + 1] = f:name()
                end
            end
        end)
    end
    for i = 1, #names do GGAI.load_bounty(names[i]) end
    GGAI.indexed = true
end

function GGAI.holder_of(target)
    if not GGAI.indexed then GGAI.index(nil) end
    return GGAI.by_target[target]
end

-- One guild's offer for a rival: its kinds bar the unscorable ones, from a rolled start,
-- the first that names something the rival can stake.
-- NO WALK FOR A GUILD IT CANNOT PAY (final review, 2026-09-29). Every rival offer asks at
-- least the stake of the base price - never a new war, and difficulty only adds - and
-- GGAI.step has just spent favour, so a broke rival is the common case.
function GGAI.offer(faction, guild, turn)
    local _, fav = GG.get(faction, guild)
    if (fav or 0) < GG.bounty_stake(GG.bounty_pay()) then return nil end
    local kinds, all = {}, GG.guild_kinds(guild)
    for i = 1, #all do
        if not GGAI.SKIP_KINDS[all[i]] then kinds[#kinds + 1] = all[i] end
    end
    local n = #kinds
    if n == 0 then return nil end
    local start = GG.roll(n)
    for step = 0, n - 1 do
        local o = GG.make_offer(faction, guild, kinds[((start + step - 1) % n) + 1], turn,
                                GGAI.by_target, true)
        if o and GG.stake_affordable(faction, o) then return o end
    end
    return nil
end

-- posted IS THE TURN TAKEN: a rival takes at the moment of posting, so the player
-- board's own field carries the 20-turn clock and no new field is needed.
function GGAI.take_bounty(faction, turn)
    local n = #GG.GUILDS
    local start = GG.roll(n)
    for step = 0, n - 1 do
        local guild = GG.GUILDS[((start + step - 1) % n) + 1]
        local o = GGAI.offer(faction, guild, turn)
        if o and GG.spend(faction, guild, o.stake or 0) then
            local k = GG.BOUNTY_KINDS[o.kind]
            -- Fill the Coffers is fixed at the take, as the player's is.
            if k.pick == "coffers" then
                pcall(function()
                    o.amount = cm:get_faction(faction):treasury() + (o.amount or 0)
                end)
            end
            o.taken = true
            GGAI.bounty[faction] = o
            if GGAI.on_map(o) then GGAI.by_target[o.target] = faction end
            GGAI.save_bounty(faction)
            GG.save(faction)
            GGAI.warn(faction, o)
            return o
        end
    end
    return nil
end

-- A PRICE ON A HUMAN'S HOLDINGS. The Log names who and what; the feed line cannot, since
-- feed strings are fixed text, so it zooms to the target instead.
function GGAI.warn(faction, o)
    local owner = o.owner
    if not owner or owner == "" or not GG.is_human(owner) then return end
    GG.log_add(owner, "hunted", o.guild, o.target, faction)
    local x, y = GG.target_pos(o)
    if not x then return end
    local k = "message_event_text_text_derpy_gg_hunted" .. GG.tag(owner)
    pcall(function()
        cm:show_message_event_located(owner, k .. "_title", k .. "_primary",
                                      k .. "_secondary", x, y, false,
                                      GG.feed(owner, GG.FEED_INDEX_HUNTED))
    end)
end

-- DONE WHEN, read off the world. Sack, kill and hero work are marked by the listeners
-- instead (o.done), because only an event can say who did it.
GGAI.DONE = {
    region_take = function(f, o)
        return cm:get_region(o.target):owning_faction():name() == f
    end,
    job_coffers = function(f, o) return cm:get_faction(f):treasury() >= (o.amount or 0) end,
    job_champion = function(f, o) return GG.highest_rank(f) >= (o.amount or 0) end,
    job_research = function(f, o) return cm:get_faction(f):has_technology(o.target) == true end,
    job_build = function(f, o) return GG.player_has_building(f, o.target) end,
}

-- How many marks finish it: hero work counts to its number, everything else to one.
function GGAI.need(o)
    local k = GG.BOUNTY_KINDS[o.kind]
    if k and k.shape then return math.max(o.amount or 1, 1) end
    return 1
end

-- A READ THAT THROWS IS NOT DONE. Nothing is paid on a question mark.
function GGAI.is_done(faction, o)
    if (o.done or 0) >= GGAI.need(o) then return true end
    local test = GGAI.DONE[o.kind]
    if not test then return false end
    local ok, yes = pcall(test, faction, o)
    return ok and yes == true
end

-- Done, then voided, then failed: a bounty finished on its last turn is paid. Returns
-- true and how when it ended the bounty, so the sweep leaves the next take to the next
-- round.
-- Cleared BEFORE the payout, as GG.bounty_done clears the player's: a grant can rank the
-- rival up and nothing may find the bounty still standing while it does.
function GGAI.settle_bounty(faction, turn)
    local o = GGAI.bounty[faction]
    if not o then return false end
    local k = GG.BOUNTY_KINDS[o.kind]
    if GGAI.is_done(faction, o) then
        GGAI.clear_bounty(faction)
        GG.refund(faction, o.guild, o.stake)
        GG.grant(faction, o.guild, o.rep, "bounties")
        if (o.gold or 0) > 0 then
            pcall(function() cm:treasury_mod(faction, o.gold) end)
        end
        GG.save(faction)
        GGAI.tell(faction, o, "hunt_done")
        return true, "hunt_done"
    end
    -- A STRIKE IS NEVER VOIDED: its target dying completes it, as the player's does.
    if k and k.shape and k.shape ~= "strike" and not GG.hero_target_alive(faction, o) then
        GGAI.clear_bounty(faction)
        GG.refund(faction, o.guild, o.stake)
        GG.save(faction)
        GGAI.tell(faction, o, "hunt_void")
        return true, "hunt_void"
    end
    if turn - (o.posted or turn) >= GG.BOUNTY_TURN_LIMIT then
        GGAI.clear_bounty(faction)
        GG.penalise(faction, o.guild, GG.bounty_fail_cost(o, faction))
        GG.save(faction)
        GGAI.tell(faction, o, "hunt_failed")
        return true, "hunt_failed"
    end
    return false
end

-- WHO HEARS HOW IT ENDED. The hunted human, by the kind; every other human of the
-- rival's race, when it was paid - the race is per culture (as GGAI.log_purchase).
function GGAI.tell(faction, o, kind)
    if o.owner ~= "" and GG.is_human(o.owner) then
        GG.log_add(o.owner, kind, o.guild, o.target, faction)
    end
    if kind ~= "hunt_done" then return end
    local ok, humans = pcall(function() return cm:get_human_factions() end)
    if not ok or not humans then return end
    local theirs = GG.culture_of(faction)
    for i = 1, #humans do
        local h = humans[i]
        if h ~= o.owner and theirs and GG.culture_of(h) == theirs then
            GG.log_add(h, "ai_bounty", o.guild, o.rep or 0, faction)
        end
    end
end

-- ------------------------------------------------ bounty marks, from listeners ---

function GGAI.on_sack(faction, region)
    if not region then return false end
    local o = GGAI.load_bounty(faction)
    if not o or o.kind ~= "region_sack" or o.target ~= region then return false end
    o.done = GGAI.need(o)
    GGAI.save_bounty(faction)
    return true
end

-- WHETHER THE ENGINE RAISES AGENT ACTIONS FOR AI FACTIONS is unmeasured (CA's followers
-- script filters them with is_human(), which suggests it does), so the first one seen is
-- said once a session. No line in a log that has an AI turn in it means it does not.
function GGAI.hero_progress(faction, action_key, target, won)
    if not GGAI.agent_seen and not GG.is_human(faction) then
        GGAI.agent_seen = true
        GG.trace("agent action reached AI faction " .. tostring(faction)
                 .. " - rivals' hero bounties can count")
    end
    if not won or target == nil then return false end
    local o = GGAI.load_bounty(faction)
    local k = o and GG.BOUNTY_KINDS[o.kind]
    if not (k and k.shape and o.target == tostring(target)
            and GG.hero_action_matches(k.shape, action_key)) then
        return false
    end
    o.done = (o.done or 0) + 1
    GGAI.save_bounty(faction)
    return true
end

-- CharacterDestroyed does not say who killed, so this finds the holder by target. A kill
-- or a strike counts whoever did it, as the player's KILL_CHARACTER_BY_ANY_MEANS does.
function GGAI.on_character_destroyed(cqi)
    local key = tostring(cqi)
    local holder = GGAI.holder_of(key)
    if not holder then return false end
    local o = GGAI.load_bounty(holder)
    if not o or o.target ~= key then return false end
    if o.kind ~= "lord_kill" and o.kind ~= "hero_strike" then return false end
    o.done = GGAI.need(o)
    GGAI.save_bounty(holder)
    return true
end

function GGAI.bounties_on()
    if GG.setting and GG.setting("ai_bounties") == false then return false end
    return GG.bounty_pay() > 0
end

-- THE ROUND'S BOUNTY PASS, after every faction's Court and service. Only a faction that
-- holds standing and is covered can hold a bounty - which is the player's own race.
function GGAI.bounty_sweep(names, turn)
    if not GGAI.bounties_on() then return 0 end
    local mine = {}
    for i = 1, #names do
        if GG.state[names[i]] and GG.covered(names[i]) then mine[#mine + 1] = names[i] end
    end
    -- ALL OF THEM FIRST, so a rival early in the list cannot take a target one later in
    -- it already holds.
    GGAI.index(mine)
    local settled = 0
    local n = {taken = 0, hunt_done = 0, hunt_failed = 0, hunt_void = 0}
    for i = 1, #mine do
        local f = mine[i]
        local ended, how = GGAI.settle_bounty(f, turn)
        if ended then
            settled = settled + 1
            n[how] = n[how] + 1
        elseif not GGAI.bounty[f] then
            if GGAI.take_bounty(f, turn) then n.taken = n.taken + 1 end
        end
    end
    -- THE SOAK'S MEASURE: whether rivals come out ahead is a rate, and nowhere else is a
    -- failed rival bounty written down.
    if settled + n.taken > 0 then
        GG.trace("rivals' bounties turn " .. tostring(turn) .. ": " .. n.taken .. " taken, "
                 .. n.hunt_done .. " paid, " .. n.hunt_failed .. " failed, "
                 .. n.hunt_void .. " withdrawn")
    end
    return settled
end

-- ------------------------------------------------------------------- turn ---

function GGAI.run_turn()
    -- Read once for the whole sweep rather than per faction: it is the same number for
    -- all of them and GG.turn_now is a guarded model walk.
    local turn = GG.turn_now()
    -- SWITCHED OFF, THE STANDINGS STILL MOVE: the round's record is not an AI action, and
    -- the switch promises that rivals still earn so the leaderboard still means something
    -- (logic audit, 2026-09-29).
    if not GGAI.enabled() then
        GG.snapshot_world(turn, 0, 0, 0)
        return
    end
    local ok, fl = pcall(function() return cm:model():world():faction_list() end)
    if not ok or not fl then return end
    -- WHAT THE RIVALS DID, counted as it happens. The panel's activity line is the
    -- only place a player can see that the AI plays this mod at all, so the numbers
    -- have to come from the calls that actually did the work rather than from a
    -- separate scan that could drift away from them.
    local bought, demands, patrons = 0, 0, 0
    local names = {}    -- the rivals this round visited, for the bounty pass after it
    pcall(function()
        for i = 0, fl:num_items() - 1 do
            local f = fl:item_at(i)
            if not f:is_null_interface() and not f:is_human() and not f:is_dead() then
                local name = f:name()
                names[#names + 1] = name
                GG.load(name)
                -- THIS PERIOD'S CARDS before anything is bought: this sweep runs at the
                -- round's first turn start, before this faction's own gg_turn.
                GG.rotate_cards(name, turn)
                -- BEFORE step, not after. A paid demand is reputation, and reputation
                -- can be the rank that makes the next line able to buy something.
                if GGAI.court_step(name, turn) then demands = demands + 1 end
                if GGAI.step(name) then bought = bought + 1 end
                if GG.patrons[name] then patrons = patrons + 1 end
            end
        end
    end)
    -- RIVALS' BOUNTIES (2026-09-29), in their own pcall: a pass that died is traced, not
    -- silent, and never stops the snapshot below.
    local okb, err = pcall(GGAI.bounty_sweep, names, turn)
    if not okb then GG.trace("rivals' bounty pass failed: " .. tostring(err)) end
    -- OUTSIDE the pcall above. A sweep that died half way through still tells the
    -- player something true about the part of the world it reached, and a record that
    -- is never written leaves the panel reading a stale turn forever.
    GG.snapshot_world(turn, bought, demands, patrons)
end

-- MCT switch. Defaults to on when MCT is absent, which is the common case. It now
-- gates the Court as well as the spending: a player who turns the AI off wants rivals
-- that accrue and do nothing, and appointing a patron is doing something.
function GGAI.enabled()
    if GG.setting then
        local v = GG.setting("ai_spending")
        if v ~= nil then return v and true or false end
    end
    return true
end

-- ONCE A ROUND, NOT ONCE PER FACTION. FactionTurnStart fires for every faction in the
-- campaign - about 190 of them in Immortal Empires - and this handler ignores its
-- context and sweeps the whole world, so it was running that entire sweep 190 times a
-- round. Worse, GGAI.reset_turn clears bought_this_turn at the top of each one, which
-- is the table enforcing "one purchase per faction per turn": the cap was real, the
-- harness tested it, and the listener handed it back 190 times before the round ended.
-- A faction could work through its whole affordable service list in a single round.
--
-- GG.turn_now is the same number for every faction in a round, so comparing against it
-- collapses the sweep to the first faction turn of each round.
--
-- SAVED, NOT SESSION STATE (logic audit, 2026-09-29). A save is made inside a round that
-- has already been swept - the player's turn comes after the round's first faction turn -
-- so a guard that started at 0 on a load swept that round again: a second purchase for
-- every rival.
GGAI.last_turn = GGAI.last_turn or 0

core:add_listener("gg_ai_turn", "FactionTurnStart", true, function()
    local turn = GG.turn_now()
    if GGAI.last_turn == 0 then
        GGAI.last_turn = tonumber(cm:get_saved_value("derpy_gg_ai_turn")) or 0
    end
    if turn == GGAI.last_turn then return end
    GGAI.last_turn = turn
    cm:set_saved_value("derpy_gg_ai_turn", turn)
    GGAI.reset_turn()
    GGAI.run_turn()
end, true)
