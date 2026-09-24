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

function GGAI.pick_army(faction)
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
        if not list[i].armed_citizenry then return list[i].cqi end
    end
    return nil
end

function GGAI.pick_enemy(faction)
    local wars = GGAI.TEST_WARS
    if not wars then
        wars = {}
        local ok, f = pcall(function() return cm:get_faction(faction) end)
        if not ok or not f then return nil end
        if f.is_null_interface and f:is_null_interface() then return nil end
        pcall(function()
            local fl = f:factions_at_war_with()
            for i = 0, fl:num_items() - 1 do
                wars[#wars + 1] = fl:item_at(i):name()
            end
        end)
    end
    if #wars == 0 then return nil end
    return wars[GGAI.roll(#wars)]
end

-- A REGION OF A FACTION AT WAR WITH THE BUYER, for Hobgoblin Eyes: the one thing an AI
-- wants to see through the shroud is where its enemy is.
function GGAI.pick_enemy_region(faction)
    local enemy = GGAI.pick_enemy(faction)
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

-- THE FIRST UPGRADE IN ANY OF THE AI'S OWN REGIONS, for Raise the Ziggurat, through the
-- same GG.upgrade_target the panel uses.
function GGAI.pick_building(faction)
    local keys = GGAI.TEST_REGIONS
    if not keys then
        keys = {}
        pcall(function()
            local f = cm:get_faction(faction)
            if not f or f:is_null_interface() then return end
            local rl = f:region_list()
            for i = 0, rl:num_items() - 1 do keys[#keys + 1] = rl:item_at(i):name() end
        end)
    end
    for i = 1, #keys do
        local t = GG.upgrade_target(faction, keys[i])
        if t then return t end
    end
    return nil
end

function GGAI.pick_target(faction, s)
    if not s then return nil end
    if s.kind == "unit" then return GGAI.pick_army(faction) end
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

function GGAI.report(faction, s, target)
    -- Only a service that landed on a HUMAN is announced. An AI buffing itself
    -- is Log content, not a feed interrupt.
    if not s.hostile or not target then return end
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
    for i = 1, #humans do
        local h = humans[i]
        if s.hostile and target == h then
            GG.log_add(h, "hit", s.guild, s.key, faction)
        elseif theirs and GG.culture_of(h) == theirs then
            GG.log_add(h, "ai_buy", s.guild, s.key, faction)
        end
    end
end

-- ------------------------------------------------------------------- turn ---

function GGAI.run_turn()
    if not GGAI.enabled() then return end
    local ok, fl = pcall(function() return cm:model():world():faction_list() end)
    if not ok or not fl then return end
    -- Read once for the whole sweep rather than per faction: it is the same number for
    -- all of them and GG.turn_now is a guarded model walk.
    local turn = GG.turn_now()
    -- WHAT THE RIVALS DID, counted as it happens. The panel's activity line is the
    -- only place a player can see that the AI plays this mod at all, so the numbers
    -- have to come from the calls that actually did the work rather than from a
    -- separate scan that could drift away from them.
    local bought, demands, patrons = 0, 0, 0
    pcall(function()
        for i = 0, fl:num_items() - 1 do
            local f = fl:item_at(i)
            if not f:is_null_interface() and not f:is_human() and not f:is_dead() then
                local name = f:name()
                GG.load(name)
                -- BEFORE step, not after. A paid demand is reputation, and reputation
                -- can be the rank that makes the next line able to buy something.
                if GGAI.court_step(name, turn) then demands = demands + 1 end
                if GGAI.step(name) then bought = bought + 1 end
                if GG.patrons[name] then patrons = patrons + 1 end
            end
        end
    end)
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
-- collapses the sweep to the first faction turn of each round. GGAI.last_turn is
-- session state and starts at 0, so the first turn start after a load runs one sweep -
-- which is what should happen.
GGAI.last_turn = GGAI.last_turn or 0

core:add_listener("gg_ai_turn", "FactionTurnStart", true, function()
    local turn = GG.turn_now()
    if turn == GGAI.last_turn then return end
    GGAI.last_turn = turn
    GGAI.reset_turn()
    GGAI.run_turn()
end, true)
