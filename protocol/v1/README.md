# Wire protocol v1.16

JSON-RPC 2.0 between the OCaml programs (client) and the daemon (server). The golden files in this
folder are the spec: the daemon's tests parse every file and the OCaml tests decode and re-encode
every file. Change a file here first, then both sides.
The golden files are pretty-printed for reading (`dev/lint/fmt_json.py`); on the wire each message is
one line.

v1.1 adds the `load` counter to `frame` and `backend.load_state`, and a `kind` to every probe result.
Template probes (`probe.upload_template`, `core.template_match@1`) came later under the same number.
v1.3 adds `unsubscribe` and the optional `ink` of `core.template_match@1`.
v1.4 sends only changed probe results: a `frame` carries a probe's result only when it differs from
the one the previous frame sent for it (see Notifications). A v1.3 frame with every result is a valid
v1.4 frame, so older wire logs replay unchanged.
v1.5 adds `status` (the daemon's health: thread heartbeats, capture ring, gaps, client, fidelity),
answered also on a second connection while a client is served, and the live `switch` backend (see
Live backends).
v1.6 adds the watch page's three notifications (see Watch page): `watch.plan` and `watch.log` from
the program, `stop` from the daemon. A program that sends neither and never gets a stop speaks v1.5.
v1.7 adds `watch.run` from the program (see Watch page): the chain of checkpoints a run goes through.
A program that does not send it speaks v1.6.
v1.8 adds each `watch.plan` event's `started_ms` and `ended_ms` (see Watch page). Both are optional,
so a v1.7 plan is a valid v1.8 plan.
v1.9 serves many clients and adds the input lease (see Input lease): `lease.acquire`,
`lease.release`, error -32004, `status`'s `clients` and `lease`, and the wire log's `conn` and
`owner`. A v1.8 program never names the lease: its first input takes it, so it works unchanged.
v1.10 makes `t_ms` of `frame` and `batch_done` game time on a lockstep backend (see Clock and frames),
so the daemon can run mGBA faster than real time (`--speed`). No message changes; at 1x game time
keeps pace with the daemon clock, so a v1.9 program runs unchanged.
v1.11 adds the Switch's own buttons `Home`, `X` and `Y` to `submit` (see Methods), for parking the
console on the HOME menu; a backend that is not the Switch refuses them with -32602
(`43-error.switch_button.response.json`). A v1.10 program never names them.
v1.12 adds the Switch's analog sticks to `submit`'s press: optional `left_stick` and `right_stick`
(see Methods), held with the press's buttons, for walking and running in a 3D game; a backend that
is not the Switch refuses them with -32602 (`45-error.switch_stick.response.json`). Both are
optional and absent means centred, so every v1.11 press means the same in v1.12.
v1.13 adds two probe kinds for the fork's PLZA detectors (see Probe kinds): `core.line_shares@1`,
the share of a box's pixels passing a test of linear channel comparisons per row and per column,
and `core.find@1`, blobs found by the fork's fixed pipeline (colour filter, waterfill, size filter,
scores) (`46-subscribe.line_shares_find.request.json`, `47-frame.line_shares_find.notification.json`).
`hello` lists both. A v1.12 program never subscribes them.
v1.16 adds the Switch's `ZR` to `submit`, for PLZA's ball throw (ZL and ZR held to aim); a backend
that is not the Switch refuses it as it does `ZL`. A v1.15 program never names it.
v1.15 adds `masked` to `core.find@1` (optional, default `false`): `true` scores each blob's box
with the pixels outside its filter's range black, as the fork's `filter_by_mask` before
MoveEffectivenessSymbol's match. v1.15 also adds `then` to `cancel`: the queued commands are dropped
with no release and the batch given runs in their place (on the Switch, the board's replace-on-next:
the running input lasts until the new one starts), as the fork's command dispatched over a running
one, so ZL held to read the move symbols stays held through the move
(`48-cancel.then.request.json`). A v1.14 program never sends either.
v1.14 adds the Switch's `ZL` to `submit` (see Methods), for PLZA's lock-on in battle; a backend that
is not the Switch refuses it as it does `Home`. A v1.13 program never names it.
v1.2 makes the daemon own where the game picture sits in the frame: `hello` gives the `viewport` and
the `game_size`, probe boxes and template placements are relative to the picture, templates are in game
pixels, and `core.color_count@1` is new.
`hello` still says `protocol: 1`: both sides ship from this repo at one commit, so there is no older
peer to tell apart, and on the only backend so far (mGBA, viewport = whole frame, game size = frame
size) every v1.1 message means the same in v1.2.

