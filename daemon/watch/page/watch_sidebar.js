"use strict";

// --- Runs sidebar --------------------------------------------------------------
//
// The hub's live runs (each with its checkpoint, elapsed time and state from
// its /summary.json) and the latest finished runs, polled while the tab is
// visible. This run is found by its name in the URL (/runs/NAME/), or by its
// port when the page was opened on the run's own port.

const SIDE_POLL_MS = 3000;
// The hub's port, for a page opened on the run's own port (?hub=N for a hub
// started on another one).
const HUB_PORT = Number(new URLSearchParams(location.search).get("hub")) || 47901;
const PHONE_LAYOUT = window.matchMedia("(max-width: 800px)");
const viaHub = location.pathname.match(/^(.*)\/runs\/([^/]+)\/$/);
const HUB = viaHub ? location.origin + viaHub[1] + "/" :
  location.protocol + "//" + location.hostname + ":" + HUB_PORT + "/";
let runName = viaHub ? decodeURIComponent(viaHub[2]) : null;
let runPort = viaHub ? null : Number(location.port);
let wasLive = false;
let endedShown = false;

const runPath = (name) => HUB + "runs/" + encodeURIComponent(name) + "/";

// Wide window: open unless closed before (kept); phone: a closed drawer.
function setSide(open, keep) {
  const phone = PHONE_LAYOUT.matches;
  document.body.classList.toggle("side-open", phone && open);
  document.body.classList.toggle("side-closed", !phone && !open);
  $("side-backdrop").hidden = !(phone && open);
  $("side-toggle").setAttribute("aria-expanded", String(open));
  if (keep && !phone) {
    try { localStorage.setItem("watch.side", open ? "open" : "closed"); } catch (e) {}
  }
  if (!phone) layoutFrame();
}
function sideOpen() {
  return PHONE_LAYOUT.matches ? document.body.classList.contains("side-open") :
    !document.body.classList.contains("side-closed");
}
function initialSide() {
  let kept = null;
  try { kept = localStorage.getItem("watch.side"); } catch (e) {}
  setSide(!PHONE_LAYOUT.matches && kept !== "closed", false);
}
$("side-toggle").addEventListener("click", () => setSide(!sideOpen(), true));
$("side-backdrop").addEventListener("click", () => setSide(false, false));
PHONE_LAYOUT.addEventListener("change", initialSide);
$("side-hub").href = HUB;
$("ended-newest").href = HUB + "live";
$("ended-close").addEventListener("click", () => { $("ended").hidden = true; });

// What a live run is doing: its plan's current (or failed) event, else its
// chain (the hub page's rule).
function runState(summary) {
  const plan = summary && summary.plan;
  const run = summary && summary.run;
  if (plan) {
    const i = plan.events.findIndex((e) => e.state === "current" || e.state === "failed");
    if (i >= 0) {
      const e = plan.events[i];
      return [(e.state === "failed" ? "failed at " : "") + "#" + (i + 1) + " " + e.id,
              e.state === "failed" ? "fail" : ""];
    }
  }
  if (run) {
    const failed = run.checkpoints.find((c) => c.state === "failed");
    if (failed) return ["stopped at " + failed.id, "fail"];
    if (!run.checkpoints.some((c) => c.state === "current")) return ["chain done", "pass"];
  }
  return ["starting", ""];
}

// "21:31", or "Nov 22 21:31" before today (RESULTS.tsv's local time).
function endedAt(time) {
  const d = new Date(time);
  if (isNaN(d)) return time || "";
  const hm = d.toLocaleTimeString([], {hour: "2-digit", minute: "2-digit", hour12: false});
  return d.toDateString() === new Date().toDateString() ? hm :
    d.toLocaleDateString([], {month: "short", day: "numeric"}) + " " + hm;
}

function sideItem(href, here, l1, l2, cls, title) {
  const li = el("li", here ? "here" : "");
  const box = el(href ? "a" : "span", "row");
  if (href) box.href = href;
  if (title) box.title = title;
  box.append(el("span", "l1 " + (cls || ""), l1), el("span", "l2", l2));
  li.append(box);
  return li;
}

function noteItem(text) {
  const li = el("li");
  li.append(el("span", "row note", text));
  return li;
}

