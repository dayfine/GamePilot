# Control UI (draft, 2026-11-23)

What a person sees and touches while GamePilot runs. Draft for discussion: the choices below are
recommendations, not decisions yet.

## What it is for

1. **Watch**: the console's video, live, with each subscribed probe's box drawn on it and its value
   next to it (what the reader sees, not just the picture).
2. **Follow a run**: which program, checkpoint and event is running, its log, pass/fail per
   checkpoint, the wire log as it grows.
3. **Take over**: a pad (buttons, D-pad, hold) under the hold lease (R14), so a person or an agent
   can drive by hand without racing a program.
4. **Debug after the fact**: open a recorded run, scrub through it frame by frame with the probe
   values and the program's decisions next to each frame.

Not in scope: editing programs, plans or maps (that stays in code and data files).

## Shape

```
browser (any OS)  ──HTTP/WebSocket──>  daemon  ──>  console / mGBA / recorded run
                                         ^
OCaml program  ──JSON-RPC (contracts)────┘
```

- **One web page, served by the daemon.** Static HTML/JS in `ui/`, no build step to start with. The
  browser is the only client that needs to run on the user's machine, so the UI works the same on
  macOS, Windows and Linux and from another device on the LAN.
- **Video goes through the daemon, not OBS.** The daemon already owns the capture device and decodes
  every frame for the probes; a capture card generally cannot be opened twice, so OBS cannot sit
  beside it. The daemon serves the frames it already has:
  - v1: MJPEG over HTTP (`multipart/x-mixed-replace`) at a reduced size and rate (for example 720p at
    30 frames/s for the Switch, native size for mGBA). A plain `<img>` shows it with about 100 ms of
    delay and no video code in the page.
  - Later, only if needed: WebRTC (H.264 plus audio) when audio monitoring or bandwidth matters.
  - OBS stays possible as a viewer: it can show the same stream as a browser or media source for
    recording or streaming, without owning the device.
- **Audio: later.** Nothing in the Mail Glitch needs it. When a program needs audio (shiny sound
  detection, as some Arduino-Source programs do), it comes in as a probe first, and the UI gets it
  over WebRTC at the same time.
- **Observing is read-only and separate from control.** An `observe` WebSocket streams what the
  wire log records (frames' probe results, submitted batches, batch_done, program status lines), so
  the UI never sits in the program's control path and can connect or disconnect at any time.
- **The pad goes through the lease.** Pressing a button takes the hold lease (the same one pa-lab's
  MCP tools use, R14); a running program is paused or refused while someone holds it. The UI shows
  who holds the lease.
- **Program status comes from the program.** A small `status` notification (program, checkpoint,
  event, free text) added to the contract lets the UI follow a run without parsing logs.
- **Scrubbing needs frames on disk.** The wire log has no images. An optional daemon flag records
  frames (JPEG, every frame or every Nth, keyed by `seq`) next to the wire log; the UI replays both.

## Order

1. Observe page: MJPEG video, probe boxes and values, wire events. Useful right away for building
   the FRLG readers (Phase 2). Built as the watch page (`Watch-Page.md`), with polled JPEG frames
   and Server-Sent Events instead of MJPEG and a WebSocket.
2. Run panel: the `status` notification and checkpoint results.
3. Pad and lease.
4. Recorded runs: frame recording and the scrubber.
5. WebRTC with audio, if a program needs it.

## Open questions

1. **Who serves the page and starts programs?** Recommendation: the daemon serves the page, the
   video and the observe stream (all I/O, which fits R7's glue-only rule); starting and stopping
   programs stays with the `gamepilot` command and pa-lab's MCP tools for now. A later
   `gamepilot serve` in OCaml could add a start button, but it needs an HTTP library on the opam
   allowlist.
2. **Plain JS or a framework?** Recommendation: plain HTML/JS until the page outgrows one file.
3. **LAN access**: localhost only by default; LAN only with an explicit flag, since the pad moves a
   real console.