## Transport

- TCP on `127.0.0.1`, default port 47900 (`--port`). Up to 16 clients at a time; one more gets an
  error (-32600) and is closed. Each connection has its own probes, templates and frames, and every
  method is served to every connection except input, which needs the input lease (below).
  When a client disconnects, the daemon drops its probes and templates, and its queued commands
  when it held the lease.
- One JSON object per line, LF-terminated, UTF-8, no embedded newlines.
- Requests have an `id`; the daemon answers each with exactly one `result` or `error`.
  Notifications (`frame`, `batch_done`, `stop`; `watch.plan`, `watch.log` and `watch.run` from the
  client)
  have no `id`.
- Responses do not name their method: JSON-RPC 2.0 ties a response to its request by `id`, and the
  client already holds each pending request by id, so a method name in the result would only repeat
  it (and could disagree with it).

## Clock and frames

- `seq`: frame number from the backend. On mGBA it is the emulator frame (`emu:currentFrame()`).
  It only grows, except across `backend.load_state`, whose reply gives the new `seq`.
- `load`: how many `backend.load_state` calls have succeeded since the daemon started (0 before the
  first). Every `frame` carries the `load` it was taken under, and the `backend.load_state` reply gives
  the new one. A client ignores frames whose `load` is older than the last reply's: they were in flight
  before the load and show another state.
- `t_ms`: milliseconds (float) since the daemon started. On a live backend (the Switch) and in
  `status`, the lease and the wire log's own `t_ms` it is the daemon's monotonic clock. On a lockstep
  backend (mGBA), `frame` and `batch_done` carry game time: the daemon clock when it started plus
  the frames stepped since, at the backend's `frame_rate`. The daemon steps the emulator at
  `--speed` times that rate (1 by default), so game time runs that many times as fast as the daemon
  clock, and stops while the emulator does. A client times its waits and timeouts on `frame` `t_ms`
  and so means game time at every speed; presses and `wait_ms` are frames already (below).

## Methods

| Method | Params | Result |
|---|---|---|
| `hello` | `protocol` (must be 1), `client` | `protocol`, `daemon`, `backend` {`kind`, `game_code`, `frame_rate`, `width`, `height`, `viewport`, `game_size`}, `probe_kinds` |
| `backend.load_state` | `path` (a save state file; the daemon passes it to the backend unread) | `seq` after loading, the new `load` |
| `probe.upload_template` | `png`: a PNG file, base64 | `template`: the lowercase hex SHA-256 of the PNG bytes |
| `subscribe` | `probes`: list of {`id`, `kind`, `box`, `delivery`, and `template` (and optionally `ink`) for `core.template_match@1`, `min` and `max` for `core.color_count@1`, `test` for `core.line_shares@1`, `filters`, `min_area` and the optional `max_area`, `min_size`, `max_size`, `margin`, `template`, `shape`, `masked` for `core.find@1`} | `subscribed`: ids |
| `unsubscribe` | `ids`: probe ids | `unsubscribed`: the ids that were subscribed, now removed (others are ignored) |
| `submit` | `batch_id`, `commands`: list of {`press`: buttons, optional `left_stick` and `right_stick`, `hold_ms`, `cooldown_ms`} or {`wait_ms`} | `batch_id`, `start_seq` |
| `cancel` | {} or {`then`: {`batch_id`, `commands`}} | `released_seq`: drops queued commands and releases all buttons; with `then` (v1.15), releases none and runs that batch in their place, its `batch_done` as a submit's |
| `status` | {} | `t_ms`, `backend` (its `kind`), `client` (the lease holder's `hello` name, else the oldest connection's, or `null`), `clients` (connections now), `lease` (below, or `null`), `fidelity`, `threads`, `ring`, `gaps` (below) |
| `lease.acquire` | `owner` (a label for people), optional `ttl_ms` (default 60000) | `lease` {`owner`, `client`, `held_ms`, `ttl_ms`} |
| `lease.release` | {} | `released`: whether this connection held it |

