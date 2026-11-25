"use strict";

// --- Run: the chain of checkpoints -------------------------------------------
//
// `run` comes at the start and the end of each run of a checkpoint (each run
// has its own daemon, so the stream reconnects in between). Each checkpoint's
// last plan stays here, so a finished one's events can be shown again.

const plans = new Map();   // checkpoint id -> its last plan
let lastRun = null;
let runAt = 0;             // when lastRun came (Date.now())
let pastId = null;         // the finished checkpoint shown below the chain

function elapsed(c) {
  return c.elapsed_ms + (c.state === "current" ? Date.now() - runAt : 0);
}

function renderRun() {
  const run = lastRun;
  if (!run) return;
  const cur = run.checkpoints.find((c) => c.state === "current");
  const total = cur ? Date.now() - run.started_ms : runAt - run.started_ms;
  const meta = $("run-meta");
  meta.replaceChildren(el("b", "", run.mode), " · ");
  if (cur) {
    meta.append(el("b", "", cur.id), " trial " + run.trial + " of " + run.trials + " · " +
                run.passes + " passed, " + run.fails + " failed · ");
  } else {
    const failed = run.checkpoints.find((c) => c.state === "failed");
    meta.append(el("b", "", failed ? "stopped at " + failed.id : "chain done"), " · ");
  }
  meta.append("total " + duration(total));
  const chain = $("chain");
  chain.replaceChildren();
  for (const c of run.checkpoints) {
    const finished = c.state === "passed" || c.state === "failed";
    const open = finished && plans.has(c.id);
    const chip = el(open ? "button" : "span", "chip " + c.state + (open ? " open" : "") +
                    (c.id === pastId ? " shown" : ""));
    if (open) chip.type = "button";
    chip.title = open ? "Show " + c.id + "'s events at its end" : c.state;
    chip.append((MARKS[c.state] ? MARKS[c.state] + " " : "") + c.id);
    let note = "";
    if (c.state === "current") {
      note = run.trial + "/" + run.trials + ", " + run.passes + " pass" +
             (run.passes === 1 ? "" : "es") + " · " + duration(elapsed(c));
    } else if (finished) {
      note = duration(elapsed(c));
    }
    if (note) chip.append(el("span", "t", note));
    if (open) chip.addEventListener("click", () => showPast(c.id === pastId ? null : c.id));
    const li = el("li");
    li.append(chip);
    chain.append(li);
  }
}

function showPast(id) {
  pastId = id;
  $("past").hidden = !id;
  if (id) {
    const plan = plans.get(id);
    const state = chainCheckpoints().find((c) => c.id === id);
    $("past-title").textContent = id + " · " + (state ? state.state : "") + " · its events at its end";
    renderEvents($("past-plan"), plan, false);
  }
  renderChain();
}
$("past-close").addEventListener("click", () => showPast(null));

// --- Run: a checkpoint series ------------------------------------------------
//
// On a series' page the Run card is the series' record (the runner's
// Series_record, through the hub's series.json): the program and range, every
// checkpoint in order with its state, its runs (run n, attempt, result) and
// its time, the current one marked. A finished checkpoint shows its events
// from this page's memory, or opens its last run's record.

const SERIES_POLL_MS = 2000;
let lastSeries = null;

function chainCheckpoints() {
  return SERIES_ID ? (lastSeries ? lastSeries.checkpoints : []) : (lastRun ? lastRun.checkpoints : []);
}

function renderChain() {
  if (SERIES_ID) renderSeries(); else renderRun();
}

// A checkpoint's time: from its first run's start to its end, or to now.
function checkpointMs(c) {
  if (c.started_ms == null) return null;
  return (c.ended_ms != null ? c.ended_ms : Date.now()) - c.started_ms;
}

// "2 runs, 1 retry": only when the runner made more than one.
function runsNote(c) {
  const runs = new Set(c.runs.map((r) => r.n)).size;
  const retries = c.runs.filter((r) => r.attempt > 1).length;
  const parts = [];
  if (runs > 1) parts.push(runs + " runs");
  if (retries) parts.push(retries + (retries === 1 ? " retry" : " retries"));
  return parts.join(", ");
}

