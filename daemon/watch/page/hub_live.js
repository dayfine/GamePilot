"use strict";

// The live runs and the watched sources, from runs.json and each run's
// /summary.json.

const POLL_MS = 2000;
const $ = (id) => document.getElementById(id);
const summaries = new Map();   // run name -> the run's latest /summary.json

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

// "4:05" or "1:02:09".
function duration(ms) {
  const s = Math.max(0, Math.floor(ms / 1000));
  const two = (n) => String(n).padStart(2, "0");
  const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
  return (h ? h + ":" + two(m) : String(m)) + ":" + two(s % 60);
}

// A run's page, through this hub.
const runUrl = (name) => "runs/" + encodeURIComponent(name) + "/";
const seriesUrl = (id) => "series/" + encodeURIComponent(id) + "/";

async function fetchSummary(name) {
  try {
    const reply = await fetch(runUrl(name) + "summary.json", {cache: "no-store"});
    if (reply.ok) summaries.set(name, await reply.json());
  } catch (e) {
    summaries.delete(name);
  }
}

// What the run is doing: the plan's current (or failed) event, else the chain.
function stateOf(summary) {
  const plan = summary && summary.plan;
  const run = summary && summary.run;
  if (plan) {
    const i = plan.events.findIndex((e) => e.state === "current" || e.state === "failed");
    if (i >= 0) {
      const e = plan.events[i];
      // The current event's time so far (v1.8 plans carry its start).
      const time = e.state === "current" && e.started_ms != null ?
        " · " + duration(Date.now() - e.started_ms) : "";
      return [(e.state === "failed" ? "failed at " : "") + "#" + (i + 1) + " " + e.id + time,
              e.state === "failed" ? "failed" : ""];
    }
  }
  if (run) {
    const failed = run.checkpoints.find((c) => c.state === "failed");
    if (failed) return ["stopped at " + failed.id, "failed"];
    if (!run.checkpoints.some((c) => c.state === "current")) return ["chain done", "passed"];
  }
  return ["starting", ""];
}

// External sources: each links to its page; the picture's state and why.
function renderWatching(sources) {
  $("watching-panel").hidden = !sources.length;
  $("watching").replaceChildren(...sources.map((r) => {
    const source = (summaries.get(r.run) || {}).source;
    const tr = el("tr");
    const name = el("td");
    const link = el("a", "", r.run);
    link.href = runUrl(r.run);
    name.append(link, el("div", "muted", "port " + r.port));
    const state = source ? source.state + (source.detail ? " · " + source.detail : "") : "starting";
    tr.append(name, el("td", "", r.source), el("td", "num", duration(Date.now() - r.started_ms)),
              el("td", "state " + (source && source.state !== "live" ? "failed" : ""), state));
    return tr;
  }));
}

// A running series: one row for all its runs.
function seriesRow(s) {
  const cps = s.checkpoints;
  const cur = cps.findIndex((c) => c.state === "current");
  const current = cur >= 0 ? cps[cur] : null;
  const last = current && current.runs.length ? current.runs[current.runs.length - 1] : null;
  const tr = el("tr");
  const name = el("td");
  const link = el("a", "", (s.program_name || s.program || "series") + " " + s.from + " → " + s.to);
  link.href = seriesUrl(s.series);
  name.append(link, el("div", "muted", s.backend + " · series · " + cps.filter((c) => c.state === "passed").length +
                       " of " + cps.length + " passed"));
  const [state, cls] = s.run ? stateOf(summaries.get(s.run)) : ["between runs", ""];
  tr.append(name, el("td", "", current ? current.id + " (" + (cur + 1) + " of " + cps.length + ")" : "–"),
            el("td", "", s.mode),
            el("td", "num", last ? "run " + last.n + (last.attempt > 1 ? " attempt " + last.attempt : "") : "–"),
            el("td", "num", duration(Date.now() - s.started_ms)),
            el("td", "state " + cls, state));
  return tr;
}

function render(all, series) {
  renderWatching(all.filter((r) => r.source));
  const entries = all.filter((r) => !r.source && !r.series);
  const body = $("runs");
  body.replaceChildren(...[...series].reverse().map(seriesRow));
  if (!entries.length && !series.length) {
    const td = el("td", "empty", "no live runs: gamepilot run --watch starts one");
    td.colSpan = 6;
    const tr = el("tr");
    tr.append(td);
    body.append(tr);
    return;
  }
  for (const r of entries) {
    const summary = summaries.get(r.run);
    const run = summary && summary.run;
    const current = run && run.checkpoints.find((c) => c.state === "current");
    const tr = el("tr");
    const name = el("td");
    const link = el("a", "", r.run || r.checkpoint || "run " + r.pid);
    link.href = runUrl(r.run);
    name.append(link, el("div", "muted", r.backend + " · port " + r.port));
    const checkpoint = current ? current.id : (r.checkpoint || "–");
    const started = run ? run.started_ms : r.started_ms;
    const [state, cls] = stateOf(summary);
    tr.append(name, el("td", "", checkpoint), el("td", "", run ? run.mode : "–"),
              el("td", "num", run && run.trial ? run.trial + " of " + run.trials +
                 " · " + run.passes + " passed" : "–"),
              el("td", "num", started ? duration(Date.now() - started) : "–"),
              el("td", "state " + cls, state));
    body.append(tr);
  }
}
