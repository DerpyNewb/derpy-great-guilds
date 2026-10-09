# audit-001 fix log - The Great Guilds

**Follow-up report** to `audit-001-2026-10-09.md`. All 61 findings taken in order ("all in order").
**Build:** f41a33d9 -> e8f55503, deployed to the Workshop folder only (not uploaded).

**Verified on e8f55503:**
- `gen_great_guilds.py --selftest` ("7 guilds, 95 services, 90 bundles, 774 loc") and `--check` pass
- `_guilds_harness.lua`: harness ok, with new tests for #6/#7, #26, #28, #29, #30, #49-#54, #56 and #58, each watched failing first
- `gen_guilds_ui.py --check` and `--selftest` pass
- Previews: 9 races x 3 sizes, no finding except #10's artefact
- Import verified every table; 494 paths, the same set as f41a33d9
- Bundle loc: 0 findings
- The packed Lua, MCT and twui match the workspace byte for byte

**Rulings, not fixes** (each costed below): #10, #31, #55, #57, #60. #27 is a note.

**Still needs eyes in game:**
- the greyscale on a shut Buy/Take/Pay (the preview does not draw shaders)
- Help wrap width (#57) and the reason plate at Small/Large (#10)
- the panel at 4K (#27)

- #1 Workshop l.95 ranks 2, 3 and 4
- #2 (Workshop half) l.142 "at most halls"
- #2 (Help half) halls page: "and, at most halls, a unit of its trade"
- #3 EFFECT_BLURB / EFFECT_BLURB_EXTRA / TEMPLE_LORE reach phrases carry their preposition ("in every region you own", "for every army"); templates drop the fixed "for"
- #4 Workshop l.146 temple Seat exception
- #5 Workshop l.37 em dash -> colon
- #6/#7 card buttons (Buy, Take, the Court's Pay) keep a cream caption and go through GGUI.set_live: SetDisabled plus set_greyscale_t0, the opener's idiom; red stays on the price. Harness: no colour markup on any caption, shader matches disabled
- #8 Log filter plates 28 tall (24 at Small, Medium's old height): the Small pill's dark middle was shorter than the caption. Preview clean at all three sizes
- #9 Skaven: a #00000070 wash as every tab state's third image (paint_tab repaints by index; the Lua FRAME mirror follows); the HUD bar tinted to 85% for the guild counts. Same sweep over all nine races found the same counts on the High Elf and Kislev bars (tinted too) and Cathay's Small header figures on the plate's top rail at 3.9:1: sized() now scales the vertical text inset (the native 9-slice ends are the horizontal ones). Previews: 9 races x 3 sizes clean bar #10's artefact
- #10 Ruling, withdrawn: the plate is already sized from the engine's TextDimensionsForText plus the inset at every size (text_ratio cancels the panel scale). The overflow is the preview measuring with PIL a string the harness stub (7px a character x the size factor) measured 9-13px shorter. Cost if wrong: the reason plate clips its last letter at Small/Large in game
- #11 temple AI donor test: comment corrected; now pins rule 1 (own effect) for _dwf/_brt/_ksl/_skv and the order fallback for the other five, so it fails on either path
- #12 temple fallback comments reworded (RANK_EFFECTS, EFFECT_GOOD_SIGN, RANK_VALUES_OF, LEAD_VALUE_OF, HALL_EFFECT, HALL_SEAT_SCOPE, seat bundle, F3 test, HALL_AI_ROLE)
- #13 HALL_BONUS["temple"] kept as the fallback hall_bonus_text reads, marked as such (deleting it would KeyError for a future race without TEMPLE_LORE)
- #14 counts: MCT thirty preset keys, switches uncounted, numeric-key list explains rotate_turns/hall_off; Lua 21 cards, "every guild"; AI "every service"; generator "The services"
- #15 Ruling: temple route sliders keep their role labels (a race name could promise a route that race lacks); comment says so and counts thirteen renamed sliders
- #16 Workshop l.98 "Higher Reputation"
- #16 done with the Workshop batch
- #17 "Agents" -> "Heroes" in the five blooded_agents names (CHD/gen Blooded, emp/cth/hef Seasoned, ksl Hardened)
- #18 hall text "without the DLC that adds X" / "if you own the DLC that adds it"; _desc_problems check follows
- #19 "unless the settings say otherwise" kept on the two Help lines only; dropped from cards, lead bundle, Court help, lead won/lost and rank-4 messages
- #20 Help page title "Losing Reputation"
- #21 MCT: "rank 1 costs 1 Reputation a turn and rank 5 costs 5"; "those that raise an enemy's costs"
- #22 one word each: stake (not deposit), finest (not dearest/most expensive), "the army you select", "at once"
- #23 generic temple earn: "by serving the faith: its buildings and its causes" (GG.covered gives unsupported races no guilds, so no route list is true)
- #24 Conclave Backing, Friends at Court, The Phoenix King's Regard (the vanilla resource keeps its own name in the text)
- #25 PLATE_WASH D0 -> E0; no Needs or price plate under 4.5:1 on any race at any size
- #26 MCT Panel size tooltip says 1440p Medium = Large and 4K draws all three alike; harness pins the 4K case
- #27 note only: needs an in-game look at 4K, UI scale 100%
- #28 empty board: one card "No bounties this turn.", the other slots hidden, header "New offers come at the start of each turn." or, switched off, "The bounty board is switched off in the settings."; harness tests both
- #29 a failed GGUI.open prints "GAVE UP opening the panel: <error>" always; harness forces a failure and a mutant without the line fails it
- #30 Help headings: 21 header_14 cells (gg_helph_NN) over the slots, shown on Help only; a "#" line goes there and its body cell stays empty. Ruling: header_14, not header_18 - an 18px slot at a 20px step holds 14, and it sits one step under the view heading's 18. Cost if wrong: headings one size smaller than the brief
- #31 Ruling, no change: every card's text already leads with its effects' own icons (effect_icons), so the same icons in the glyph slot would show each twice; the glyph says whose service it is and the Needs plate carries the rank. Cost if wrong: three identical glyphs stay
- #32 the selected guild's marker is CA's yellow (FFB900) like the open tab and active filter; GOLD stays on the counts. Blocked is red only since #6/#7 (orange now marks only the Court's near deadline)
- #33 "six guilds" comments that state today's count: every guild / seven (20 lines, 6 files); "six" kept where it counts something else (races, listeners, effects) or tells history
- #34 service_sign docstring scoped to rank-effect bundles (enemy_settlement services sign their own effects); _cai_donor lists rule 3 and the first-row fallback; the order comments now match SERVICES (checked against TEMPLE_KEYS and the race/temple indices)
- #35 18 lore sentences rewritten across the six repeated shapes (debts owed, knives for hire, weak walls, pay carried home, lent oaths, slow secrets): Kislev, Dark Elves, High Elves, Skaven, Cathay, Bretonnia; the rest keep theirs
- #36 bounty/job completion text: one line per guild (MISSION_DONE), race-neutral, ending "Your reward is paid."
- #37 "For N turns, units/heroes you recruit start X rank(s) higher." (3 templates); --check passes
- #38 stray comma before "for your faction" gone with #3's template change (extra_sentence has no comma)
- #39 rivals_idle: "Rivals have not moved yet. End a turn to see them."
- #40 lead won: "A rival who out-earns you takes the lead back."; demand help (2 places): "your Reputation falls"
- #41 one name, "the Great Guilds panel" (4 loc lines, the MCT size tooltip); the Log is "the Log tab of the Great Guilds panel"
- #42 Help p3: "...or one belonging to a faction at peace with you. Taking that one means war, and pays far more."
- #43 renamed, not reassigned (a move reshuffles that guild's cards): the Masons' "The Watch-Houses", the Engineers' "Pavise Wall"
- #44 Chaos Dwarf temple: "victories against the Dwarfs, and the Temple's buildings."
- #45 Help p4 and the Court's patron help carry the figures from PATRON_EFFECTS / PATRON_REP_SHARE / PATRON_DISCOUNT
- #46 Workshop l.163 confirmed (GG.covered/place_opener give unsupported races no button); reworded to the one message they can see
- #47 MCT: description without the filler opener; "losing a guild's lead"; "as a percentage of what you earned"; "Reputation per ..." (9 tooltips) and "gold for each point of Reputation"
- #48 hardest preset "Cutthroat" -> "Brutal" (key "ultra" unchanged, so saves keep it); Workshop page and comments follow
- #49 Court deadline: "Due this turn" at 0, "1 turn to pay" at 1; comment says orange (LOCK_COL); harness covers 0/1/5
- #50 GGUI.count(n, key) picks the _1 loc: rivals line (3 nouns), cooldown and bounty "turn(s) left"; harness covers both
- #51 Court: the demand's figure only in the price box beside Pay (the line reads "They want gold"); the leadership card has no price box (a score is not a price); harness pins both
- #52 patron card wears the guild's glyph (the patron icon is 24px and would blur at 62); a patron serving elsewhere is one line, not "No patron appointed" over it; harness
- #53 the header's holder shows the panel crest on Bounties, Help and Log, the guild's glyph elsewhere; harness
- #54 footer: "<guild> Favour: N" on the per-guild tabs, the countdown alone on Bounties/Help/Log; harness
- #55 Ruling, no change: the flag replacing "You" was your own request (harness: "instead of Leader: You it should be Leader: and the leader's flag"); a test asserting it caught the change. Cost if wrong: none, it is your call
- #56 the shut card's three reasons come from loc (tip_short_rep / tip_cooldown(_1) / tip_short_fav) with Reputation and Favour capitalised; harness
- #57 Ruling, withdrawn: the same preview artefact as #10 - Help wraps by TextDimensionsForText, and the preview's 7px stub runs ~15% wider than PIL's body font, which is the 640-of-750 seen. Cost if wrong: Help wraps short in game; check page 1 in game
- #58 a service slot with no service hides the whole card (the empty bounty board's one card shows again); harness
- #59 preview: --size with --page or --help-page adds the size suffix
- #60 Ruling, left: the banners are house convention (the audit's own "leave" option)
- #61 Workshop ":D" dropped; flavour aphorisms kept