// Each run on its own line: "run 1 attempt 2: fail at #3 talk: no_text".
function runsTitle(c) {
  return [c.state, ...c.runs.map((r) => "run " + r.n + (r.attempt > 1 ? " attempt " + r.attempt : "") +
    ": " + (r.result === "running" ? "running" : r.result +
      (r.at ? " at " + r.at : "") + (r.reason ? ": " + r.reason : "")))].join("\n");
}

function seriesMeta(series) {
  const meta = $("run-meta");
  const cps = series.checkpoints;
  const cur = cps.findIndex((c) => c.state === "current");
  meta.replaceChildren(el("b", "", series.program_name || series.program || "series"),
    " · " + series.from + " → " + series.to + " · " + series.mode + " · ");
  if (series.result === "running" && cur >= 0) {
    meta.append(el("b", "", cps[cur].id), " (" + (cur + 1) + " of " + cps.length + ")" +
                (series.run ? "" : " · between runs") + " · ");
  } else if (series.result === "running") {
    meta.append("starting · ");
  } else {
    const failed = cps.find((c) => c.state === "failed");
    meta.append(el("b", "", series.result === "pass" ? "series passed" :
                "stopped at " + (failed ? failed.id : "?")), " · ");
  }
  const end = series.ended_ms != null ? series.ended_ms : Date.now();
  meta.append("total " + duration(end - series.started_ms));
}

function seriesChip(c) {
  const finished = c.state === "passed" || c.state === "failed";
  const shows = finished && plans.has(c.id);
  const last = c.runs.length ? c.runs[c.runs.length - 1] : null;
  const record = finished && !shows && last;
  const chip = el(shows ? "button" : record ? "a" : "span", "chip " + c.state +
                  (shows || record ? " open" : "") + (c.id === pastId ? " shown" : ""));
  if (shows) {
    chip.type = "button";
    chip.addEventListener("click", () => showPast(c.id === pastId ? null : c.id));
  }
  if (record) chip.href = runPath(last.run);
  chip.title = runsTitle(c) + (shows ? "\nShow its events at its end" : record ? "\nOpen its last run's record" : "");
  chip.append((MARKS[c.state] ? MARKS[c.state] + " " : "") + c.id);
  const ms = checkpointMs(c);
  const note = [runsNote(c), c.state === "current" && last && last.attempt > 1 ? "attempt " + last.attempt : "",
                ms != null && c.state !== "pending" ? duration(ms) : ""].filter((x) => x).join(" · ");
  if (note) chip.append(el("span", "t", note));
  return chip;
}

function renderSeries() {
  const series = lastSeries;
  if (!series) return;
  seriesMeta(series);
  const chain = $("chain");
  chain.replaceChildren(...series.checkpoints.map((c) => {
    const li = el("li");
    li.append(seriesChip(c));
    return li;
  }));
  document.title = (series.program_name || series.program || "series") + " " + series.from +
    " → " + series.to + " · GamePilot Watch";
}

// The series ended: say so, stop the frame and Stop.
function showSeriesEnded(series) {
  if (endedShown) return;
  endedShown = true;
  const failed = series.checkpoints.find((c) => c.state === "failed");
  $("ended-text").textContent = "This series has ended: " +
    (series.result === "pass" ? "every checkpoint passed." : "stopped" + (failed ? " at " + failed.id : "") + ".");
  $("ended-record").hidden = true;
  $("ended").hidden = false;
  $("conn").textContent = "series ended";
  $("conn").className = "down";
  setSource("off");
  $("stop").hidden = true;
}

async function pollSeries() {
  if (!document.hidden || !lastSeries) {
    try {
      const series = await getJson("series.json");
      const first = !lastSeries;
      lastSeries = series;
      renderSeries();
      if (first) eventsRun = series.run;  // the stream opened at load is its
      if (series.result !== "running") showSeriesEnded(series);
      else if (series.run && series.run !== eventsRun) connect();
    } catch (e) {
      // The hub restarting: the next poll tries again.
    }
  }
  setTimeout(pollSeries, SERIES_POLL_MS);
}

// Times tick between messages.
setInterval(() => {
  renderChain();
  if (lastPlan && currentKey) renderPlan();
}, 1000);
