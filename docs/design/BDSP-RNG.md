# BDSP blink RNG on GamePilot (S2)

Status: **draft for discussion, nothing built** (2026-11-23). Nothing here is decided until the user
says so; recommendations are marked as such. It plans slice S2 of `Layered-Automation-Stack.md`
(section 9), starting with the starter RNG that the fork's C++ AutoStory runs today, and follows
that document's decisions (Q2, Q3, D5, D6, R7, R11, R21) unless a section says it proposes a change.

## 1. What the C++ does today

The fork (`dayfine/Arduino-Source`, `bdsp/lean`) gets a shiny starter in BDSP by reading the game's
RNG from eye blinks:

1. **Position.** AutoStory walks Dawn/Lucas and Barry to Lake Verity's blink spot
   (`StarterNavigation`, `BlinkScenes`).
2. **Watch blinks.** Two `EyeBlinkWatcher`s (player, Barry) run on every inference tick. Each
   computes one number per frame: the best grayscale zero-mean normalized cross-correlation
   (OpenCV `TM_CCOEFF_NORMED`) of an open-eye template over a small box, the box rescaled to a
   1080p reference (`EyeBlinkDetector`, about 150 lines).
3. **Turn numbers into blinks.** A threshold per watcher is estimated from the samples; dips below
   it become blink events with a time; a tick period (about 1.017 s per NPC advance) is fitted from
   the event times (`BlinkExtraction`, 417 lines).
4. **Solve the state.** From 44 rolls (about 3-4 minutes) the solver searches the Xorshift128 state
   that explains the blink gaps within 0.1 s (`StateSolver`, `BlinkModel`, `Pokemon_Xorshift128`,
   `Pokemon_BdspRng`, about 1.2k lines). A first solve is *provisional*; it is trusted once six more
   rolls give the same state (`BlinkRecovery`, 693 lines).
5. **Pick a target.** Search ahead (about 3,500 advances) for a shiny starter reachable by the
   timeline (`TargetSelection`, `RngTargets`, `RngTimeline`, `AdvanceClock`).
6. **Hit it.** Wait, re-anchoring the advance clock on new blinks, then press through a fixed timeline:
   briefcase, Starly, select, UP onto Yes, confirm at a computed time (`RngExecution`,
   `StarterNavigation`). Since fork #810 the UP press waits for the Yes/No arrow instead of a fixed
   1 s.
7. **Check.** The starter battle's shiny detector; on a miss, reset and repeat
   (`StarterRngAttempts`, 848 lines).

About 6.5k lines of C++ in all, plus 350 lines of tests.

## 2. Why now: what failed on console B (2026-11-23)

Runs 6-8 (Korean, French, German) lost hours to step 4, not to the RNG math:

