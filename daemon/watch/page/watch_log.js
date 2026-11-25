"use strict";

// --- Log ---------------------------------------------------------------------

function addLog(line) {
  const log = $("log");
  const atBottom = log.scrollTop + log.clientHeight >= log.scrollHeight - 4;
  log.append(line + "\n");
  while (log.childNodes.length > LOG_LINES) log.removeChild(log.firstChild);
  if (atBottom) log.scrollTop = log.scrollHeight;
  lastLogLine = line;
  grindLine(line);
  if (lastPlan && lastPlan.events.some((e) => e.state === "current")) renderPlan();
}
