"use strict";

// The page's helpers, the run's data and its record (result, range, facts).

const $ = (id) => document.getElementById(id);

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

// "4:05" or "1:02:09".
function duration(ms) {
  const s = Math.max(0, Math.round(ms / 1000));
  const two = (n) => String(n).padStart(2, "0");
  const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
  return (h ? h + ":" + two(m) : String(m)) + ":" + two(s % 60);
}

function clock(ms) {
  return new Date(ms).toLocaleTimeString([], {hour12: false});
}

async function getJson(url) {
  const reply = await fetch(url, {cache: "no-store"});
  if (!reply.ok) throw new Error(url + ": " + reply.status);
  return reply.json();
}
async function getText(url) {
  const reply = await fetch(url, {cache: "no-store"});
  if (!reply.ok) throw new Error(url + ": " + reply.status);
  return reply.text();
}
const jsonLines = (text) => text.split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));

// The run's data; times are Unix ms (`zero` puts the daemon's clock on it).
const data = {record: null, plan: null, log: [], timedLog: false, frames: [],
              probes: null, zero: null};
// The scrubber's time and its range.
let now = 0, t0 = 0, t1 = 0;

const BACKEND_NAMES = {mgba: "mGBA", switch: "Switch"};

function renderRecord(r) {
  document.title = r.run + " · GamePilot Run";
  $("title").textContent = r.run;
  const verdict = $("verdict");
  verdict.textContent = r.result === "pass" ? "Passed" : r.result === "fail" ? "Failed" :
    r.result === "running" ? "Running" : "No result";
  verdict.className = r.result === "pass" ? "passed" : r.result === "fail" ? "failed" : "muted";
  $("where").textContent = r.at ? "at " + r.at : "";
  $("reason").textContent = r.reason || "";
  const facts = $("facts");
  facts.replaceChildren();
  const fact = (label, value) => {
    if (!value) return;
    const span = el("span", "", label + " ");
    span.append(el("b", "", value));
    facts.append(span);
  };
  fact("game", r.game);
  fact("program", r.program);
  fact("checkpoints", r.from && r.from !== r.to ? r.from + " → " + r.to + " (this: " +
       r.checkpoint + ")" : r.checkpoint);
  fact("backend", BACKEND_NAMES[r.backend] || r.backend);
  fact("mode", r.mode);
  fact("started", r.started_ms ? new Date(r.started_ms).toLocaleString([], {hour12: false}) : "");
  fact("duration", r.started_ms && r.ended_ms ? duration(r.ended_ms - r.started_ms) : "");
  if (r.failure_frame) {
    $("failure").src = "files/failure.png";
    $("failure-box").hidden = false;
  }
  if (r.result === "running") {
    $("verdict").append(" ", Object.assign(el("a", "", "open the live page"), {href: "./"}));
  }
}
