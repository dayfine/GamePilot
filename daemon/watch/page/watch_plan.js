"use strict";

// --- Plan --------------------------------------------------------------------

const MARKS = {done: "✓", passed: "✓", current: "▶", failed: "✗", skipped: "–", pending: ""};

// "4:05" or "1:02:09".
function duration(ms) {
  const s = Math.max(0, Math.floor(ms / 1000));
  const two = (n) => String(n).padStart(2, "0");
  const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
  return (h ? h + ":" + two(m) : String(m)) + ":" + two(s % 60);
}

// An event's time: a finished one's from its start to its end, the current
// one's so far (`now`; null for a plan that is not live). Null without times
// (a program before v1.8) or before it started. The same rule as
// Wire.Watch.event_ms.
function eventMs(e, now) {
  if (e.started_ms == null) return null;
  if (e.ended_ms != null) return e.ended_ms - e.started_ms;
  return e.state === "current" && now != null ? now - e.started_ms : null;
}

// The checkpoint's time: from its first event's start to `now` while an event
// runs (a live plan), else to its last end. Wire.Watch.plan_ms.
function planMs(plan, now) {
  const starts = plan.events.filter((e) => e.started_ms != null).map((e) => e.started_ms);
  if (!starts.length) return null;
  const ends = plan.events.filter((e) => e.ended_ms != null).map((e) => e.ended_ms);
  const running = plan.events.some((e) => e.state === "current" && e.ended_ms == null);
  const end = running && now != null ? now : (ends.length ? Math.max(...ends) : null);
  return end == null ? null : end - Math.min(...starts);
}

// The current event: since when this page has seen it current (a program
// before v1.8 sends no start times, so a page opened mid-event counts from
// then), and the grind's progress from its log lines (Frlg_actions.Grind).
let currentKey = null;
let currentSince = 0;
let grind = null;   // {goal, battle, level, heal}

function trackCurrent(plan) {
  const i = plan.events.findIndex((e) => e.state === "current");
  const key = i < 0 ? null : plan.checkpoint + "#" + i;
  if (key !== currentKey) { currentKey = key; currentSince = Date.now(); grind = null; }
}

function grindLine(line) {
  const goal = line.match(/Grind: (.+? to Lv \d+ for [^(]+?) \(/);
  const battle = line.match(/Grind: battle (\d+) (?:of \d+, Lv (\d+))?/);
  if (!goal && !battle && !/Grind: heal\./.test(line)) return;
  grind = grind || {goal: "", battle: 0, level: 0, heal: false};
  if (goal) grind.goal = goal[1];
  if (battle) {
    grind.battle = Number(battle[1]);
    if (battle[2]) grind.level = Number(battle[2]);
    grind.heal = false;
  }
  if (/Grind: heal\./.test(line)) grind.heal = true;
}

function currentDetail(timed) {
  const parts = timed ? [] : [duration(Date.now() - currentSince)];
  if (grind) {
    if (grind.battle) parts.push("battle " + grind.battle + (grind.level ? ", Lv " + grind.level : "") + (grind.heal ? ", healing" : ""));
    if (grind.goal) parts.push(grind.goal);
  } else if (lastLogLine) {
    parts.push(lastLogLine);
  }
  return parts.join(" · ");
}

// A plan's events into a list, each with its time, and the checkpoint's total
// below; the live plan shows the current event's time so far and progress.
function renderEvents(list, plan, live) {
  const now = live ? Date.now() : null;
  list.replaceChildren();
  plan.events.forEach((e, i) => {
    const li = el("li", e.state);
    li.append(el("span", "mark", MARKS[e.state] || ""), el("span", "n", "#" + (i + 1)),
              el("span", "id", e.id));
    const ms = eventMs(e, now);
    if (ms != null) li.append(el("span", "t", duration(ms)));
    let detail = e.detail;
    if (live && e.state === "current" && !detail) detail = currentDetail(ms != null);
    if (e.state === "skipped" && detail) detail = "skipped: " + detail;
    if (detail) li.append(el("span", "detail", detail));
    list.append(li);
  });
  const total = planMs(plan, now);
  if (total != null) {
    const li = el("li", "total");
    li.append(el("span", "mark", ""), el("span", "n", ""), el("span", "id", "total"),
              el("span", "t", duration(total)));
    list.append(li);
  }
}

function renderPlan() {
  const plan = lastPlan;
  if (!plan) return;
  $("plan-title").textContent = "Plan · " + plan.checkpoint;
  renderEvents($("plan"), plan, true);
  // Scroll only the plan's own list, never the page: scrollIntoView moved the
  // whole window on a phone's one-column layout at every update.
  const list = $("plan");
  const current = list.querySelector("li.current, li.failed");
  if (current && list.scrollHeight > list.clientHeight) {
    const top = current.offsetTop - list.offsetTop;
    if (top < list.scrollTop || top + current.offsetHeight > list.scrollTop + list.clientHeight) {
      list.scrollTop = top - list.clientHeight / 3;
    }
  }
}
