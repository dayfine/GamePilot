"use strict";

// --- Events ------------------------------------------------------------------

// The event stream. On a series' page it follows the run going: opened again
// when that run changes, and when the hub closed it (between runs, 503).
let events = null;
let eventsRun = null;      // the series' run going when it was opened
const RECONNECT_MS = 2000;

function connect() {
  if (events) events.close();
  const source = new EventSource("events");
  events = source;
  eventsRun = lastSeries ? lastSeries.run : null;
  const on = (name, f) => source.addEventListener(name, (m) => f(JSON.parse(m.data)));
  source.onopen = () => { $("conn").textContent = "live"; $("conn").className = ""; };
  source.onerror = () => {
    if (source !== events || endedShown) return;
    $("conn").textContent = SERIES_ID ? "between runs, waiting for the next…" : "disconnected, retrying…";
    $("conn").className = "down";
    if (SERIES_ID && source.readyState === EventSource.CLOSED) {
      setTimeout(() => { if (source === events && !endedShown) connect(); }, RECONNECT_MS);
    }
  };
  // A new daemon (each checkpoint has its own): its frame size, and the
  // stream again, since the last one ended with the old daemon. Its probes
  // and plan come after it: the last daemon's are gone.
  on("info", (d) => {
    info = d;
    lastLabel.clear();
    changedAt.clear();
    takeProbes([]);
    lastPlan = null;
    currentKey = null;
    $("plan-title").textContent = "Plan";
    $("plan").replaceChildren(el("li", "empty", "no plan yet: the program sends it when a checkpoint starts"));
    renderCounters(null);
    if (d.backend.kind === "view") showViewOnly();
    frameW = d.backend.width || frameW;
    frameH = d.backend.height || frameH;
    layoutFrame();
    if (!document.hidden) setSource("stream");
  });
  // A series' page shows the series' record instead of one run's chain.
  on("run", (d) => { lastRun = d; runAt = Date.now(); if (!SERIES_ID) renderRun(); });
  on("plan", (d) => {
    lastPlan = d;
    plans.set(d.checkpoint, d);
    resetAttemptForCheckpoint(d.checkpoint);
    trackCurrent(d);
    renderPlan();
    if (d.checkpoint === pastId) showPast(pastId);
  });
  on("counters", renderCounters);
  on("source", showSourceState);
  on("log", (d) => addLog(d.line));
  on("probes", (d) => takeProbes(d.probes));
  on("status", (d) => { renderStatus(d); $("conn").textContent = "live"; $("conn").className = ""; });
}

const COUNTDOWN_SOON_MS = 60000;
let countdownTimer = 0;

function formatCountdown(remMs) {
  const totalSec = Math.max(0, Math.ceil(remMs / 1000));
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
}

function tickCountdowns() {
  const nodes = $("counters").querySelectorAll("dd[data-until-ms]");
  const pill = $("frame-countdown");
  if (nodes.length === 0) {
    if (countdownTimer) { clearInterval(countdownTimer); countdownTimer = 0; }
    if (pill) { pill.hidden = true; pill.textContent = ""; pill.classList.remove("soon"); }
    return;
  }
  const now = Date.now();
  let first = null;
  for (const dd of nodes) {
    const until = Number(dd.dataset.untilMs);
    const rem = Math.max(0, until - now);
    const text = formatCountdown(rem);
    const soon = rem <= COUNTDOWN_SOON_MS;
    dd.textContent = text;
    dd.classList.toggle("countdown-soon", soon);
    if (!first) first = { label: dd.dataset.label || "Countdown", text, soon };
  }
  if (pill && first) {
    pill.textContent = first.label + " " + first.text;
    pill.classList.toggle("soon", first.soon);
    pill.hidden = false;
  }
}

// Live key-value counters from watch.counters; hidden when empty.
function renderCounters(d) {
  const items = d && Array.isArray(d.items) ? d.items : [];
  const panel = $("counters-panel");
  const main = document.querySelector("main");
  panel.hidden = items.length === 0;
  if (main) main.classList.toggle("has-counters", items.length > 0);
  const list = $("counters");
  list.replaceChildren();
  let hasCountdown = false;
  for (const item of items) {
    const box = el("div", "counter");
    const dd = el("dd", "", item.value);
    if (typeof item.until_ms === "number" && Number.isFinite(item.until_ms)) {
      dd.dataset.untilMs = String(item.until_ms);
      dd.dataset.label = item.label;
      hasCountdown = true;
    }
    box.append(el("dt", "", item.label), dd);
    list.append(box);
    if (/^(?:attempts?|resets?)$/i.test(item.label)) {
      updateAttemptFromCounter(item.label, item.value);
    }
  }
  tickCountdowns();
  if (hasCountdown && !countdownTimer) {
    countdownTimer = setInterval(tickCountdowns, 1000);
  }
}

// A view-only daemon: nothing to stop, no run or plan of ours.
function showViewOnly() {
  $("stop").hidden = true;
  $("readonly").hidden = true;
  $("run-meta").textContent = "watching another program: no run or plan here; its log is below";
}

// "live", or why the picture may be old: stale, covered, hidden.
function showSourceState(d) {
  const box = $("source-state");
  box.hidden = false;
  box.textContent = d.state === "live" ? "picture live" : "picture " + d.state;
  box.title = d.detail || "";
  box.className = d.state === "live" ? "" : "warn";
}

$("stop").hidden = !TOKEN;
$("readonly").hidden = !!TOKEN;
$("stop").addEventListener("click", async () => {
  if (!confirm("Stop the program? All buttons are released and the run ends as failed (stopped by user).")) return;
  const button = $("stop");
  button.disabled = true;
  try {
    const response = await fetch("stop?token=" + encodeURIComponent(TOKEN), {method: "POST"});
    const reply = await response.json();
    addLog(response.status === 403 ? "[Watch] Stop refused: this page's token is not the run's" :
           reply.stopped ? "[Watch] Stop sent" : "[Watch] Stop: no program is connected");
  } catch (e) {
    addLog("[Watch] Stop failed: " + e);
  } finally {
    setTimeout(() => { button.disabled = false; }, 2000);
  }
});
