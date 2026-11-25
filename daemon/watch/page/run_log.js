"use strict";

// --- Log ------------------------------------------------------------------------

function renderLog() {
  const box = $("log");
  box.replaceChildren();
  for (const [i, entry] of data.log.entries()) {
    const div = el("div", entry.unix_ms ? "timed" : "");
    div.dataset.i = i;
    if (entry.unix_ms) {
      div.append(el("span", "lt", clock(entry.unix_ms)));
      div.addEventListener("click", () => seek(entry.unix_ms));
    }
    div.append(entry.line);
    box.append(div);
  }
  if (!data.log.length) box.append(el("div", "note", "no story log"));
  $("log-note").textContent = data.log.length + " lines" +
    (data.timedLog ? "" : " · no times (older run): the scrubber cannot follow it");
}

// The last log line at or before `t`.
function logIndexAt(t) {
  let found = -1;
  for (let i = 0; i < data.log.length; i++) {
    if (data.log[i].unix_ms && data.log[i].unix_ms <= t) found = i;
    else if (data.log[i].unix_ms > t) break;
  }
  return found;
}

let shownLog = -1;
function markLog(scrollLog) {
  const i = data.timedLog ? logIndexAt(now) : -1;
  const box = $("log-at");
  box.replaceChildren();
  if (i >= 0) {
    for (let k = Math.max(0, i - 2); k <= i; k++) {
      box.append(el("div", k === i ? "now" : "", data.log[k].line));
    }
  } else {
    box.append(el("div", "note", data.timedLog ? "before the first story line" :
      "the story log has no times for this run"));
  }
  if (i === shownLog) return;
  const rows = $("log").children;
  if (shownLog >= 0 && rows[shownLog]) rows[shownLog].classList.remove("now");
  shownLog = i;
  if (i >= 0 && rows[i]) {
    rows[i].classList.add("now");
    if (scrollLog) {
      const box2 = $("log");
      box2.scrollTop = rows[i].offsetTop - box2.offsetTop - box2.clientHeight / 2;
    }
  }
}
