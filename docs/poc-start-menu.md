# Proof of concept: Start menu on mGBA (2026-11-23)

An OCaml program opens and closes FireRed's Start menu on mGBA through the daemon, and a change to
its reader is checked on a recorded run in under a second, with no emulator and no C++ rebuild.

## Live run

```
# mGBA instance with the bridge on port 47810 (see daemon/README.md)
daemon/build/gamepilot_daemon --backend mgba --mgba-port 47810 --port 47900 --log run1.jsonl
cd src && dune exec -- gamepilot run start_menu_poc
start_menu_poc: PASS (open 50 ms, close 0 ms after batch_done)
```

The whole program (hello, load the Pallet overworld state, subscribe one `core.color_stats@1` probe,
Start, wait for the menu, B, wait for it to close) took 0.57 s wall clock. The daemon ran the emulator
in lockstep at 59.7-60.1 frames/s with no frame gaps and no late key presses. The wire log has 40 lines.

Probe values on the menu box (x 0.94 w 0.04, y 0.05 h 0.5): open mean ~251, stddev 10-13; closed
mean ~[142, 204, 181], stddev ~[44, 40, 35]. Reader thresholds (`src/games/frlg/lib/start_menu.ml`):
`min_white = 220.`, `max_stddev = 20.`

## Dev loop (stop rule 4)

The recorded log is `src/games/frlg/test/fixtures/mgba_run1.wirelog.jsonl` (home path replaced by `~`).

| Step | Result | Wall clock (edit + rebuild + replay) |
|---|---|---|
| `max_stddev = 5.` (broken) | `start_menu_poc: FAIL menu did not open within 3000 ms` | 0.43 s |
| `max_stddev = 20.` (fixed) | `start_menu_poc: PASS` | 0.27 s |

`dune test` replays the recorded run on every build, so a reader change that breaks it fails CI.

Replay semantics: when the program waits and the recorded client sent its next request first (the live
wait ended there), the wait times out, so a reader that misses on the recorded frames reads as the
program's own failure. Waiting again past that point is a divergence.

## Open points found

- Frames after `backend.load_state` cannot be told apart from frames already in flight before it; a
  load counter in `frame` would fix it (programs agent, item 6).
- Responses don't name their method; probe results don't name their kind (decoded by shape).
- Replay does not yet check that the program sent every request the recorded run sent.
- No `race` effect yet.
