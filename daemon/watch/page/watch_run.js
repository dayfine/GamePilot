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
    const state = lastRun.checkpoints.find((c) => c.id === id);
    $("past-title").textContent = id + " · " + (state ? state.state : "") + " · its events at its end";
    renderEvents($("past-plan"), plan, false);
  }
  renderRun();
}
$("past-close").addEventListener("click", () => showPast(null));

// Times tick between messages.
setInterval(() => {
  renderRun();
  if (lastPlan && currentKey) renderPlan();
}, 1000);
