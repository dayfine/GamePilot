# Wire protocol v1.3

JSON-RPC 2.0 between the OCaml programs (client) and the daemon (server). The golden files in this
folder are the spec: the daemon's tests parse every file and the OCaml tests decode and re-encode
every file. Change a file here first, then both sides.
The golden files are pretty-printed for reading (`tools/fmt_json.py`); on the wire each message is
one line.

v1.1 adds the `load` counter to `frame` and `backend.load_state`, and a `kind` to every probe result.
Template probes (`probe.upload_template`, `core.template_match@1`) came later under the same number.
v1.3 adds `unsubscribe` and the optional `ink` of `core.template_match@1`.
v1.2 makes the daemon own where the game picture sits in the frame: `hello` gives the `viewport` and
the `game_size`, probe boxes and template placements are relative to the picture, templates are in game
pixels, and `core.color_count@1` is new.
`hello` still says `protocol: 1`: both sides ship from this repo at one commit, so there is no older
peer to tell apart, and on the only backend so far (mGBA, viewport = whole frame, game size = frame
size) every v1.1 message means the same in v1.2.

## Transport

- TCP on `127.0.0.1`, default port 47900 (`--port`). One client at a time; a second gets an error and
  is closed.
  When the client disconnects, the daemon drops its probes and queued commands.
- One JSON object per line, LF-terminated, UTF-8, no embedded newlines.
- Requests have an `id`; the daemon answers each with exactly one `result` or `error`.
  Notifications (`frame`, `batch_done`) have no `id`.
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
- `t_ms`: daemon monotonic clock in milliseconds since the daemon started (float).

## Methods

| Method | Params | Result |
|---|---|---|
| `hello` | `protocol` (must be 1), `client` | `protocol`, `daemon`, `backend` {`kind`, `game_code`, `frame_rate`, `width`, `height`, `viewport`, `game_size`}, `probe_kinds` |
| `backend.load_state` | `path` (a save state file; the daemon passes it to the backend unread) | `seq` after loading, the new `load` |
| `probe.upload_template` | `png`: a PNG file, base64 | `template`: the lowercase hex SHA-256 of the PNG bytes |
| `subscribe` | `probes`: list of {`id`, `kind`, `box`, `delivery`, and `template` (and optionally `ink`) for `core.template_match@1`, `min` and `max` for `core.color_count@1`} | `subscribed`: ids |
| `unsubscribe` | `ids`: probe ids | `unsubscribed`: the ids that were subscribed, now removed (others are ignored) |
| `submit` | `batch_id`, `commands`: list of {`press`: buttons, `hold_ms`, `cooldown_ms`} or {`wait_ms`} | `batch_id`, `start_seq` |
| `cancel` | {} | `released_seq`: drops queued commands and releases all buttons |

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
- Batches run in order, one after another. Times are rounded to whole frames by the backend.
- `backend.load_state` also drops queued commands and releases all buttons, as `cancel` does;
  queued batches then get no `batch_done`.

## Notifications

- `frame`: `seq`, `load`, `t_ms`, `probes` {id: result}. One per frame while any probe is subscribed.
- `batch_done`: `batch_id`, `seq`, `t_ms` once the batch's last command (including its cooldown) ended.

## Probe kinds

Every probe result names its kind (`kind`, as subscribed) next to the fields below, so a client
decodes it by kind, not by shape.

| Kind | Result |
|---|---|
| `core.color_stats@1` | `mean` [r, g, b], `stddev` [r, g, b] over the box, 0..255 |
| `core.template_match@1` | `score`, `x`, `y`: the best placement of the template inside the box |
| `core.color_count@1` | `fraction`, `mean` [r, g, b] or `null`: the box's pixels inside a color range |

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

The daemon writes every message it sends or receives, one per line (`14-wire_log.line.json`):
`dir` (`in` = from the client, `out` = to the client), `t_ms`, `msg`. Replay reads this file.
