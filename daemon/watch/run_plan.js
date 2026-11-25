"use strict";

// --- Plan -----------------------------------------------------------------------

const MARKS = {done: "✓", failed: "✗", skipped: "–", current: "▸", pending: "·"};

// Older runs have no watch_plan.json: their events from story.log's
// "[Story] CP #N ID: VERDICT" lines, without times.
function planFromLog(lines) {
  const events = [];
  for (const {line} of lines) {
    const m = /^\[Story\] \S+ #(\d+) (\S+): (\w+)/.exec(line);
    if (!m) continue;
    const i = Number(m[1]) - 1;
    const state = m[3] === "start" ? "current" : m[3] === "passed" || m[3] === "done" ? "done" :
      m[3] === "skipped" ? "skipped" : m[3] === "failed" ? "failed" : null;
    if (!state) continue;
    events[i] = Object.assign(events[i] || {id: m[2], detail: ""}, {state});
  }
  return {events: events.filter(Boolean)};
}

function renderPlan() {
  const list = $("events");
  list.replaceChildren();
  const plan = data.plan;
  if (!plan || !plan.events.length) {
    list.append(el("li", "note", "no plan recorded"));
    return;
  }
  let first = null, last = null;
  plan.events.forEach((e, i) => {
    const li = el("li", "s-" + e.state);
    li.dataset.i = i;
    const t = e.started_ms != null && e.ended_ms != null ? duration(e.ended_ms - e.started_ms) :
      e.started_ms != null ? "…" : "";
    li.append(el("span", "mark", MARKS[e.state] || "·"), el("span", "id", "#" + (i + 1) + " " + e.id),
              el("span", "t", t));
    if (e.detail) li.append(el("span", "detail", e.detail));
    if (e.started_ms != null) {
      li.title = "started " + clock(e.started_ms);
      li.addEventListener("click", () => seek(e.started_ms));
      if (first === null || e.started_ms < first) first = e.started_ms;
      const end = e.ended_ms != null ? e.ended_ms : e.started_ms;
      if (last === null || end > last) last = end;
    }
    list.append(li);
  });
  $("plan-total").textContent = first !== null ? "total " + duration(last - first) :
    "no times (older run)";
}

function markPlan() {
  const plan = data.plan;
  if (!plan) return;
  for (const li of $("events").children) {
    const e = plan.events[li.dataset.i];
    li.classList.toggle("at", !!e && e.started_ms != null && e.started_ms <= now &&
      (e.ended_ms == null || now < e.ended_ms));
  }
}
