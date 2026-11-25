"use strict";

// Polls the live runs and starts the page, once hub_live.js and
// hub_history.js have loaded.

let entries = [];
let series = [];
async function poll() {
  try {
    const reply = await fetch("runs.json", {cache: "no-store"});
    entries = await reply.json();
    series = await fetch("series.json", {cache: "no-store"})
      .then((r) => r.ok ? r.json() : []).catch(() => []);
    await Promise.all(entries.map((r) => fetchSummary(r.run)));
    const runs = entries.filter((r) => !r.source && !r.series).length + series.length;
    const watched = entries.length - runs;
    $("conn").textContent = runs + " live run" + (runs === 1 ? "" : "s") +
      (watched ? " · " + watched + " watched" : "");
    $("conn").className = "";
  } catch (e) {
    $("conn").textContent = "hub unreachable, retrying…";
    $("conn").className = "down";
  }
  render(entries, series);
  setTimeout(poll, POLL_MS);
}
poll();
pollHistory();
