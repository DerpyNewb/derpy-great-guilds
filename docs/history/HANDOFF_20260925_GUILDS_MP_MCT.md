# The Great Guilds - MCT settings in multiplayer, and turn 1 on the player's settings

2026-09-25. Built, packed and deployed to `data/`:

- `derpy_great_guilds.pack`, MD5 `40fe934ad62dac1982e6aeac259815d5`, 32,077,286 bytes. The MD5
  matched on both sides.
- The previous build (`7dbe88c6`, the Leaderboard icons, see
  `HANDOFF_20260924_GUILDS_BUILDING_LINE_LEDGER.md` section 7) is backed up as
  `Modpacks/derpy_great_guilds.pack.bak_20260925_pre_mp_tune_7dbe88c6`.
- Not pushed to GitHub.

The request was "add mct and multiplayer compatibility for the great guilds mod". An audit
found both mostly present already:

- the MCT page, with presets, sliders, switches and a debug section;
- the multiplayer transport, where every panel action goes out as a UITrigger;
- forced local-faction reads;
- `cm:random_number` for rolls.

Two gaps were real.

## 1. What was wrong

1. **Multiplayer ignored MCT completely.** `GG.mp_ignores_mct` returned the shipped defaults on
   every machine. That was deliberate: MCT is a local registry, so letting each machine read its
   own would freeze a different economy into each save. The cost was that a multiplayer campaign
   could never be tuned.
2. **Single player froze its settings at the first `FactionTurnStart`,** which comes after turn 1
   has been played. So turn 1, and the first bounty boards, ran on the defaults. See memory
   `wh3-mct-has-no-campaign-gating`.

## 2. What was built

- **The host sends, everyone freezes.**
  - At the first tick of a multiplayer campaign that has no saved settings, `GG.send_tune`
    runs only on the machine where `core:svr_load_bool("mct_local_is_host")` is true.
  - That is the flag MCT sets in the lobby, and the one its own sync reads to decide who
    sends (`groovy_mct`, `systems/sync/main.lua`). It was read out of the pack, not guessed.
  - The host reads its own MCT, packs the settings with `GG.pack_tune`, and sends them
    through the existing `gg1` transport as the op `tune`.
  - `GG.MP_OPS.tune` runs on every machine in UITrigger order, and freezes the settings into
    `derpy_gg_tuned` once every part is in.
- **Parts.** Each event string stays at or under 100 characters (`GG.TUNE_CHUNK`, MCT's own
  ceiling). Every part reads `i/n|v|v|...`.
  - Every preset packs to 74-79 characters, so it travels as one part.
  - Custom settings with four-digit sliders need two.
- **Before the settings arrive,** `GG.snapshot_settings` sets `GG.TUNE = nil` in multiplayer and
  writes nothing. Every machine plays the identical shipped defaults.
- **Once frozen, always frozen.**
  - A second broadcast is ignored, and a loaded campaign that already has settings sends
    nothing.
  - A host who changes MCT mid-campaign changes nothing. This is the same rule as single
    player.
- **If the host has no MCT,** MCT never set the flag, so nobody sends. The campaign stays on the
  defaults, unfrozen, and identical on every machine.
- **Existing multiplayer saves** already froze the defaults under the old rule, and they keep
  them.
- **The first tick now runs `GG.snapshot_settings()` first.** In single player that reads MCT
  there, so turn 1 plays on the player's settings. MCT loads its registry in `LoadingGame`, which
  runs earlier.
- **The MCT page.**
  - "Log every reputation gain" is `set_is_global(true)`. That is the call MCT makes for its
    own two logging switches: global options are left out of the host sync and left unlocked
    on clients, so each player keeps their own.
  - The switch only writes to that machine's log.
  - The description now says the settings are read when a campaign starts, and that in
    multiplayer the host's are used for every player.
- **Deleted:** `GG.mp_ignores_mct` and the harness assertions that pinned its old behaviour.

## 3. Tests

A new harness block simulates two machines in turn, delivering the same broadcast to each.
The host's MCT says Hard and the client's says Easy. It checks the following:

- **Who sends:** only the host sends, and every part is at most 100 characters and goes out
  on the host's cqi.
- **Before the host's settings arrive:** nothing is frozen, a turn start freezes nothing, and
  the client plays the defaults, not its own Easy.
- **After they arrive:** both machines freeze byte-identical settings, on the host's Hard,
  with the host's switches.
- **Once frozen:** a later broadcast changes nothing, and a saved campaign does not send
  again.
- **Custom host:** four-digit sliders travel in two or more parts. Nothing applies until the
  last part arrives, then all values land intact.
- **No MCT on the host:** nothing is sent and nothing is frozen.
- **First tick:** in single player the first tick freezes the player's own MCT and
  broadcasts nothing. In multiplayer the host's first tick sends.

Eight mutations were run and all were caught:

- a client sends;
- multiplayer freezes its own MCT;
- the settings apply on any part;
- a frozen campaign can refreeze;
- no first-tick snapshot;
- no first-tick send;
- parts that are too long;
- resending on load.

Also green:

- `luac` on all four scripts;
- `check_lua_api`, `check_lua_literal_left` and `check_lua_undeclared`, which reports only the
  existing `BUTTON*` names;
- `gen_great_guilds --check` and `--selftest`;
- `gen_guilds_ui --check`;
- `check_guilds_ui`;
- the packed scripts are byte-identical to staging.

## 4. Owed

- **A two-machine campaign.** Start a new one with the host on Hard and the client on Easy.
  - Both logs should show "froze the host's settings for this campaign".
  - The host's log should also show "sent this campaign's settings to every player".
  - There should be no desync through the first few turns.
  - This has never been run, the same as the rest of the mod's multiplayer support.
- **Single player:** start a campaign on Easy. The first bounty board and the turn 1 limits
  should already be Easy's.
