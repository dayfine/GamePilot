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

// Live key-value counters from watch.counters; hidden when empty.
function renderCounters(d) {
  const items = d && Array.isArray(d.items) ? d.items : [];
  const panel = $("counters-panel");
  const main = document.querySelector("main");
  panel.hidden = items.length === 0;
  if (main) main.classList.toggle("has-counters", items.length > 0);
  const list = $("counters");
  list.replaceChildren();
  for (const item of items) {
    const box = el("div", "counter");
    box.append(el("dt", "", item.label), el("dd", "", item.value));
    list.append(box);
    if (/^(?:attempts?|resets?)$/i.test(item.label)) {
      updateAttemptFromCounter(item.label, item.value);
    }
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
