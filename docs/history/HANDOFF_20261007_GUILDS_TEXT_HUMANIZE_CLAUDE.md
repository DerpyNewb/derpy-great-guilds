# Handover to Claude: Great Guilds player text

2026-10-07. Workspace: `G:\Modding for resources`. Run commands from the workspace root.

## Result

Codex completed the player-text pass in [the original brief](HANDOFF_20261007_GUILDS_TEXT_HUMANIZE_CODEX.md).
Read [the editing report](CODEX_GUILDS_TEXT_REPORT_20261007.md) for family counts, before/after examples, fixed strings,
factual questions and command output.

Reviewed nine supported races plus the generic fallback. Changed 3,440 of 8,980 localisation rows;
text fell from 728,562 to 685,149 characters. The MCT pass changed 39 string expressions and
corrected the known Six guilds description to Seven guilds. Names and mechanics are unchanged.

**State: source edited and TSVs regenerated; not packed, deployed, uploaded, synced to GitHub or tested in game.**

## Files and ownership

- Maintained source: `tools/gen_great_guilds.py` and
  `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua`.
- Generated outputs with changed bytes: `Modding Files/source/great_guilds/loc.tsv` and `missions.tsv`.
  Regenerate through `gen_great_guilds.py --write`; do not edit either by hand.
- All other generated TSVs and every staged `zzz_derpy_guilds*.lua` campaign script matched their baseline hashes.
  `--write` rewrote the UI MCT-name block and bounty-data script without changing their bytes.
- Destination pack for later release work: `Modding Files/Modpacks/derpy_great_guilds.pack`.
  This pass did not inspect or change its contents. The existing index records a separate panel-tab build
  `2C504683` in Modpacks; that is dated context, not validation of the pack for this text pass.
- The game copy and launcher/mod-manager selection were not inspected or changed.
  Establish the enabled copy before deploying. Loose staging is not a full mirror of a live pack.
- `repos/derpy-great-guilds/` was not touched. Baselines and full logs are in
  `.skilltree_cache/guilds_text_20261007/`.

## Checks completed

- `py tools/gen_great_guilds.py --write`: exit 0.
- `py tools/gen_great_guilds.py --check`: exit 0, no reported problems.
- `py tools/gen_great_guilds.py --selftest`: exit 0;
  `selftest ok: 7 guilds, 95 services, 90 bundles, 774 loc`.
- Lua 5.1 `tools/_guilds_harness.lua`: exit 0, `harness ok`.
- Lua 5.1 `tools/_guilds_bounty_harness.lua`: exit 0, `bounty harness ok`.
- Lua 5.1 `luac -p` on the MCT file: exit 0.
- Saved-baseline comparison: localisation keys and names, numeric tokens, placeholders, markup,
  Help structure and fixed-label lengths preserved. Every family is shorter overall;
  no string exceeds +10%. Generator logic, checks and self-test source are unchanged.
- MCT comparison: comments, non-text tokens and digit values preserved.
- Chaos Dwarf and High Elf full previews: no width findings. Both exit 1 solely for
  the baseline `LOW CONTRAST 4.2:1 ... Buy` warning. Skaven Help page 1: exit 0.
  The Guilds panels for Chaos Dwarfs/High Elves and Skaven Help PNG were visually inspected.
  The game font still needs a live fit check.

The complete suite was checked at baseline and after integration, rather than after each isolated family edit.

## Keep these text contracts

The four promotion phrases in the original brief remain exact. The self-test also identifies
`fallen` in expired-demand feed text, `falls` in its Court tooltip, `it falls` in Help and
the expired-demand heading. A first wording pass failed those literal checks; Codex adjusted
the prose and left the checks intact. The Skaven free-expiry branch still passes.

Hall self-tests assert complete Chaos Dwarf level-2 descriptions and the Empire level-0
temple description. Those common clauses were kept. The hall unit validator also parses
`Trains` and requires `if you own the pack` for certain DLC units. Do not casually rename
those clauses when reviewing the text.

All guild, rank, service, hall-level, panel and tab names are unchanged. The report proposes
only `Losing reputation` to `Losing Reputation` for the Help title, without applying it.
High Elf `Influence` remains where it names the actual vanilla resource.

## Decisions still needed

Review the report's factual questions before changing any rule text:

1. Skaven Help page 5 still counts four Reputation losses and three rank risks despite omitting expired demands.
2. Generic Help claims ignoring a demand costs more than paying it, without allowing for presets or different currencies.
3. MCT deadline/penalty tooltips state the common rule without the Skaven exception.
4. Generic hire text conditionally promises elite infantry despite unsupported-race recruitment being refused.
5. Help says each rank gives a bonus, while Unmarked has no rank bundle.

These existing claims were left for author review. No balance or mechanic correction was made.

## Next steps

1. Review the report and decide whether to approve the Help-title proposal and any factual corrections.
   If source changes, regenerate and rerun the affected checks. Keep frozen names and text contracts intact.
2. Read `Modding Files/CLAUDE.md`, the pack-building skill and the importer entry point before packing.
   The importer can save a pack in place. Preserve the separate panel-tab work already recorded in the index.
3. Pack the reviewed text, verify the saved pack's localisation and MCT file, and establish the enabled
   game copy before deployment. Do not infer deployment from regenerated TSVs.
4. Check text fit and wording in game, especially Help, rank tooltips, Court demands and DLC hall cards.
5. Sync the maintained source, generated outputs and report to the owning repository using its workflow.
   Record the actual pack/deploy/upload state in the next handoff.

## Source hashes at handover

| File | SHA-256 |
|---|---|
| `tools/gen_great_guilds.py` | `09fc052fee6d8a5e46a47da0f015a2d8c5c10103ef2c771f30c6a8406c832303` |
| `Modding Files/pack/script/mct/settings/derpy_great_guilds.lua` | `72373e8ade4f63017601f57cea25ac64f478fc48485fb8133abe9684387a9e25` |
| `Modding Files/source/great_guilds/loc.tsv` | `ae7b97ee12c2d5d8d0f68fa5c221a2924a0ac2dab861bac6f781466b867a831a` |
| `Modding Files/source/great_guilds/missions.tsv` | `37a70fe9d8bca2da75854c107ccf00fd5f810dc66ea82029617a2a471b877b9e` |