| Symptom | Cause |
|---|---|
| `no RNG state solved over 156 blinks` | the stream contained a missed or invented blink, so every solve failed |
| first solve needed 51-56 rolls instead of 44 | a bad reading early in the stream |
| provisional state never confirmed for 11 min | while a provisional state is held the window stops sliding, so the bad reading never left (fixed by fork #816: drop it after six failed solves) |
| frame conversion 2-110 ms mean, 177-955 ms max | machine load 7-30: other jobs (mGBA, MuMu, a VM at ~310 % CPU, macOS StorageManagement) on a 6-core Mac |
| eye match 0.36-0.79 in evening runs vs 0.87 in the morning | darker scene, smaller margin between open and closed |

The root problem: the C++ watchers run on a periodic inference loop over the **latest** snapshot.
When processing falls behind, frames are skipped silently; a blink lasts a few frames, so a 150 ms
stall can lose it, and the solver gets a stream that contradicts itself with no way to know where.
Of the day's 21 calibrations (runs 6-8, lab log), 6 gave up this way after 156 blinks, and the last
one was stopped by hand after #816 had dropped two bad provisional states at load 13; the others
solved (5 of them reached a shiny target, the rest found none in range).

## 3. Requirements

| # | Requirement | Source |
|---|---|---|
| F1 | Every captured frame is matched (no silent skips); a frame that could not be matched is reported as a gap | blink lasts a few frames; section 2 |
| F2 | Each match carries the frame's **capture** time, not its processing time | the solver's tolerance is 0.1 s; processing delay under load reached 1 s |
| F3 | The solver can tell "no blink here" from "no data here" | section 2 |
| F4 | A press can be scheduled at an absolute time on the frame clock and lands on the console with a spread (p99 minus median) under 50 ms, measured end to end: daemon, serial controller and the console's input path. A constant offset is fine: the C++ already calibrates one out (`RngAim`'s aim offset and calibration bias) | step 6; an advance is about 1.017 s and the timeline keeps 100 ms slack |
| F5 | Same results as the C++ for the same inputs (state, targets, timeline) | R21 (transparent port), D6 (C++ as oracle) |
| F6 | A failed attempt can be replayed offline from its recording, blink for blink | stop rule 4; "every live failure becomes a replay test" |
| F7 | Works for every language the C++ supports (9) and both games (BD, SP) | runs 1-9 |
| N1 | Holds up with the machine at load 10+ (other lab jobs keep running) | section 2; the user decides per process what may be slowed (only MuMu so far) |
| N2 | Daemon stays glue: no game names, thresholds or state machines in C++ | D3, R7 |
| N3 | OCaml side: stdlib handler, no C stubs, Windows CI, the OCaml lint rules | D1, R8, AGENTS.md |
| N4 | Console B under the one-train rule: a GamePilot run takes the console through `lablock.sh` like the lab app, and never while another program holds it | R10 |

## 4. Constraints

- **Roadmap order.** S0 → S1 → S4 → S2 (Q10, revised). The Mail Glitch on mGBA and then the
  Switch comes first; S2 cannot run live before the Switch backend (Phase 5) exists and passes its
  latency gate.
- **No Switch backend yet.** The daemon has one backend (mGBA), one thread, lockstep frames. The
  capture path, its timestamps and its behaviour under load are unbuilt and unmeasured.
- **Capture timestamps are unverified.** OpenCV `VideoCapture` on macOS (AVFoundation) may or may
  not expose the driver's presentation time; reading time instead would reintroduce the load error.
- **Template scale.** BDSP's eye templates are at a 1080p reference. GamePilot's probe boxes are
  relative to the game picture and templates are in game pixels; for BDSP the "game picture" is the
  whole 1920x1080 frame, so `game_size` = 1920x1080 and the existing scaling rule applies unchanged.
- **Only `core.template_match@1` exists**, scoring mean squared difference (lower is better). The
  blink detector needs normalized correlation on grayscale (higher is better): another formula, so
  either a new kind or an option (section 5.2).
- **`every` has no meaning today.** Since contract v1.4 a `frame` carries only changed results, and
  the README says both deliveries get the same frames. So a missing result is not a gap; only a
  missing `seq` can be one. F1-F3 need the daemon to promise a `frame` for every captured `seq` while
  an `every` probe is subscribed (W5).
- **Single thread.** The stack design's daemon is one thread with lockstep frames (section 3, and the
  daemon README). Anything with a second thread is a change to that design, not an S2 detail
  (section 5.3).
- **Wire volume.** Two probes on every frame at 60 fps is 120 results/s; v1.4 sends only changed
  results, but a correlation score changes every frame. About 10 KB/s of JSON: fine for localhost.
- **CPU priority.** Without root the lab cannot raise its own process's nice value or lower it back
  on another process; macOS QoS classes (`pthread_set_qos_class_self_np`, `taskpolicy -b/-B`) are
  available to the owner. The user approved only MuMu to be slowed during RNG.
- **Transparent first.** R21: the first OCaml version reproduces the C++ behaviour, including the
  #816 drop rule; better recovery comes in its own PRs.

## 5. Options and recommendations

### 5.1 Where the per-frame eye match runs

