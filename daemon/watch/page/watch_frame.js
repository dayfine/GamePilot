"use strict";

// --- Frame and probe boxes ---------------------------------------------------
//
// The frame is an <img> sized by CSS from the backend's frame size (a GBA
// frame pixelated, at a whole multiple when it fits; the image the stream
// sends is twice the GBA's size, so every whole multiple stays sharp); the boxes and labels go on a canvas over it at
// the displayed size, so text stays sharp. Mode: off, changed (probes whose
// value changed in the last second) or all; a label shows only for the box
// under the pointer (or tapped), and the table lists every value.

const CHANGED_MS = 1000;
const MODES = ["off", "changed", "all"];
const overlay = $("overlay");
const octx = overlay.getContext("2d");
let mode = "changed";
try { const m = localStorage.getItem("watch.mode"); if (MODES.includes(m)) mode = m; } catch (e) {}
const changedAt = new Map();   // probe id -> time its label last changed
const lastLabel = new Map();   // probe id -> its last label
let hovered = null;            // probe id under the pointer or row
let pinned = null;             // probe id tapped
let scale = 1;                 // displayed pixels per frame pixel

const recent = (id) => performance.now() - (changedAt.get(id) || -1e9) < CHANGED_MS;
const filterText = () => $("probe-filter").value.trim();
const matches = (p) => p.id.startsWith(filterText());

function setMode(m) {
  mode = m;
  try { localStorage.setItem("watch.mode", m); } catch (e) {}
  for (const b of document.querySelectorAll(".modes button")) {
    b.setAttribute("aria-pressed", String(b.dataset.mode === m));
  }
  drawOverlay();
}

function takeProbes(list) {
  const now = performance.now();
  for (const p of list) {
    const label = resultLabel(p.result);
    if (lastLabel.has(p.id) && lastLabel.get(p.id) !== label) changedAt.set(p.id, now);
    lastLabel.set(p.id, label);
  }
  probes = list;
  const prefixes = new Set(list.map((p) => p.id.split(".")[0] + "."));
  const options = $("probe-prefixes");
  if (options.childElementCount !== prefixes.size) {
    options.replaceChildren(...[...prefixes].sort().map((x) => { const o = el("option"); o.value = x; return o; }));
  }
  renderProbeTable();
  drawOverlay();
  showFrameMeta();
}

function resultLabel(r) {
  if (!r) return "";
  const f = (x, d) => Number(x).toFixed(d);
  switch (r.kind) {
    case "core.color_stats@1":
      return "μ " + r.mean.map((x) => f(x, 0)).join(",") + " σ " +
             f((r.stddev[0] + r.stddev[1] + r.stddev[2]) / 3, 1);
    case "core.template_match@1":
      return "score " + f(r.score, 3);
    case "core.color_count@1":
      return "frac " + f(r.fraction, 3);
    default:
      return r.kind || "";
  }
}

function renderProbeTable() {
  const body = el("tbody");
  for (const p of probes.filter(matches)) {
    const tr = el("tr", p.id === hovered || p.id === pinned ? "hot" : "");
    tr.append(el("td", "chg", recent(p.id) ? "●" : ""), el("td", "pid", p.id),
              el("td", "val", lastLabel.get(p.id) || ""));
    tr.addEventListener("mouseenter", () => { hovered = p.id; drawOverlay(); });
    tr.addEventListener("mouseleave", () => { hovered = null; drawOverlay(); });
    body.append(tr);
  }
  if (!body.childElementCount) {
    body.append(row([[probes.length ? "no probe matches the filter" : "no probes subscribed", "empty"]]));
  }
  $("probe-table").replaceChildren(body);
}

// A probe's box in displayed pixels.
function boxRect(p, W, H) {
  const vp = (info && info.backend && info.backend.viewport) || {x: 0, y: 0, w: 1, h: 1};
  return {x: (vp.x + p.box.x * vp.w) * W * scale, y: (vp.y + p.box.y * vp.h) * H * scale,
          w: p.box.w * vp.w * W * scale, h: p.box.h * vp.h * H * scale};
}

// The whole multiple of the frame that fits the panel's width and 70% of the
// window's height, or a fraction when even 1x does not.
// The height is read once: a phone's window height changes as its address bar
// shows and hides, which resized the frame and shifted the page under the reader.
const stableHeight = window.innerHeight;
function fitScale(w, h) {
  const s = Math.min($("stage-wrap").clientWidth / w, stableHeight * 0.7 / h);
  return s >= 1 ? Math.floor(s) : s;
}

function layoutFrame() {
  scale = fitScale(frameW, frameH);
  screen.style.width = frameW * scale + "px";
  screen.style.height = frameH * scale + "px";
  $("stage").classList.toggle("pixel", frameW <= 320);
  drawOverlay();
  showFrameMeta();
}

