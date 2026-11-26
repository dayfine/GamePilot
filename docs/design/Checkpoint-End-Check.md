# Checkpoint end check (2026-11-25)

How a plan says "the console is already at this checkpoint's end", once for the checkpoint instead
of on every event. The user approved the change on 2026-11-25; this note fixes the field, what the
runner does with it and the migration of today's PLZA plans. Checkpoint ids are the renumbered ones
of #221.

## The problem

A PLZA checkpoint resumes from where the console is: a reload past the checkpoint's own autosave
lands at its end, and every event must then do nothing. Today each event says so itself.
`03.03-battle-taunie.plan.json` has eight events, and all eight carry

```json
"skip_if": ["minimap:03.03-start"]
```

The flag is read from the screen before each event (PLZA's `Resume_flags`, five reads over 1 s), so
a run that starts at the end reads the minimap eight times to press nothing. The same list is
repeated on every event, and a new event added without it would run at the end. The name is wrong
too: `03.03-start` is the fork's checkpoint number, the start of the fork's 03.03, which is the end
of our 03.03-battle-taunie. `03.07-pokemon-center` and `01.04-starter-and-andi` have the same
pattern (`minimap:03.06-start` on both events; `party_bar_free` on all four).

## Decisions

1. **An optional `end` object in the plan's `checkpoint`**, beside `start`, holding `is`: the
   flags that hold at the checkpoint's end.

   ```json
   "checkpoint": {
     "id": "03.03-battle-taunie",
     "start": { "place": "LumioseCity" },
     "end": { "is": ["minimap:after-taunie-battle"] },
     "events": [ ... ]
   }
   ```

   The flags are the ones `skip_if` names, read by the same game function (`Game.flag_holds`), so
   a game checks their names where it checks `skip_if`'s (PLZA's `Plan_check`). The end holds when
   every flag in `is` holds. `start` is a pose and `end` an object, so an end pose can join `is`
   later without another shape; today `Checkpoint_end` derives the Pokémon end pose from the next
   start, and nothing changes there. An empty `is`, or another key in `end`, is refused when the
   plan loads, and so is `end` in a plan with a `repeat` (a round ends where it starts, so it would
   always read as done).

2. **Before the first event, the runner (`engine/run`) checks it.** When every flag holds, no
   event runs: each is reported skipped (the watch page's plan shows them so), one line is logged,

   ```text
   [Story] 03.03-battle-taunie: already at its end (minimap:after-taunie-battle): passed, no event run
   ```

   and the checkpoint passes. The declared end pose and the postconditions are not read: the
   console did nothing, so a promise of a change from the start (items gained, money spent) cannot
   hold. A run that starts past the first event (`--from-event`) does not check it.

3. **After the last event, the runner checks it again, as an end check.** Every flag in `is` must
   hold, after the declared end pose and before the postconditions. Each is judged as a promise
   and logged by the postconditions' own lines under an `[End]` tag,

   ```text
   [End] 03.03-battle-taunie minimap:after-taunie-battle: passed: holds
   ```

   and one that does not hold fails the run with `Unmet_postconditions` at event `end`. No new
   failure kind or log format: the runner already reports promises that way. A range that stops
   before the last event checks neither.

4. **`skip_if` stays for an event's own reason.** 03.03's last event keeps `party_bar_free`, and
   01.04's first two keep `talk_or_battle_shows` and `battle_shows`: they skip when the console is
   part-way through the checkpoint, which the end check does not cover.

PLZA's `execution.end_signature` (03.07) stays as it is. It is the game's own end check, read by
waiting for three agreeing frames, and the start check accepts it as "at its end" before the
runner is called; the runner's `end` then passes the checkpoint with nothing pressed.

## The plan format

`end` is optional, and a plan without it reads and runs as today: no version bump, the format stays
`gamepilot-checkpoint/1`. Every reader of the format is in this repo and learns the field in the
same PR (`plan_decode`'s `known_fields_only` list for `checkpoint`). `Plan.checkpoint` gains
`end_flags : string list`, `[]` when the plan has no `end`.

## Migration

One PR after the minimap references are renamed for what they show (the same PR, two commits):

1. `engine`: `end_flags` in `Plan.checkpoint`, its decode, the two checks in `Runner`, tests over
   the toy game (the decode and its refusals; at the end: nothing run; not at the end: run and
   checked after; a flag that fails after the last event; partial ranges).
2. PLZA: `Plan_check` checks `end.is` with `Resume_flags.known`, as `skip_if` (its messages say
   "flag", not "skip_if flag"). The scripted runs' fakes show the minimap where the console does,
   after 03.03's map talk and outside the Center.
3. Plans: 03.03-battle-taunie and 03.07-pokemon-center get `end.is` with their minimap,
   01.04-starter-and-andi with `party_bar_free`; the repeated flag leaves their events. Their
   `metadata.source` lines say the end is checked by `end` instead of "every event is skipped".

The check after the last event is new for 03.03 and 01.04, where nothing read the end before (03.04's
start signature, when chained, reads the same minimap). It has run in the scripted tests only; its
first console run is the next 03.03 pass.