| Option | Pros | Cons |
|---|---|---|
| **A. Daemon probe kind** (recommended) | On the frame path that already has `seq`, capture time and the `every` delivery (design invariant 3: "BDSP blink timing needs `every`"); about 1 ms per box; generic (no game names); recordings are the wire log | needs the Switch backend's capture ring to really hold F1 under load |
| B. External worker process fed by shared memory | isolates heavy work; designed for in Q3 | the match is cheap, so the isolation buys nothing; adds a process, shared memory and a second clock to keep in step; deferred by Q3 |
| C. OCaml computes on pixels | one language | breaks Q2 (no pixels in OCaml in the hot loop); pixels over the wire at 60 fps; slow without C |
| D. Keep the C++ app as a blink service, OCaml asks it | reuses working code | two apps on one capture card (a card opens once); game code in C++ (D3); no `every` guarantee, so the section 2 failure stays |

Recommendation: **A**. A worker (B) is the right place for OCR or a model, not for a few hundred
pixels per frame.

### 5.2 Shape of the probe

| Option | Pros | Cons |
|---|---|---|
| **New kind `core.template_ncc@1`**: grayscale zero-mean normalized cross-correlation, best score and placement in the box (recommended) | one formula per kind; the result means "higher is better" with no flag to read; matches `EyeBlinkDetector` exactly (F5) | a second template kind next to `template_match` |
| `mode: "ncc_gray"` option on `core.template_match@1` | one kind | the score's meaning and direction change with an option, unlike `ink`, which keeps the formula (contracts README) |
| `bdsp.eye_blink@1` | names the use | game name in the daemon (D3) |

Recommendation: the new kind. Result `{score, x, y}` like `template_match`; `score` in -1..1.
Templates uploaded as today (R13), from the fork's `PokemonBDSP/Rng` resources, moved into
`src/games/bdsp/assets/` with their source noted.

### 5.3 Frame timing in the Switch backend (proposed change to the stack design)

A capture card cannot be paused, so the Switch backend cannot keep mGBA's lockstep. This section
proposes a change to the stack design's single-threaded daemon; it needs the user's agreement as a
design change, not only as part of S2.

