# C. BDSP legendary RNG

GamePilot will build shiny static legendary RNG as the rest of slice S2, tracked in
[issue #18](https://github.com/dayfine/GamePilot/issues/18). The
[fork design](../design/BDSP-Static-Legendary-RNG.md) is the reference for encounter mechanics and
save setup. GamePilot goes first, following the closure of
[dayfine/Arduino-Source#782](https://github.com/dayfine/Arduino-Source/pull/782).

## Current foundation

The [starter RNG design](../design/BDSP-RNG.md) defines the shared Switch capture, replay, and
timing work (W1–W10). Main has the pure OCaml [BDSP RNG library](../../src/games/pokemon/bdsp/rng)
and its C++ golden fixtures. The starter attempt loop and a registered BDSP program are still ahead.

| Landed | Reuse for statics |
|---|---|
| [#2](https://github.com/dayfine/GamePilot/pull/2) | Xorshift128, the blink model, and static generation and search with Synchronize. Static templates need companion data for species base stats. Roamer generation and its Xoroshiro RNG are deferred with the release workflow. |
| [#3](https://github.com/dayfine/GamePilot/pull/3) | Blink extraction, the periodic player/NPC and aperiodic Pokémon blink solvers, and the reidentifier for periodic NPC blinks. Mixed player and Pokémon-model reidentification (`1PK`) is new work. |
| [#4](https://github.com/dayfine/GamePilot/pull/4) | Pure blink recovery, re-anchoring, the advance clock, and hit calibration. The stat calculation accepts a level and base stats. Hit identification currently generates with Synchronize off. |

## Shared Switch work

The [Switch backend](../switch-bring-up.md) timestamps frames after each read and buffers eight
full frames. The protocol exposes sequence numbers and
[ring gap counters](../../protocol/v1/README.md#methods).
W3 still needs the cropped ring and BDSP timestamp and latency measurements. W4 adds the
`core.template_ncc@1` eye probe. The current `every` subscription reports full fidelity in
`status`. Per-gap notifications and fidelity-based thread priority are W5 work. Absolute-time
`submit` with `start_at_t_ms` is W6 work. W7–W8 supply the shared recovery flow and readers.

Use W10's gap-aware solve for both workflows. Give `State_solver.blink_sample` an explicit third
per-tick observation state (blinked with optional type, did not blink, or unknown span) so
`verify_samples` skips missing or mistimed ticks rather than rejecting them. Keep reliable blink
timing with an unknown type if only the second dip may be missing. A gap long enough to hide the
shortest blink leaves that span unknown. Omit equations that rely on missing or mistimed
observations, including inferred non-blinks. Replay stalls that hide the first dip, the second dip,
and an entire blink. Use capture timestamps and frame sequence gaps so the tests cover a dropped
frame at 30 fps and longer stalls.

Keep the input lease active throughout read-only waits, including the Munchlax intro. Add an
`Effects` lease-renewal op wired through `Session` so the live runner can renew the lease during
those waits. Verify this with a run that exceeds both the default 60-second lease and the Switch
daemon's 180-second keep-awake interval. Check the wire log that the daemon's default `B` press
stays suppressed.

## Program integration

Register the static RNG as a Switch checkpoint program. Use the checkpoint runner (`engine/run`)
and have its BDSP actions call the game effects. Add BDSP to `Program_registry` (with
`Descriptor.rules`, `Native` viewport, and `Descriptor.game.switch_home` carrying a measured
`home_tile` color for HOME resets) and to the OCaml lint family when wiring the first checkpoint.
Express player settings through `Run_options` and per-user files under `Repo_io.Repo_files.data_dir`
(using `One_of`/`Text` + per-user JSON config, or extending `Run_options` for toggles and target
filter tables). Use the engine's
[`Roll` and `Console_start` contracts](../design/Engine-Boundary.md#3-new-engine-concepts)
for observed misses and retries from a verified in-game save. Wiring those planned contracts or
equivalent shared runner support is part of the integration work. Unreadable screens, failed
recovery, and input faults follow the runner's fault path. Share Munchlax recovery as a boot step
in the encounter attempt. Any post-v1 standalone seed finder would run as a single-checkpoint
program under `engine/run` or as a `gamepilot ctl` command (one-shot runners were retired).

## Encounter workflows

- **Quiet room (A).** Recover the state from player blinks before entering the chamber, then track
  the legendary model's aperiodic blinks on the room-entry timeline. This is the first approach for
  Dialga or Palkia and also applies to Uxie, Azelf, and Giratina. Rotom can use a direct trigger.
- **In-chamber save (B).** Recover the boot state from the Munchlax intro, load the save, and
  reidentify the advance with one player and one Pokémon model (`1PK`). This lets Ramanas Park
  start after the slate fixes the encounter species. Heatran, Regigigas, Darkrai, and Arceus can
  follow once their scenes and trigger timings are measured.

V1 covers static battles. Shaymin's Flower Paradise particle effects consume about 279 advances per
second, and Mesprit and Cresselia need a separate release flow. V1 excludes those three encounters.
Coverage expands by verified encounter and game version.

## Steps after the starter (W9) passes

1. Add verified encounter data for the first targets. Check levels, ability roll counts,
   guaranteed IVs, and Synchronize against PokeFinder and the existing C++ vectors where they
   overlap. Treat blind delays in the fork design as starting values for console calibration.
2. Build the Munchlax boot step using the existing Pokémon blink solver. Replay recorded intro
   blinks and test lease renewal before running it live.
3. Add mixed-model timeline simulation and `1PK` reidentification to the RNG library. From a `1PK`
   anchor, simulate player ticks and Pokémon blinks through target selection, waiting, and
   re-anchoring. The periodic `Advance_clock` remains useful in scenes with human blinks alone.
   Fit or bound the player tick period and keep both event orders when a player tick and Pokémon
   blink may swap. Prune inconsistent candidates as observations arrive and measure search time
   on recorded sessions. Test unique, ambiguous, and missing matches, including tick-period drift
   and arbitrary initial Pokémon blink phases. Measure timer and advance offsets for loading a
   save and closing a menu separately before using either as a fresh-scene anchor.
4. Add the static trigger scheduler and BDSP readers. Start with template and shape probes for
   digit glyphs, slash-separated HP, two- and three-digit stats, and the 25 nature labels. Commit
   the assets and replay fixtures for all nine supported languages in GamePilot. Use the fixtures
   to decide if a shared asynchronous OCR probe is needed. Add visual-only battle shiny detection
   (audio capture is deferred), verifying `WILD_ANIMATION` dialog boundaries against opening
   ability and weather banners (`Pressure`, `Drizzle`, `Drought`, `Air Lock`, `Slow Start`). Add
   catch handling and post-catch Summary readers for both a free party slot and a full party that
   sends the catch to the Box. Verify Summary reads at each calibrated encounter's level and pass
   Synchronize through search and hit identification.
5. Validate one post-slate Ramanas Park encounter on the Switch, then one post-E4 (or
   post-Commanders) Dialga or Palkia encounter for workflow A. Measure the hit offset, check
   whether each blink timer runs during the cry dialog (including whether pre-slate Ramanas spawns
   the 3D model before the cry box), and verify `+1` alignment on `DirectNoPokemonModel` / Rotom.
   Replay each workflow end to end before expanding coverage. For later encounters, verify the
   key item is registered and its prompt preserves readable blinks. Check the effects of Lake
   Acuity's snow, Turnback Cave's layout and fog, and Stark Mountain's particles. Measure Arceus's
   timed Up input on the Hall of Origin stairs as its own trigger.

## Catch calibration and settlement

Keep autosave off during attempts. Catch calibration defaults off. When enabled, default to
standard balls and handle failed catches or a depleted ball supply as attempts without a
calibration reading. A Master Ball is opt-in. After a miss, return to the pre-encounter save
without saving. Base timing corrections on uniquely identified hits and require agreement across
multiple well-anchored `1PK` attempts before changing the input bias. After a target auto-catch,
verify the result and stop on a safe screen for the player to review and save manually.

## Prerequisites

A passing starter loop (W9), a post-game BDSP save, and a matching slate for the first Ramanas Park
test. [Underground mining](bdsp-underground-mining.md) can supply slates for later runs.

## Open question

Which Ramanas Park encounter and game version should provide the first post-slate test save?
The fork design suggests Regirock or Mewtwo.
