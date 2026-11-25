# A5. Port FRLG Wild RNG and Static RNG

Goal: GamePilot programs `frlg.wild_rng` and `frlg.static_rng` that do what PA/CC's FRLG `WildRng`
and `StaticRng` do: find a seed and target advance, boot and press on time, calibrate from what was
caught, and stop on a shiny. They gate the shiny parts of A4 and A6.

## What exists

- **The C++ programs** in `SerialPrograms/Source/VideoGames/PokemonFRLG/Programs/RngManipulation/`
  (upstream PA/CC, with fork changes): `WildRng`, `StaticRng`, and next to them `GiftRng`,
  `StarterRng`, `RoamingLegendaryRng`, `EggRng`, sharing the seed and encounter databases,
  calibration, blind navigation, hard reset and the program base with its prechecks (free party
  slot, black border). About 8k lines of C++ in that folder.
- **Decisions already made** in GamePilot: RNG math is rewritten in OCaml with the C++ as test
  oracle (stack design D6), and FRLG RNG is needed in S4 (R12). `docs/design/BDSP-RNG.md` (PR #1,
  section 8 item 7) leaves FRLG RNG on the Switch out of its scope: presses are timed from a known
  boot at about 60 fps (16.7 ms frames), not from blinks, so it needs its own timing gate.
- **Plan for the shared wild loop**: fork PR #776 section 4.4 splits the reset, calibrate, catch and
  read loop out of `WildRng` so a standalone program and the dex collector (A6) share it. There is
  no plan yet for the GamePilot port itself; this page is it.

## Steps

1. **Pure math** in `src/games/frlg/rng`: the Gen 3 LCG, Method 1/2/4 generation, the wild slot
   and encounter tables, the seed database lookup and the target search. Golden vectors generated
   from the C++, as `src/games/bdsp/rng` does in PR #2.
2. **Calibration** (seed and advance offsets learned from caught results) as pure functions with the
   C++ calibration as oracle, persisted per profile.
3. **Timing gate on the Switch**: measure press-to-effect jitter at 60 fps through the daemon, the way
   the latency spike did. If it misses one frame, stop and redesign (the stack's stop rule).
4. **Actions**: hard reset and boot timing, Sweet Scent or step encounter, summary read of the caught
   result (nature, IVs or stats), and the precheck (free party slot) ported from `run_precheck`.
5. **Programs**: `static_rng` first (one target, saved facing it), then `wild_rng` (encounter slot
   and location), each one-shot with a stop on shiny.

## Open questions

- Is mGBA useful as a test bed? Its boot timing is deterministic, which helps replay tests but hides
  the Switch's jitter; the timing gate has to be on console B.
- Which of the other RNG programs (Gift, Roaming, Egg, Starter) come with this port, or later?
- Seed data: ship the C++ databases as assets, or regenerate them from the decomp?