- `width`, `height`: the frame's size in pixels. `viewport` {`x`, `y`, `w`, `h`}: where the game
  picture sits in the frame, normalized to the frame. `game_size` {`width`, `height`}: the picture's
  native size in game pixels (240x160 on the GBA). On mGBA the frame is the picture (viewport 0, 0,
  1, 1); a capture card frame has it inside side bars (a Switch backend will take it from a daemon
  flag, by default the fork's FRLG `GAME_BOX`).
- `box` is normalized to the game picture: `x`, `y`, `w`, `h` in 0..1 of the viewport. The daemon
  maps it onto the frame, so a reader's boxes are the same on every backend.
- `template`: the hash `probe.upload_template` returned on this connection; an unknown hash is
  -32602. Uploads last until the client disconnects. Uploading the same bytes again returns the same
  hash, so a client keeps its own bytes-to-hash table per connection and uploads each template once.
  Uploading is its own method rather than a field of `subscribe` so that the daemon computes the hash
  (CoreLib's SHA-256) and the client needs no hash code, and so a subscribe stays small.
- `delivery`: `every` (one result per frame, a gap is an error) or `latest`.
- A probe stays subscribed until `unsubscribe` names it or the client disconnects; subscribing its id
  again replaces it. Each probe costs time on every frame, so a reader unsubscribes the probes it no
  longer reads.
- Buttons (GBA): `A`, `B`, `Select`, `Start`, `Right`, `Left`, `Up`, `Down`, `R`, `L`.
  The Switch only: `Home`, `X`, `Y`, `ZL`, `ZR` (`42-submit.home.request.json`). A press of one on another
  backend is refused, as a whole batch, with -32602 and `data` {`backend`, `button`}: mGBA and the
  view backend have no such button (the view backend refuses every input anyway, -32002).
- Sticks (the Switch only, `44-submit.sticks.request.json`): `left_stick` and `right_stick` are each
  `[x, y]`, numbers in -1..1, as CoreLib's `JoystickPosition`: +x is right, +y is up, `[0, 0]`
  centred; a value outside -1..1 is -32602. A stick left out is centred. A press tilts its sticks
  for `hold_ms` together with its buttons, and its cooldown centres them and releases the buttons;
  `press` may then be empty (`[]`), a tilt alone. A cooldown of 0 chains the next press straight
  on, as the C++'s release 0 does: a run is B with the left stick, then the next heading with B.
  The daemon turns a tilt into the Pro Controller's report as the C++ does (`encode_joystick`,
  `daemon/src/switch_controller.h`): a tilt inside the unit circle is scaled onto the range the
  console registers, one on or past it is pushed out to full. Headings in degrees and how fast to
  run are the game's, not the wire's.
  mGBA refuses a press that names a stick, as a whole batch, with -32602 and `data` {`backend`,
  `stick`} (the first one named): the GBA has no stick, and a press that silently dropped its tilt
  would report a walk that never happened. The view backend refuses every input (-32002).
- Batches run in order, one after another. Times are rounded to whole frames by the backend.
- `backend.load_state` also drops queued commands and releases all buttons, as `cancel` does;
  queued batches then get no `batch_done`.

`status` (`29-status.response.json`):

- `threads`: one heartbeat per daemon thread, {`name`, `seq`, `t_ms`}: the last frame it handled and
  when it last showed life. mGBA has one thread, `server` (it steps and probes each frame). The Switch
  has `capture` (`seq`, `t_ms`: the last frame captured) and `server` (`seq`: the last frame probed,
  `t_ms`: its last loop pass, at least every 50 ms). A thread whose `t_ms` is far behind the reply's
  `t_ms` is stuck; the daemon reports and the reader judges (`gamepilot status` states its limits).
- `ring` {`depth`, `capacity`}: frames captured and not yet probed (0, 0 on mGBA).
- `gaps` {`count`, `frames`}: jumps in `seq` the server saw because the ring was full, and the frames
  lost in them.
- `fidelity`: `full` while an `every` probe is subscribed, else `latest`. Thread priority does not
  follow it yet.

## Input lease

`submit`, `cancel` and `backend.load_state` need the input lease; everything else (status,
subscribe and frames, templates, saves) needs none, so any number of clients watch while one
drives (`daemon/src/input_lease.h`).

- A connection takes the free lease with `lease.acquire` (`35`, `36`) or implicitly with its first
  input, owned then by its `hello` name with the default ttl. Every input and every
  `lease.acquire` by the holder renews it; an acquire also sets a new owner and ttl.
- Input or an acquire from anyone else gets error -32004 `input lease held by OWNER`, whose `data`
  is the lease: `owner`, `client` (the holder's `hello` name), `held_ms` (since it took it),
  `ttl_ms` (`39-error.lease_held.response.json`).
- The lease ends when its connection disconnects (its queued commands are dropped and buttons
  released), sends `lease.release` (`37`, `38`; queued commands run on), or sends no input for
  `ttl_ms`. Batches still queued or running count as input, so a program's long batch keeps it.
- Keep-awake never presses while a lease is held.
- `stop` (watch page) goes to every client; `batch_done` only to the one that submitted it.
- A `backend.save_frame` marks the recording's failure only from the holder, or with no holder.

## Live backends

The `switch` backend (`hello` `backend.kind`) is live: the capture card is not paused. `seq` counts
captured frames from 1, and `t_ms` of a `frame` is when the frame was captured. Commands are timed in
wall time: a batch starts when submitted (or when the queued ones end), each press and wait runs for
its milliseconds as given, without rounding to frames, and `start_seq` is the last frame captured
when it was submitted. `backend.load_state` and `backend.save_state` answer -32002 (a console has
no save states). The game picture sits inside the frame (`viewport`, by default the fork's FRLG
`GAME_BOX`); GBA buttons map to the Switch's GBA app: Start is Plus, Select is Minus; `Home`, `X`
and `Y` are the controller's own, and so are `left_stick` and `right_stick`.

The `view` backend is live too, and view-only: its frames come from a picture another program owns
(an app's window), cropped to the video, so `viewport` is the whole frame and `game_size` the
frame's size. It takes no input: `submit`, `cancel`, `backend.load_state` and `lease.acquire` answer
-32002 with `data` {`backend`, `method`} (`41-error.view_only.response.json`); reads, probes and
`status` work as on any backend. No new message: a client that never drives one needs no change.

## Notifications

- `frame`: `seq`, `load`, `t_ms`, `probes` {id: result}. One per frame while any probe is subscribed,
  also when `probes` is empty.
  `probes` holds only the results that changed since this client's previous frame
  (`23-frame.changed_only.notification.json`): a result is left out when its JSON, as sent (rounded as
  below), equals the last one sent for that probe id. The first frame after a `subscribe`, a
  successful `backend.load_state` or a new connection carries every subscribed probe's result, so a
  reader starting at one of those points needs no earlier frame. A re-subscribed id is always sent
  again (every `subscribe` starts over), and an unsubscribed id is forgotten.
  The client keeps the latest result per probe id and reads from that; both deliveries get the same
  frames, since an unchanged result is still that frame's result.
  Results are compared after the daemon's rounding: means and stddevs to 0.01, `fraction` and
  `score` to 1e-6, `x` and `y` to 1e-5. A deterministic backend (mGBA) gives the same pixels the same
  numbers, so a still screen sends nothing; the rounding is not coarsened for this, because a probe
  whose numbers change does so because its pixels did.
- `batch_done`: `batch_id`, `seq`, `t_ms` once the batch's last command (including its cooldown) ended.
- `stop`: `reason` (`32-stop.notification.json`). Someone pressed Stop on the watch page. The daemon
  has already dropped the queued commands and released every button (as `cancel` does; queued
  batches get no `batch_done`). The program ends at its next wait and may still make requests on its
  way out (save the failure frame and state, unsubscribe).

## Watch page

The program tells the daemon what only it knows, for the daemon's watch page
(`docs/design/Watch-Page.md`). Both are notifications from the client (no `id`, no answer), and the
daemon keeps them out of the wire log; without a watch page it drops them.

- `watch.plan`: `checkpoint`, `events`: list of {`id`, `state`, `detail`, `started_ms`?,
  `ended_ms`?} (`30-watch_plan.notification.json`). Every event of the running checkpoint, each time
  one changes. `state` is `pending`, `current`, `done`, `failed` or `skipped`; `detail` is a
  failure's reason, the flag a skip held on, or empty. `started_ms` is when the event last started
  and `ended_ms` when it ended, Unix time in milliseconds, each present once known: a pending event
  has neither, the current one only `started_ms`, a skipped one both, equal (it took no time). The
  page shows each finished event's time, the current one's so far and the checkpoint's total.
- `watch.log`: `line` (`31-watch_log.notification.json`): one story log line.
- `watch.run`: `mode`, `trial`, `trials`, `passes`, `fails`, `started_ms`, `checkpoints`: list of
  {`id`, `state`, `elapsed_ms`} (`33-watch_run.notification.json`). The chain the program runs
  (`gamepilot checkpoints --from --to`), sent at the start and the end of each run. `state` is
  `pending`, `current`, `passed`, `failed` or `skipped` (not run because an earlier one failed);
  `elapsed_ms` is the time spent on that checkpoint over all its runs, up to the message for the
  current one. `mode` is `testing` or `verification`; `trial` is the current checkpoint's run (1-based)
  out of the `trials` its policy allows, `passes` and `fails` its runs so far. `started_ms` is when the
  chain started, Unix time in milliseconds. The daemon keeps the latest, like the plan. Each run
  has its own daemon, so the program sends it again at every run's start.

## Probe kinds

Every probe result names its kind (`kind`, as subscribed) next to the fields below, so a client
decodes it by kind, not by shape.

| Kind | Result |
|---|---|
| `core.color_stats@1` | `mean` [r, g, b], `stddev` [r, g, b] over the box, 0..255 |
| `core.template_match@1` | `score`, `x`, `y`: the best placement of the template inside the box |
| `core.color_count@1` | `fraction`, `mean` [r, g, b] or `null`: the box's pixels inside a color range |
| `core.line_shares@1` | `rows`, `columns`: the share of each row's and each column's pixels passing a test |
| `core.find@1` | `blobs`: list of {`filter`, `x`, `y`, `w`, `h`, `fill`, and `stray`, `score`, `overlap` when asked} |

`core.template_match@1` takes the template in game pixels (a GBA tile is 8x8 whatever the capture).
The daemon scales it to the frame by the viewport's pixels per game pixel (each axis: viewport size in
frame pixels over `game_size`), then slides it over every placement fully inside the box (which must
be at least the scaled template's size, else subscribe fails with -32602). Scaling uses OpenCV
`INTER_AREA`: at scale 1 (mGBA) the template is used as uploaded, and at a whole scale (a 2x capture)
each game pixel becomes a block, as with nearest neighbour; at a fractional scale (6.5x for the
Switch's 1080p picture) nearest neighbour would push every seam between two game pixels to one side,
while `INTER_AREA` blends the one frame pixel a seam crosses by how much of it each game pixel covers,
which is what a scaled capture shows there; and it averages, not samples, when a capture is smaller
than the game.

`score` is the mean squared difference per pixel and channel at the best placement, divided by 255²:
0 for identical pixels, 1 when every channel is as far off as it can be (OpenCV `TM_SQDIFF` /
(w·h·3·255²)). Lower is better; there is no threshold in the daemon. `x`, `y` are the top-left corner
of that placement, normalized to the game picture. The PNG is read as 8-bit RGB; an alpha channel is
ignored. Plain `TM_SQDIFF_NORMED` is not used: it divides by the template's energy, so a flat dark
template (a black text box) scores 1 on an exact match.

`ink` {`min`, `max`}, each [r, g, b] integers 0..255 with `min` <= `max` per channel, makes the probe
compare masks instead of colors: the daemon replaces the template (in game pixels, before scaling) and
the box by their masks, 255 where every channel lies in `min`..`max` (both ends included) and 0
elsewhere, and scores as above with one channel. With whole pixels (mGBA) `score` is then the fraction
of the template's pixels whose mask differs; at a fractional scale a seam pixel of the scaled mask is
between 0 and 255 and counts by its squared difference. A text reader sets `ink` to the range of its
text color, so the same drawn word matches gray, blue or shaded text on any background.
`ink` is an option rather than a kind of its own because the result, its fields and the score's formula
stay the same; only the pixels compared change.

`core.color_count@1` takes `min` and `max`, [r, g, b] integers 0..255 with `min` <= `max` per
channel (else -32602), and counts the box's pixels whose every channel lies in `min`..`max`, both
ends included. `fraction` is that count over the box's pixel count (0..1). `mean` is the per-channel
mean of those pixels, 0..255, and `null` (present, not omitted) when no pixel is in range, so every
result has the same fields. Like the other kinds it has no threshold: the reader decides from the
numbers (the fork's advance arrow: `mean` red far above green and blue).

`core.line_shares@1` takes `test`, a non-empty list of comparisons {`weights`: [r, g, b] integers,
`op`: `>`, `>=`, `<` or `<=`, `value`: an integer}; a pixel passes when every comparison
`weights[0]·r + weights[1]·g + weights[2]·b op value` holds (else -32602 for a bad one). `rows` holds
one share per frame row of the box, top to bottom (the pixels passing over the row's width), and
`columns` one per frame column, left to right; both rounded to 1e-6. These are the fork's PLZA
PixelShares tests (`PokemonLZA_PixelShares.cpp`, `PokemonLZA_ControlsHintDetector.cpp`), which compare
channels with each other (sky blue is b > 200, g > 160 and b > r + 60), so no `min`..`max` range can
say them. The fork slides each such box over a range of offsets one line at a time; one probe over
the whole range gives the share of every offset's box as the mean of its rows (a vertical slide) or
columns (a horizontal one), and the reader does the search and keeps the thresholds. Rows and columns
are frame pixels: at 1x (mGBA, the native Switch viewport) they are game pixels.

`core.find@1` runs a fixed pipeline over the box: per range of `filters` (a non-empty list of
{`min`, `max`}, each [r, g, b] as for `core.color_count@1`) a mask of the pixels in it, then its
4-connected blobs (the fork's waterfill fills left, right, up and down), then a size filter, then
the scores asked for. It mirrors `match_template_by_waterfill` (`CommonTools/Images/
WaterfillUtilities.cpp`) and `WaterfillTemplateMatcher` with `ExactImageMatcher`
(`CommonTools/ImageMatch/`). Sizes are in game pixels, as the fork's are in 1080p pixels:
`min_area` (at least 1) and `max_area` bound a blob's pixels, scaled to the frame by both axes' frame
pixels per game pixel and truncated, as the fork scales by the frame's height over 1080; `min_size`
and `max_size`, [w, h], bound its box, both ends included. Every blob that passes is reported, in
filter order, so a reader filters by size to keep the list short.

- `filter`: the index of the range that made the blob. `x`, `y`, `w`, `h`: its bounding box in game
  pixels of the picture (not normalized: the fork's size tests are in pixels, and a fraction would
  round a 26-pixel width to 25.99), rounded to 1e-3. `fill`: its pixels over its box's
  (`WaterfillObject::area_ratio`).
- `margin` (game pixels, scaled by the height and rounded): `stray`, the filter's pixels within
  that margin around the blob's box (inside the probe's box) that are not the blob's, over the blob's
  pixels (AdvanceArrowDetector's stray share, `PokemonLZA_StoryDialogDetector.cpp`).
- `template` (a hash from `probe.upload_template`): `score`, `ExactImageMatcher::rmsd` of the blob's
  box (all its pixels, not just the blob's) against the template, rounded to 1e-3. The box is resized
  to the template's size (nearest neighbour at pixel centres, as the fork's Qt `scaled()`), the
  template's colours scaled per channel by the ratio of the box's mean to the template's over the
  template's opaque pixels (alpha 128 or more; the ratio kept in 0.85..1.15), and the score is the
  square root of the mean over those pixels of the summed squared channel differences: 0 for
  identical pixels, at most 441.7, lower is better. The template is used as uploaded, alpha
  included, at its own size: upload the fork's template already cut to its largest blob, as
  `WaterfillTemplateMatcher` cuts it. The fork's aspect and area-ratio gates are the reader's, from
  `w`, `h` and `fill`.
- `masked` (v1.15, a boolean, default `false`): with `true`, the `score` is of the blob's box with
  every pixel outside the filter's range black, as the fork's `filter_by_mask` before
  MoveEffectivenessSymbol's match.
- `shape` (a hash): `overlap`, the blob's pixels against the shape's opaque pixels (alpha 128 or
  more) sampled at the centres of the blob's box's pixels: pixels in both over pixels in either.
  AdvanceArrowDetector tests the chevron by this overlap with a V (`v_match`), a test of the blob's
  own pixels that a colour score cannot make; the reader uploads the V drawn large, and the overlap
  then equals the fork's to the shape's resolution.

There is no black-screen kind: `core.color_stats@1` gives the mean and stddev over a box, and a
reader decides "black" from those numbers (low mean, low stddev) in OCaml.

## Errors

| Code | Meaning |
|---|---|
| -32700 / -32600 / -32601 / -32602 | JSON-RPC parse error / invalid request / unknown method / bad params |
| -32001 | unknown probe kind (`data.kind`) |
| -32002 | backend error (`data.detail`), e.g. load failed |
| -32003 | protocol version mismatch |

## Wire log

The daemon writes every message it sends or receives, except the client's `watch.plan`,
`watch.log` and `watch.run`, one per line (`14-wire_log.line.json`):
`dir` (`in` = from the client, `out` = to the client), `t_ms`, `conn` (the connection's number,
from 1 in the order they came), `msg` (the message as sent, so a press's sticks are on its line);
an input line also has `owner`, the lease's owner
(`40-wire_log.input_owner.line.json`). Replay reads this file and follows the program's
connection: the one of the log's first `in` line. A log from before v1.9 has no `conn`.
A `daemon` line is the daemon's own act, sent to no one: its keep-awake press, a `keepawake`
notification with the key and how long the console was idle (`34-keepawake.line.json`). Replay
skips it.
