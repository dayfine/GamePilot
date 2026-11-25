# Wild RNG (FRLG)

Registry id `frlg.wild_rng`, group FRLG / RNG (`src/program_registry`). It catches a chosen shiny
wild Pokémon by RNG manipulation, a port of the fork's WildRng (PA/CC's
`PokemonFRLG/Programs/RngManipulation/`) for Sweet Scent in grass, so every catch toward the 60 the
National Pokédex needs can be shiny (issue #14). It runs on mGBA.

| Checkpoint | Content |
|---|---|
| 01-route10-grass | From Cinnabar: fly to Route 10, Mr. Mime into the Center's PC (a party slot for the catch), into the north grass, save |
| 02-shiny-ekans | A hard reset timed for the soonest shiny Ekans of the seed table, the C++'s blind presses (title screen, continue screen, Sweet Scent), the catch, its summary's star, save |

How 02 hits its target (`wild_rng`, `src/games/frlg/actions/lib/wild_rng*.ml`):

- The seed is the title screen's A press: `backend.reset` (mGBA's power switch) boots the game from
  its save, and the press N frames later gives the same seed every time. The seed table,
  `src/games/frlg/assets/rng_seeds_mgba_route10_save.json` (FR_Eng.json's shape, delays in ms that
  round to the press frame), was measured on mGBA from 01's end save. Another save shifts every seed
  by a few timer counts, so a new start save needs its own table.
- The target is searched, not given: of the table's seeds and advances 900 to 4000, the shiny Ekans
  (TID 33002, SID 9011: plan args, as PA/CC's RNG programs take them; the SID was read once from this save's memory, and players find theirs with PA/CC's SID Helper, `docs/guide/frlg.wild_rng.md`) whose waits add up least
  (`Frlg_rng.Wild_target`).
- The waits are the C++'s `prepare_timings` with mGBA's frame model (`Frlg_rng.Rng_timings.mgba`):
  one advance per frame where the C++ counts two on the Switch, and Sweet Scent's encounter 183
  advances before the formula without its offset.
- The fork listens for the shiny sound in battle; GamePilot has no audio, so the Pokémon is caught
  and its summary read (`Frlg_readers.Shiny_star`). A catch without the star fails the checkpoint
  (`wild_rng_not_shiny`) before the save, and the runner retries from the start state.

Next: other species and routes (a seed table per start save, or a seed calibration from a miss, as
the C++ calibrates), and the Switch's frame model on console. GamePilot has no SID finder: PA/CC's SID Helper finds it.
