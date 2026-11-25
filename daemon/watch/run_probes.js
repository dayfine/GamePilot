"use strict";

// --- Probe timeline -------------------------------------------------------------

let probeRows = [];

// A probe's value at daemon time `t`: its last point at or before it.
function valueAt(points, t) {
  let lo = 0, hi = points.length - 1, found = -1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (points[mid][0] <= t) { found = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return found < 0 ? null : points[found][1];
}

const toDaemon = (t) => data.zero !== null ? t - data.zero : t;
const fromDaemon = (t) => data.zero !== null ? t + data.zero : t;

// A run may have thousands of probes (template matches that ran once): the
// first MAX_PROBE_ROWS that match the filter get a row, busiest first.
const MAX_PROBE_ROWS = 60;
let probeIds = [];

function buildTimeline() {
  const probes = data.probes ? data.probes.probes : {};
  // The busiest first: a probe that changed often says more than one that
  // ran once.
  probeIds = Object.keys(probes).sort((a, b) =>
    probes[b].points.length - probes[a].points.length || (a < b ? -1 : 1));
  filterTimeline();
}

function probeRow(id, probe) {
  const row = el("div", "probe");
  const canvas = el("canvas");
  const value = el("span", "v");
  row.append(el("span", "pid", id), canvas, value);
  row.title = id + " (" + probe.kind + ")";
  canvas.addEventListener("click", (e) => {
    const r = canvas.getBoundingClientRect();
    seek(t0 + (e.clientX - r.left) / r.width * (t1 - t0));
  });
  return {id, row, canvas, value, points: probe.points};
}

function filterTimeline() {
  const filter = $("probe-filter").value.trim();
  try { localStorage.setItem("run.probeFilter", filter); } catch (e) {}
  const box = $("timeline");
  box.replaceChildren();
  const ids = probeIds.filter((id) => !filter || id.includes(filter));
  probeRows = ids.slice(0, MAX_PROBE_ROWS).map((id) => probeRow(id, data.probes.probes[id]));
  for (const p of probeRows) box.append(p.row);
  if (!probeIds.length) {
    box.append(el("div", "note", data.probes ? "no probe values in this run's wire log" : ""));
  } else if (ids.length > MAX_PROBE_ROWS) {
    box.append(el("div", "note", (ids.length - MAX_PROBE_ROWS) + " more probes: filter by name"));
  } else if (!ids.length) {
    box.append(el("div", "note", "no probe matches the filter"));
  }
  drawTimeline();
}
$("probe-filter").addEventListener("input", filterTimeline);

function drawTimeline() {
  const css = getComputedStyle(document.documentElement);
  const spark = css.getPropertyValue("--spark").trim();
  const cursor = css.getPropertyValue("--bad").trim();
  const span = Math.max(1, t1 - t0);
  for (const p of probeRows) {
    const c = p.canvas;
    const w = c.clientWidth, h = c.clientHeight, dpr = window.devicePixelRatio || 1;
    if (!w) continue;
    if (c.width !== Math.round(w * dpr)) { c.width = Math.round(w * dpr); c.height = Math.round(h * dpr); }
    const ctx = c.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    let lo = Infinity, hi = -Infinity;
    for (const [, v] of p.points) { lo = Math.min(lo, v); hi = Math.max(hi, v); }
    const range = hi - lo || 1;
    ctx.strokeStyle = spark;
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    let prevY = null;
    for (const [t, v] of p.points) {
      const x = (fromDaemon(t) - t0) / span * w;
      const y = h - 2 - (v - lo) / range * (h - 4);
      if (prevY === null) ctx.moveTo(x, y); else { ctx.lineTo(x, prevY); ctx.lineTo(x, y); }
      prevY = y;
    }
    if (prevY !== null) ctx.lineTo(w, prevY);
    ctx.stroke();
    const x = (now - t0) / span * w;
    ctx.fillStyle = cursor;
    ctx.fillRect(Math.round(x), 0, 1, h);
    const v = valueAt(p.points, toDaemon(now));
    p.value.textContent = v === null ? "–" : String(v);
  }
}
window.addEventListener("resize", () => drawTimeline());
