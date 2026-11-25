"use strict";

// --- Frames and the scrubber ----------------------------------------------------

function frameIndexAt(t) {
  const f = data.frames;
  let lo = 0, hi = f.length - 1, found = 0;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (f[mid].unix_ms <= t) { found = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return found;
}

let shownFrame = -1;
function showFrame() {
  if (!data.frames.length) return;
  const i = frameIndexAt(now);
  const f = data.frames[i];
  if (i !== shownFrame) {
    shownFrame = i;
    $("frame").src = "files/frames/" + f.file;
  }
  $("scrub-step").replaceChildren(el("b", "", f.step || "–"),
    " · frame " + (i + 1) + " of " + data.frames.length + (f.why !== "tick" ? " · " + f.why : ""));
}

function seek(t, opts) {
  now = Math.min(Math.max(t, t0), t1);
  const scrub = $("scrub");
  if (Number(scrub.value) !== Math.round(now - t0)) scrub.value = Math.round(now - t0);
  $("scrub-time").textContent = (data.zero !== null || data.frames.length ?
    clock(now) + " · " : "") + duration(now - t0) + " into the run";
  showFrame();
  markLog(!(opts && opts.fromLog));
  markPlan();
  drawTimeline();
}

function setRange() {
  const times = [];
  if (data.frames.length) times.push(data.frames[0].unix_ms, data.frames[data.frames.length - 1].unix_ms);
  if (data.probes && data.probes.lines && data.zero !== null) {
    times.push(data.zero + data.probes.t0_ms, data.zero + data.probes.t1_ms);
  }
  for (const e of (data.plan ? data.plan.events : [])) {
    if (e.started_ms != null) times.push(e.started_ms);
    if (e.ended_ms != null) times.push(e.ended_ms);
  }
  if (data.timedLog && data.log.length) times.push(data.log[0].unix_ms, data.log[data.log.length - 1].unix_ms);
  if (!times.length && data.probes && data.probes.lines) times.push(data.probes.t0_ms, data.probes.t1_ms);
  if (!times.length) return;
  t0 = Math.min(...times);
  t1 = Math.max(...times);
  $("scrub").max = Math.max(0, Math.round(t1 - t0));
}

function stepTimes() {
  const s = new Set();
  for (const e of (data.plan ? data.plan.events : [])) if (e.started_ms != null) s.add(e.started_ms);
  return [...s].sort((a, b) => a - b);
}

$("scrub").addEventListener("input", (e) => seek(t0 + Number(e.target.value)));
$("prev").addEventListener("click", () => stepFrame(-1));
$("next").addEventListener("click", () => stepFrame(1));
$("prev-step").addEventListener("click", () => {
  const before = stepTimes().filter((t) => t < now - 1);
  if (before.length) seek(before[before.length - 1]);
});
$("next-step").addEventListener("click", () => {
  const after = stepTimes().find((t) => t > now + 1);
  if (after !== undefined) seek(after);
});
$("to-failure").addEventListener("click", () => {
  const f = data.frames.find((x) => x.why === "failure");
  if (f) seek(f.unix_ms);
});
function stepFrame(d) {
  if (data.frames.length) {
    const i = Math.min(Math.max(frameIndexAt(now) + d, 0), data.frames.length - 1);
    seek(data.frames[i].unix_ms);
  } else {
    seek(now + d * 1000);
  }
}
document.addEventListener("keydown", (e) => {
  if (e.target.tagName === "INPUT" && e.target.type !== "range") return;
  if (e.key === "ArrowLeft") { stepFrame(-1); e.preventDefault(); }
  if (e.key === "ArrowRight") { stepFrame(1); e.preventDefault(); }
});
