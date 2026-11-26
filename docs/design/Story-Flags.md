# Story flags (2026-11-25)

What a checkpoint may assume the story has unlocked, said by name in the plans instead of by
comparing checkpoint ids in code. The design is the user's choice from a session on 2026-11-25;
one question (where running really starts) is left open below. Checkpoint ids are the renumbered
ones of #221 (`NN.NN-name`, no letters); the fork's numbers are said as the fork's.

## The problem

PLZA's walk holds B to run, except in the checkpoints before 03.04-rock-pile-scene, which walk:

```ocaml
(* src/games/pokemon/plza/programs/autostory/lib/story_game.ml *)
let walk_only id = String.compare id "03.04" < 0
```

The game's story is hidden in an id comparison inside one game's code. Nothing in the plans says
that 03.04 is where running starts, a new or renamed checkpoint silently moves the line, and the
next unlock of this kind (a ride, a gift) would add another cutoff beside it.

## Decisions

1. **A game's rules declare its story flags, with defaults.** A flag is a name and the value it has
   on a new game: PLZA declares `can_run = false` and `mystery_gift = false`. The engine names no
   flag; the names are the game's (Octopath 0 and the others can declare theirs the same way).
   `GAME_RULES` (`engine/rules`) gains `val story_flags : (string * bool) list`; FRLG and BDSP
   declare `[]` until they need one.
2. **A checkpoint's plan says which flags it sets.** An optional `sets` list in the plan's
   `checkpoint` object, beside `id`, `title` and `start`:

   ```json
   "checkpoint": { "id": "03.03-battle-taunie", "title": "Battle Taunie", "sets": ["can_run"], ... }
   ```

   A set flag is `true` from the next checkpoint on: the setter is the checkpoint whose story
   unlocks it. (The session's example put `sets` on the rock pile scene, 03.04-rock-pile-scene;
   with flags derived from *earlier* plans, that would make 03.04 itself walk.
   03.03-battle-taunie, where Taunie's battle unlocks running per the fork, keeps today's
   behaviour.) A name the game does not declare fails plan
   checking (`plan_format`'s decode, which already has the game's rules), like an unknown action.
   Flags only go from their default to `true`: the story does not take an unlock back. A flag that
   must be cleared waits for a game that needs one.
3. **The flags at a checkpoint's start are derived, never remembered.** They are the game's
   defaults with every `sets` of the plans before it, in the program's run order
   (`Plan_folder.checkpoint_ids`, plain name order). So `gamepilot checkpoints --from
   03.10` alone knows `can_run = true`: no run state, no save file field, no flag read from the
   screen. The same plan folder always gives the same flags.
4. **Actions read flags, not ids.** `Story_game.make` takes the checkpoint's flags; the walk reads
   `can_run` (`walk_only = not can_run`). No code under `src/games/` compares checkpoint ids to
   decide what the game allows.
5. **Out of scope: flags across programs.** A program's flags come from its own plans only.
   Composing programs (one program's end state as another's start) is deferred to its own design,
   done thoroughly and correctly. Until then the gifts program (a separate program after AutoStory)
   checks the screen for the gift. 03.15-mable-reward setting `mystery_gift` is written in its
   plan now, so the composition design finds it there.

Story flags are not the `skip_if` flags events already name: those are read from the screen at
run time (PLZA's `Resume_flags`) to skip an event whose result the game already holds. Story flags
are read from the plans before the console moves.

## The plan format

`sets` is optional and defaults to `[]`, so every plan written today reads unchanged: no version
bump, the format stays `gamepilot-checkpoint/1`. Every reader of the format is in this repo and
learns the field in the same PR (`plan_decode`'s `known_fields_only` list for `checkpoint`), so an
older reader meeting it is not a case to handle. `Plan.checkpoint` gains `sets : string list`.

## Where flags are computed

In `engine/series`, a new pure module `Story_flags`: from the game's declared defaults and the
`sets` of the plans before a checkpoint, the flags at its start (a string-to-bool map, with a
lookup that fails for an undeclared name). `engine/series` already owns the plan folder and its
run order; `engine/plan` stays types only. The series runner computes the flags once per
checkpoint and hands them to the game with the checkpoint, beside `plan_dir`. A run of one
checkpoint by itself (`gamepilot run`) computes them the same way from its plan folder.

The runner reads every plan before `--from` for its `sets`, not only the ones it runs; each is
decoded and checked as today, so a broken earlier plan fails before the console moves.

## Migrating `walk_only`

One PR, no change in behaviour:

1. `engine`: `sets` in the plan and its decode; `story_flags` in `GAME_RULES`; `Story_flags` in
   `engine/series`, with tests (defaults, a set flag, an unknown name, `--from` past the setter).
2. PLZA: rules declare `can_run` and `mystery_gift`; `03.03-battle-taunie.plan.json` sets `can_run`
   (so 03.04-rock-pile-scene starts with it, as today's cutoff), `03.15-mable-reward.plan.json`
   sets `mystery_gift`.
3. `Story_game`: `walk_only` goes; `make` takes the flags and `walk` passes
   `~walk_only:(not can_run)`. `test_story_game.ml`'s "walked up to 03.03-battle-taunie, run
   from 03.04-rock-pile-scene on" case becomes a `Story_flags` case over the PLZA plan folder.
4. Doc comments in `walk.mli`, `walk_inputs.mli` and `story_game.ml` name `can_run` and the plan
   that sets it instead of an id.

## Open question: does running start at 03.04, or earlier?

Three statements disagree today:

- `walk.mli`: "as before dash is unlocked (01.02)".
- `walk_inputs.mli`: "dash unlocks at 03.01: 03.01 and 03.02 could run".
- The fork (`PokemonLZA_AutoStory.cpp`, branch `plza/lean`): `RUN_FROM = "03.03"`, "First
  checkpoint whose walks hold B to run; dash unlocks after Taunie's battle in 03.02b." (The
  fork's numbers: its 03.03 is our 03.04-rock-pile-scene, its 03.02b our 03.03-battle-taunie.)

The fork's history is the only evidence from the console (quoted with the fork's numbers):

- Fork commit bec527c23 (2026-11-19): "on console B, B held in 01.02 still walked, so dash comes
  later." Running is not unlocked at the fork's 01.01 (our 01.02-platform-to-plaza);
  `walk.mli` is wrong.
- Fork commit 90d43f747 (2026-11-19) moved the default from 02.01 to 03.03: "Running legs are
  checked on console only from after Taunie's battle in 03.02b; 02.01's run legs missed Brigitte
  3/3". So the fork's 03.03 (our 03.04) is the first checkpoint whose *run* timings were tuned
  on the console, not a proven unlock point: 02.01's legs failed because they were timed for
  walking.
- Nothing found backs `walk_inputs.mli`'s 03.01.

So the game unlocks running somewhere between 01.03-chase-pancham and 03.03-battle-taunie, and the
plans before 03.04-rock-pile-scene are timed for walking. The migration keeps 03.03-battle-taunie as
the setter, which is what the plans are tuned for. Whether to find the real unlock (hold B on the
console at 02.0x and 03.01) and move `can_run` there, retiming those plans for running, is the
user's call; it is a plan change, not a code change, once this design lands. Either way, the two
wrong doc comments are fixed in the migration.
