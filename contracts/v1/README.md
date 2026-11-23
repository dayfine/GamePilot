# Wire protocol v1

JSON-RPC 2.0 between the OCaml programs (client) and the daemon (server). The golden files in this
folder are the spec: the daemon's tests parse every file and the OCaml tests decode and re-encode
every file. Change a file here first, then both sides.

## Transport

- TCP on `127.0.0.1`, default port 47900 (`--port`). One client at a time; a second gets an error and
  is closed.
- One JSON object per line, LF-terminated, UTF-8, no embedded newlines.
- Requests have an `id`; the daemon answers each with exactly one `result` or `error`.
  Notifications (`frame`, `batch_done`) have no `id`.

## Clock and frames

- `seq`: frame number from the backend. On mGBA it is the emulator frame (`emu:currentFrame()`).
  It only grows, except across `backend.load_state`, whose reply gives the new `seq`.
- `t_ms`: daemon monotonic clock in milliseconds since the daemon started (float).

## Methods

| Method | Params | Result |
|---|---|---|
| `hello` | `protocol` (must be 1), `client` | `protocol`, `daemon`, `backend` {`kind`, `game_code`, `frame_rate`, `width`, `height`}, `probe_kinds` |
| `backend.load_state` | `path` (a save state file; the daemon passes it to the backend unread) | `seq` after loading |
| `subscribe` | `probes`: list of {`id`, `kind`, `box`, `delivery`} | `subscribed`: ids |
| `submit` | `batch_id`, `commands`: list of {`press`: buttons, `hold_ms`, `cooldown_ms`} or {`wait_ms`} | `batch_id`, `start_seq` |
| `cancel` | {} | `released_seq`: drops queued commands and releases all buttons |

- `box` is normalized to the frame: `x`, `y`, `w`, `h` in 0..1.
- `delivery`: `every` (one result per frame, a gap is an error) or `latest`.
- Buttons (GBA): `A`, `B`, `Select`, `Start`, `Right`, `Left`, `Up`, `Down`, `R`, `L`.
- Batches run in order, one after another. Times are rounded to whole frames by the backend.

## Notifications

- `frame`: `seq`, `t_ms`, `probes` {id: result}. One per frame while any probe is subscribed.
- `batch_done`: `batch_id`, `seq`, `t_ms` once the batch's last command (including its cooldown) ended.

## Probe kinds

| Kind | Result |
|---|---|
| `core.color_stats@1` | `mean` [r, g, b], `stddev` [r, g, b] over the box, 0..255 |

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
