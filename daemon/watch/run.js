"use strict";

// --- Load -----------------------------------------------------------------------

async function load() {
  try {
    data.record = await getJson("record.json");
    renderRecord(data.record);
  } catch (e) {
    $("verdict").textContent = "no record of this run";
    return;
  }
  const [plan, logText, storyText, daemon, framesText] = await Promise.all([
    getJson("files/watch_plan.json").catch(() => null),
    getText("files/watch_log.jsonl").catch(() => ""),
    getText("files/story.log").catch(() => ""),
    getJson("files/daemon.json").catch(() => null),
    getText("files/frames/index.jsonl").catch(() => ""),
  ]);
  const timed = logText.trim() ? jsonLines(logText) : [];
  data.timedLog = timed.length > 0;
  data.log = data.timedLog ? timed :
    storyText.split("\n").filter((l) => l !== "").map((line) => ({line}));
  data.plan = plan || planFromLog(data.log);
  data.zero = daemon && daemon.clock_zero_unix_ms ? daemon.clock_zero_unix_ms : null;
  data.frames = framesText.trim() ? jsonLines(framesText) : [];
  $("frame-count").textContent = data.frames.length ? data.frames.length + " frames" :
    "not recorded (mGBA runs record with --record)";
  $("frame").hidden = !data.frames.length;
  $("to-failure").hidden = !data.frames.some((f) => f.why === "failure");
  try { $("probe-filter").value = localStorage.getItem("run.probeFilter") || ""; } catch (e) {}
  renderPlan();
  renderLog();
  setRange();
  // ?t=S opens the run S seconds in; else at its failure, else its end.
  const at = Number(new URLSearchParams(location.search).get("t"));
  const failure = data.frames.find((f) => f.why === "failure");
  seek(at > 0 ? t0 + at * 1000 : failure ? failure.unix_ms : t1);
  // The timeline last: the hub reads the whole wire log for it once.
  const started = performance.now();
  const hadRange = t1 > t0;
  try {
    data.probes = await getJson("probes.json");
    const n = Object.keys(data.probes.probes).length;
    $("timeline-note").textContent = n + " probes, " + data.probes.lines + " wire lines, " +
      "one value a second (" + Math.round(performance.now() - started) + " ms)" +
      (data.zero === null ? " · daemon time" : "");
  } catch (e) {
    $("timeline-note").textContent = "no wire log";
  }
  setRange();
  buildTimeline();
  seek(hadRange ? now : t1);
}
load();