function drawOverlay() {
  const W = frameW, H = frameH;
  const dw = W * scale, dh = H * scale, dpr = window.devicePixelRatio || 1;
  if (overlay.width !== Math.round(dw * dpr) || overlay.height !== Math.round(dh * dpr)) {
    overlay.width = Math.round(dw * dpr);
    overlay.height = Math.round(dh * dpr);
  }
  octx.setTransform(dpr, 0, 0, dpr, 0, 0);
  octx.clearRect(0, 0, dw, dh);
  const color = getComputedStyle(document.documentElement).getPropertyValue("--box").trim();
  const focus = hovered || pinned;
  const shown = probes.filter((p) => p.id === focus ||
    (mode !== "off" && matches(p) && (mode === "all" || recent(p.id))));
  octx.lineWidth = 1.5;
  for (const p of shown) {
    const r = boxRect(p, W, H);
    octx.strokeStyle = p.id === focus ? "#ffffff" : color;
    octx.globalAlpha = p.id === focus || recent(p.id) ? 1 : 0.55;
    octx.strokeRect(r.x + 0.75, r.y + 0.75, Math.max(1, r.w - 1.5), Math.max(1, r.h - 1.5));
  }
  octx.globalAlpha = 1;
  const p = probes.find((q) => q.id === focus);
  if (!p) return;
  const r = boxRect(p, W, H);
  const text = p.id + "  " + (lastLabel.get(p.id) || "");
  octx.font = "12px ui-monospace, Menlo, Consolas, monospace";
  octx.textBaseline = "middle";
  const tw = octx.measureText(text).width + 8, th = 18;
  const ty = r.y >= th + 2 ? r.y - th - 2 : Math.min(dh - th, r.y + r.h + 2);
  const tx = Math.max(0, Math.min(r.x, dw - tw));
  octx.fillStyle = "rgba(0,0,0,0.8)";
  octx.fillRect(tx, ty, tw, th);
  octx.fillStyle = color;
  octx.fillText(text, tx + 4, ty + th / 2);
}

// The smallest shown box under a point (in displayed pixels).
function probeAt(x, y) {
  let best = null, bestArea = Infinity;
  for (const p of probes) {
    if (!matches(p) || mode === "off" || (mode === "changed" && !recent(p.id))) continue;
    const r = boxRect(p, frameW, frameH);
    if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h && r.w * r.h < bestArea) {
      best = p.id; bestArea = r.w * r.h;
    }
  }
  return best;
}

function pointer(e) {
  const b = overlay.getBoundingClientRect();
  return probeAt(e.clientX - b.left, e.clientY - b.top);
}
overlay.addEventListener("mousemove", (e) => {
  const id = pointer(e);
  if (id !== hovered) { hovered = id; drawOverlay(); renderProbeTable(); }
});
overlay.addEventListener("mouseleave", () => { hovered = null; drawOverlay(); renderProbeTable(); });
overlay.addEventListener("click", (e) => {
  const id = pointer(e);
  pinned = id === pinned ? null : id;
  drawOverlay();
  renderProbeTable();
});
for (const b of document.querySelectorAll(".modes button")) {
  b.addEventListener("click", () => setMode(b.dataset.mode));
}
$("probe-filter").addEventListener("input", () => { renderProbeTable(); drawOverlay(); });
window.addEventListener("resize", layoutFrame);
setMode(mode);

// The frame's source: "stream" (MJPEG on the <img>), "poll" (/frame after
// the stream failed) or "off" (the tab is hidden: nothing is fetched).
let source = "off";
let pollTimer = 0, retryTimer = 0;

function streamUrl() {
  const width = window.innerWidth < PHONE_WIDTH ? 960 : 1280;
  return "stream?w=" + width + "&t=" + Date.now();
}

function setSource(next) {
  source = next;
  clearTimeout(pollTimer);
  clearTimeout(retryTimer);
  if (next === "stream") {
    screen.src = streamUrl();
  } else if (next === "poll") {
    pollTimer = setTimeout(pollFrame, FRAME_MS);
    retryTimer = setTimeout(() => setSource("stream"), STREAM_RETRY_MS);
  } else {
    screen.removeAttribute("src");  // closes the stream
  }
  showFrameMeta();
}

function pollFrame() {
  if (source === "poll") screen.src = "frame?t=" + Date.now();
}

// A polled frame asks for the next; the stream fires this once, at its first
// part.
screen.addEventListener("load", () => {
  if (source === "poll") pollTimer = setTimeout(pollFrame, FRAME_MS);
});
screen.addEventListener("error", () => {
  if (source === "stream") setSource("poll");
  else if (source === "poll") pollTimer = setTimeout(pollFrame, 1000);
});
document.addEventListener("visibilitychange", () => {
  // A run that ended behind the hub has no stream any more.
  setSource(document.hidden || (viaHub && endedShown) ? "off" : "stream");
});

function showFrameMeta() {
  const how = source === "stream" ? "live (MJPEG)" :
              source === "poll" ? "polled (stream failed, retrying)" : "paused";
  $("frame-meta-text").textContent = frameW + "×" + frameH + " " + how + " · shown at " +
    (Number.isInteger(scale) ? scale + "×" : scale.toFixed(2) + "×") +
    (info ? " · " + info.backend.kind : "") + " · " + probes.length + " probes";
}

// Changed marks fade with time, not only with new probe results.
setInterval(() => {
  if (document.hidden) return;
  renderProbeTable();
  drawOverlay();
}, FRAME_MS);
