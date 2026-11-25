"use strict";

// The page's settings, its shared state and the element helper.

// The daemon's limit: a thread whose heartbeat is older than this is stuck
// (the same rule as `gamepilot status`).
const STUCK_MS = 2000;
// Polling /frame (when the stream fails): at most this often; the daemon caps
// it too. The stream is tried again after STREAM_RETRY_MS.
const FRAME_MS = 200;
const STREAM_RETRY_MS = 15000;
// Narrower windows than this (phones) ask for a 960 px stream, else 1280.
const PHONE_WIDTH = 700;
const LOG_LINES = 2000;

const $ = (id) => document.getElementById(id);
// Stop's token: from the URL, else the one the daemon put in for this machine.
const TOKEN = new URLSearchParams(location.search).get("token") ||
  document.querySelector('meta[name="gamepilot-token"]').content;
// A series' page: /series/ID/ through the hub.
const viaSeries = location.pathname.match(/^(.*)\/series\/([^/]+)\/$/);
const SERIES_ID = viaSeries ? decodeURIComponent(viaSeries[2]) : null;
const screen = $("screen");
let info = null;          // the backend, as `hello` describes it
let probes = [];          // [{id, kind, box, result}]
// The backend's frame size: the layout and the boxes go by it, not by the
// image received (the stream's is scaled), so the frame keeps its size.
let frameW = 240, frameH = 160;
let lastPlan = null;
let lastLogLine = "";
let lastStatusAt = 0;

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}