function renderSide(live, summaries, recent) {
  const liveList = $("side-live");
  liveList.replaceChildren();
  if (!live) {
    liveList.append(sideItem(null, false, "Hub not running",
      "open " + HUB + " once a run starts it", "", ""));
    $("side-recent").replaceChildren();
    return;
  }
  // External sources (a view-only daemon) are watched, not run: their own
  // group, with the picture's state.
  const watching = live.filter((r) => r.source);
  live = live.filter((r) => !r.source);
  $("side-watching-group").hidden = !watching.length;
  $("side-watching").replaceChildren(...watching.map((r) => {
    const source = summaries.get(r.run) && summaries.get(r.run).source;
    const state = source ? source.state : "starting";
    return sideItem(runPath(r.run), r.run === runName, r.run + " · " + r.source,
      duration(Date.now() - r.started_ms) + " · " + state,
      state === "live" ? "pass" : (source ? "fail" : ""), source ? source.detail : "");
  }));
  for (const r of [...live].sort((a, b) => b.started_ms - a.started_ms)) {
    const summary = summaries.get(r.run);
    const run = summary && summary.run;
    const current = run && run.checkpoints.find((c) => c.state === "current");
    const started = run ? run.started_ms : r.started_ms;
    const [state, cls] = runState(summary);
    liveList.append(sideItem(runPath(r.run), r.run === runName,
      (current ? current.id : r.checkpoint || r.run) + " · " + r.backend,
      duration(Date.now() - started) + " · " + state, cls, r.run));
  }
  if (!live.length) liveList.append(noteItem("no live runs"));
  const recentList = $("side-recent");
  recentList.replaceChildren();
  const liveNames = new Set(live.map((r) => r.run));
  for (const row of (recent || []).filter((x) => !liveNames.has(x.run)).slice(0, 12)) {
    const pass = row.result === "pass";
    recentList.append(sideItem(runPath(row.run), row.run === runName,
      (pass ? "✓ " : "✗ ") + (row.checkpoint || row.run) + (row.mode ? " · " + row.mode : ""),
      endedAt(row.time) + (pass ? "" : " · " + (row.at || row.result)),
      pass ? "pass" : "fail", row.run + (row.reason ? "\n" + row.reason : "")));
  }
  if (!recentList.childElementCount) recentList.append(noteItem("none yet"));
}

// This run left the registry: say so (with its result when RESULTS.tsv has
// it), stop fetching its frame, and follow the series' next run (it takes
// the same port) when the page came through the hub.
function checkEnded(live, recent) {
  const mine = live.find((r) => runName ? r.run === runName : r.port === runPort);
  if (mine) {
    runName = mine.run;
    runPort = mine.port;
    wasLive = true;
    document.title = (mine.checkpoint || mine.run) + " · GamePilot Watch";
    if (endedShown) { endedShown = false; $("ended").hidden = true; }
    return;
  }
  if (!wasLive && !viaHub) return;
  if (viaHub) {
    const next = runPort && live.find((r) => r.port === runPort);
    if (next) { location.replace(runPath(next.run) + location.search); return; }
  }
  if (endedShown) return;
  endedShown = true;
  const row = (recent || []).find((x) => x.run === runName);
  $("ended-text").textContent = "This run has ended" +
    (row ? (row.result === "pass" ? ": passed." : ": failed" + (row.at ? " at " + row.at : "") + ".") : ".");
  $("ended-newest").hidden = !live.length;
  $("ended-record").href = runPath(runName);
  $("ended").hidden = false;
  $("conn").textContent = "run ended";
  $("conn").className = "down";
  if (viaHub) {
    setSource("off");
    $("stop").hidden = true;
  }
}

async function getJson(url) {
  const reply = await fetch(url, {cache: "no-store"});
  if (!reply.ok) throw new Error(url + ": " + reply.status);
  return reply.json();
}

async function pollSide() {
  if (!document.hidden) {
    let live = null, recent = null;
    const summaries = new Map();
    try {
      [live, recent] = await Promise.all([getJson(HUB + "runs.json"),
                                          getJson(HUB + "recent.json").catch(() => [])]);
      await Promise.all(live.map((r) => getJson(runPath(r.run) + "summary.json")
        .then((s) => summaries.set(r.run, s)).catch(() => {})));
    } catch (e) {
      live = null;
    }
    if (live) checkEnded(live, recent);
    renderSide(live, summaries, recent);
  }
  setTimeout(pollSide, SIDE_POLL_MS);
}
