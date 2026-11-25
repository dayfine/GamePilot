"use strict";

// --- Events ------------------------------------------------------------------

function connect() {
  const events = new EventSource("events");
  const on = (name, f) => events.addEventListener(name, (m) => f(JSON.parse(m.data)));
  events.onopen = () => { $("conn").textContent = "live"; $("conn").className = ""; };
  events.onerror = () => { $("conn").textContent = "disconnected, retrying…"; $("conn").className = "down"; };
  // A new daemon (each checkpoint has its own): its frame size, and the
  // stream again, since the last one ended with the old daemon.
  on("info", (d) => {
    info = d;
    if (d.backend.kind === "view") showViewOnly();
    frameW = d.backend.width || frameW;
    frameH = d.backend.height || frameH;
    layoutFrame();
    if (!document.hidden) setSource("stream");
  });
  on("run", (d) => { lastRun = d; runAt = Date.now(); renderRun(); });
  on("plan", (d) => {
    lastPlan = d;
    plans.set(d.checkpoint, d);
    trackCurrent(d);
    renderPlan();
    if (d.checkpoint === pastId) showPast(pastId);
  });
  on("source", showSourceState);
  on("log", (d) => addLog(d.line));
  on("probes", (d) => takeProbes(d.probes));
  on("status", (d) => { renderStatus(d); $("conn").textContent = "live"; $("conn").className = ""; });
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