| Option | Pros | Cons |
|---|---|---|
| **Capture thread stamps each frame at capture and pushes it into a bounded ring; the probe thread works through the ring in order; an overflow drops the oldest frame and reports a gap** (recommended) | F1-F3: a stall delays results but does not corrupt them; a real loss is explicit | two threads in the daemon (today one); ring size and memory to choose (1080p RGB is 6 MB a frame; 2 s at 60 fps is 720 MB, so the ring holds only the probe boxes' crops or converts on capture) |
| Latest frame wins, as the C++ app does | simple | the section 2 failure |
| Lockstep, as on mGBA | exact | a capture card cannot be paused |

Recommendation: the ring, with probes evaluated on box crops so a frame costs kilobytes, not
megabytes. Raise the capture and probe threads to QoS user-interactive (allowed without root) so
other jobs yield to them.

What each thread may touch:

| Thread | Owns | Never touches |
|---|---|---|
| capture | the capture device; stamps each frame with `seq` and capture time; copies the subscribed boxes' crops into the ring | probes, sockets, the controller |
| server (today's one thread) | the ring's read end, probes, JSON-RPC, the command scheduler, the controller | the capture device |

The ring is the only shared state: single producer, single consumer, fixed size. The capture thread
reads the current probe set (boxes only) from an immutable snapshot the server thread swaps in on
`subscribe`/`unsubscribe`.

When the probe set changes mid-stream: entries already in the ring hold crops for the old set. A new
probe gets its first result on the first frame captured after its `subscribe` (as v1.4 already says
"the first frame after a `subscribe` carries every subscribed probe's result"); frames captured
before it have no result for it, and that is not a gap. Keeping full frames for a short window
instead was considered and rejected: 1080p frames are 6-8 MB each, so even half a second is
200 MB. **Measure** before relying on it: capture timestamp source and jitter,
and gap rate at load 10 with the lab's real jobs running (work item W3).

### 5.4 Solver robustness

| Option | Pros | Cons |
|---|---|---|
| Port as is, with #816 (drop a provisional state after six failed solves) | R21; the C++ is the oracle | still guesses "no blink" across a gap |
| **Then: gap-aware windows**: a frame gap longer than the shortest blink marks that span unknown; readings touching it are left out of the solve (recommended second step) | uses F3 directly; no false contradictions from stalls | fewer usable readings in a bad window; needs replay data to tune |
| Leave-one-out solve on a contradiction (drop each suspect blink in turn, accept a unique solve that then confirms) | also covers misreads with no gap (dark scene) | more solver work (bounded: 44 solves); risk of accepting a wrong state, so it must confirm |

Recommendation: port first (F5), then gap-aware windows, then leave-one-out only if replays show
misreads without gaps.

### 5.5 Pressing on time

| Option | Pros | Cons |
|---|---|---|
| **`submit` with `start_at_t_ms` on the daemon clock** (recommended) | the daemon, which owns the clock, starts the batch; no round trip in the timing path (D5 already plans "batches anchored to the frame clock") | contract change (v1.5) and daemon scheduling on wall time for the Switch |
| OCaml sleeps until T, then submits | no contract change | adds OCaml scheduling plus a localhost round trip to the press time, both worse under load |

The UP press of fork #810 becomes a `race` between the Yes/No arrow probe and a deadline, then the
anchored confirm.

### 5.6 Language for the RNG math

| Option | Pros | Cons |
|---|---|---|
| **OCaml** (recommended; D6) | the programs' language; pure and testable; one process | about 2.5k lines to port with golden vectors |
| Python (PokemonSimulation) | quick to write | a second runtime in the hot loop; Q12 keeps Python to planning and evaluation |
| C++ in the daemon | already written | game code in the daemon (D3, R7) |

Python keeps an offline role: Monte Carlo of the solver with injected misses, stalls and dark-scene
noise, fed by recorded streams, to choose thresholds and the recovery rule (section 5.4).

### 5.7 Getting real blink data before S2

| Option | Pros | Cons |
|---|---|---|
| **Log each sample from the C++ app now** (time, watcher, score; a few KB per attempt) (recommended) | every lab run from today on becomes test data for the OCaml solver and the 5.4 choices; today's failures cannot be replayed because nothing was logged | a small fork PR in C++ that GamePilot does not own |
| Wait for GamePilot recordings | no C++ work | no data until S2 is live |

## 6. Planned work

In order; sizes are rough guesses for one agent lane, not measurements. W1-W2 need no daemon, no
console and do not disturb the S0/S1 order; W3 onward wait for Phase 5.

| # | Item | Where | Done when | Size |
|---|---|---|---|---|
| W1 | Log blink samples (time, watcher, score) and solver decisions in the C++ app. Through the fork lane like any fork PR: draft into `bdsp/lean`, fork CI, code health | fork, `PokemonBDSP/Programs/RngManipulation` | one lab attempt's samples are on disk and a script turns them into a stream file | S |
| W2 | Pure RNG math in OCaml: `Xorshift128`, `BdspRng`, `BlinkModel`, `BlinkExtraction`, `StateSolver`, `StateReidentifier`, `AdvanceClock`, target search, timeline math; each module names its C++ file | `src/games/bdsp/rng/` | golden vectors from the C++ (states, intervals, solves, targets) pass; W1 streams replay to the C++'s results | L (~1 week) |
| W3 | Switch backend: capture thread with capture timestamps, crop ring, gap reporting, QoS | `daemon/` | latency spike passes; at load 10 with lab jobs running, the gap rate and timestamp jitter are measured and written down | L (Phase 5 item) |
| W4 | `core.template_ncc@1` | `daemon/`, `contracts/`, `src/base/wire` | golden files; same scores as `EyeBlinkDetector` on the fork's test images (`probe_images`) | S |
| W5 | Gaps on the wire. The gap signal is the frame `seq`, not a missing result (v1.4 omits unchanged results). While an `every` probe is subscribed the daemon sends a `frame` for every captured `seq`, consecutive; a frame it could not evaluate (ring overflow, capture hole) is reported by a `gap` notification {`from_seq`, `to_seq`}. This gives `every` its meaning back; without an `every` probe frames may skip as today | `contracts/`, daemon, `core/session` | golden files; replay of a recorded gap reaches the program as a gap | S |
| W6 | `submit` `start_at_t_ms` (v1.5) | `contracts/`, daemon `schedule`, `core/effects` | F4 measured end to end on the Switch, as the latency spike does: schedule a press whose effect shows on screen at once (opening a menu), take the capture time of the first frame that shows it, and report the spread of (that time minus `start_at_t_ms`) over 100 presses at idle and at load 10. Spread p99 under 50 ms; the median is the constant offset the aim calibration absorbs | M |
| W7 | Blink recovery and calibration as a program on the effects, ported with #816 | `src/games/bdsp/rng/` | replays of W1 streams give the same provisional and confirmed states, and the same give-ups, as the C++ | M |
| W8 | BDSP readers: eye boxes per scene and player model, Yes/No arrow, dialog, battle shiny check, summary | `src/games/bdsp/readers/` | replay tests from recorded frames in each language | M |
| W9 | Starter attempt loop and timeline (reset, lake walk-in, target wait, presses, check) | `src/games/bdsp/programs/starter_rng/` | 10 attempts from the same save on console B, hit rate at least the C++'s | M |
| W10 | Gap-aware solve (5.4 second step) | `src/games/bdsp/rng/` | on recorded failures it confirms where the port gave up, and never confirms a wrong state in the Monte Carlo | M |

Not in this plan: the bedroom and intro seed finders (other BDSP RNG programs), legendaries
(the rest of S2), and the BDSP story before Lake Verity (the C++ chain keeps doing it and hands over
the save, as S4 does for FRLG).

## 7. Caveats

- **The ring is only as good as capture.** If the capture card or driver itself drops frames under
  load, the daemon sees a hole in the card's frame counter (if it has one) or only in the timestamps.
  W3 must find out which.
- **A gap still costs data.** F1-F3 stop false readings; they do not create true ones. At heavy load
  attempts still slow down; the gain is that they no longer give up after collecting 156 bad blinks.
- **Dark scenes are a separate problem.** Lower eye-match margins at night are lighting, not timing;
  gap handling does not help. Options are templates per time of day, a contrast-normalized box, or
  setting the Switch clock to day before RNG (changes in-game time for the whole run; needs the user).
- **Transparent port means old weaknesses too.** The first OCaml version will give up where the C++
  gives up; W10 is where it gets better.
- **Two stacks in parallel.** Until W9 passes, the C++ starter RNG keeps running the language runs.
  Fixes found there (such as #810, #816) must be ported, and W1's logs are how the OCaml side keeps up.
- **Timing on Windows.** The daemon's clock and the press scheduler need the same accuracy on
  Windows (CI is the gate there, but console B is a Mac).
- **Effort estimates are guesses.** The design's stop rules (section 10 of the stack design) apply:
  a failed spike takes its fallback and a new estimate.

## 8. Open questions for the user

1. Approve W1 (C++ sample logging on the fork) now, ahead of S2?
2. Approve W2 (OCaml RNG math) as a background lane now, or keep everything for S2?
3. New kind `core.template_ncc@1` (recommended) or an option on `template_match`?
4. Daemon threads at QoS user-interactive: fine as a default?
5. Dark scenes: is setting the Switch clock to daytime before RNG acceptable, or must readers cope?
6. Agree to 5.3 as a change to the stack design (two daemon threads on the Switch backend)?
7. The stack design's latency gate says "p99 under one frame (33 ms)": one frame is 33 ms at 30 fps
   but 16.7 ms at the capture's 60 fps. Which does the gate mean? (BDSP itself renders at 30 fps.)
