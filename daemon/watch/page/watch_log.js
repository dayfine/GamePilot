"use strict";

// --- Log, classification, filters and attempt/reset counter ------------------

const LOG_MODES = ["all", "important", "rng"];
let logMode = "all";
try {
  const saved = localStorage.getItem("watch.logMode");
  if (LOG_MODES.includes(saved)) logMode = saved;
} catch (e) {}

const logEntries = [];  // [{text, lower, level, isRng, el}]
let logVisible = 0;

// Attempt/reset badge state for the current checkpoint.
let attemptCheckpoint = null;
const attemptState = {
  kind: null,       // "attempt" | "reset" | "counter" | null
  current: 0,
  total: null,
  resets: 0,
  counterText: "",
  fromLog: false,
};

const NEGATIVE_SHINY_RE = /\b(not[_\s]shiny|no\s+shiny|does\s+not\s+show\s+the\s+shiny|missed\s+its\s+target|skipped\s+catch)\b/i;
const RNG_TOPIC_RE = /\b(wild\s+rng|rng|verdict=|wild_intro=|calibrat\w*|seed(?:_shift)?|advance[sd]?|target\s+frame|delay|soft\s+reset|hard\s+reset|reset\s*\(seq|reloading\s+for\s+attempt|attempt\s*#?\d+|resets?\s*[:#]\s*\d+|missed\s+its\s+target|not[_\s]shiny|skipped\s+catch|shiny\s+star|shiny)\b/i;
const ERROR_UPPER_RE = /\b(FAIL|FAILED|ERROR|EXCEPTION|TIMEOUT|STUCK|STOPPED)\b/;
const ERROR_LOWER_RE = /\b(failed|failure|error|timed?\s*out|stuck|refused|aborted|paused\s+for\s+user)\b/i;
const NO_ERROR_RE = /\b(0\s+(?:failed|errors?)|no\s+errors?)\b/i;
const SHINY_HIT_RE = /\b(verdict=shiny|shows\s+the\s+shiny\s+star|the\s+catch\s+is\s+shiny|shiny)\b/i;
const SUCCESS_RE = /\b(PASS|PASSED|caught|all_caught|completed|chain\s+done|series\s+passed|succeeded)\b/i;
const DIM_RE = /^(?:\[(?:Park|Settle)\]|Detected\b|Action:)/;

function classifyLog(line) {
  const isRng = RNG_TOPIC_RE.test(line);
  if (ERROR_UPPER_RE.test(line) || (ERROR_LOWER_RE.test(line) && !NO_ERROR_RE.test(line))) {
    return {level: "error", isRng};
  }
  if (DIM_RE.test(line)) {
    return {level: "dim", isRng: false};
  }
  if (!NEGATIVE_SHINY_RE.test(line) && SHINY_HIT_RE.test(line)) {
    return {level: "shiny", isRng: true};
  }
  if (isRng) {
    return {level: "rng", isRng: true};
  }
  if (SUCCESS_RE.test(line)) {
    return {level: "success", isRng: false};
  }
  return {level: "normal", isRng: false};
}

function logFilterQuery() {
  const input = $("log-filter");
  return input ? input.value.trim().toLowerCase() : "";
}

function matchesLogFilter(entry, mode, query) {
  if (mode === "important" && entry.level === "dim") return false;
  if (mode === "rng" && !entry.isRng && entry.level !== "error") return false;
  if (query && !entry.lower.includes(query)) return false;
  return true;
}

function updateLogCount() {
  const badge = $("log-count");
  if (!badge) return;
  const filtered = logMode !== "all" || logFilterQuery().length > 0;
  badge.hidden = !filtered || logEntries.length === 0;
  if (!badge.hidden) badge.textContent = logVisible + " / " + logEntries.length;
}

function hasLogSelection(log) {
  const sel = window.getSelection && window.getSelection();
  if (!sel || sel.isCollapsed || !sel.rangeCount) return false;
  return Boolean(
    (sel.anchorNode && log.contains(sel.anchorNode)) ||
    (sel.focusNode && log.contains(sel.focusNode))
  );
}

function applyLogFilter() {
  const log = $("log");
  const atBottom = log.scrollTop + log.clientHeight >= log.scrollHeight - 4;
  const query = logFilterQuery();
  let visible = 0;
  for (const entry of logEntries) {
    const show = matchesLogFilter(entry, logMode, query);
    entry.el.hidden = !show;
    if (show) visible++;
  }
  logVisible = visible;
  updateLogCount();
  if (atBottom && !hasLogSelection(log)) log.scrollTop = log.scrollHeight;
}

function setLogMode(next) {
  logMode = LOG_MODES.includes(next) ? next : "all";
  try { localStorage.setItem("watch.logMode", logMode); } catch (e) {}
  for (const b of document.querySelectorAll("#log-modes button")) {
    b.setAttribute("aria-pressed", String(b.dataset.logMode === logMode));
  }
  applyLogFilter();
}

function parseAttemptLine(line) {
  let m = line.match(/\battempt\s*#?\s*(\d+)\s*(?:\/|of)\s*(\d+)\b/i);
  if (m) return {kind: "attempt", current: Number(m[1]), total: Number(m[2])};
  m = line.match(/\b(\d+)\s+of\s+(\d+)\s+attempts?\b/i);
  if (m) return {kind: "attempt", current: Number(m[1]), total: Number(m[2])};
  m = line.match(/\breset\s*#?\s*(\d+)\s*(?:\/|of)\s*(\d+)\b/i);
  if (m) return {kind: "reset", current: Number(m[1]), total: Number(m[2])};
  m = line.match(/\battempt\s*#?\s*(\d+)\b/i);
  if (m) return {kind: "attempt", current: Number(m[1]), total: null};
  m = line.match(/\bresets?\s*[:#]\s*(\d+)\b/i);
  if (m) return {kind: "reset", current: Number(m[1]), total: null};
  if (/\b(?:wild\s+rng:\s*reset\b|soft\s+reset:\s*a\s*\+\s*b|hard\s+reset\b)/i.test(line)) {
    return {kind: "reset_inc"};
  }
  return null;
}

function renderAttemptBadge() {
  const badge = $("attempt-badge");
  if (!badge) return;
  let text = "";
  let title = "";
  if (attemptState.kind === "attempt" && attemptState.current > 0) {
    text = attemptState.total ? "Attempt " + attemptState.current + "/" + attemptState.total
                              : "Attempt " + attemptState.current;
    if (attemptState.resets > 0) title = "Resets seen: " + attemptState.resets;
  } else if (attemptState.kind === "reset" && attemptState.current > 0) {
    text = attemptState.total ? "Reset " + attemptState.current + "/" + attemptState.total
                              : "Resets: " + attemptState.current;
  } else if (attemptState.kind === "counter" && attemptState.counterText) {
    text = attemptState.counterText;
  } else if (attemptState.resets > 0) {
    text = "Resets: " + attemptState.resets;
  }
  badge.hidden = !text;
  badge.textContent = text;
  badge.title = title;
}

function updateAttemptFromLog(line) {
  const parsed = parseAttemptLine(line);
  if (!parsed) return;
  attemptState.fromLog = true;
  if (parsed.kind === "reset_inc") {
    attemptState.resets++;
  } else if (parsed.kind === "attempt") {
    const keepTotal = attemptState.kind === "attempt" ? attemptState.total : null;
    attemptState.kind = "attempt";
    attemptState.current = parsed.current;
    attemptState.total = parsed.total != null ? parsed.total : keepTotal;
  } else if (parsed.kind === "reset") {
    const keepTotal = attemptState.kind === "reset" ? attemptState.total : null;
    attemptState.kind = "reset";
    attemptState.current = parsed.current;
    attemptState.total = parsed.total != null ? parsed.total : keepTotal;
    attemptState.resets = Math.max(attemptState.resets, parsed.current);
  }
  renderAttemptBadge();
}

function updateAttemptFromStructured(current, total) {
  if (!current || current < 1) return;
  if (attemptState.fromLog && attemptState.current >= current) return;
  attemptState.kind = "attempt";
  attemptState.current = current;
  attemptState.total = total || null;
  renderAttemptBadge();
}

function updateAttemptFromCounter(label, value) {
  if (attemptState.fromLog) return;
  attemptState.kind = "counter";
  attemptState.counterText = label + ": " + value;
  renderAttemptBadge();
}

function resetAttemptForCheckpoint(checkpoint) {
  if (!checkpoint || checkpoint === attemptCheckpoint) return;
  attemptCheckpoint = checkpoint;
  attemptState.kind = null;
  attemptState.current = 0;
  attemptState.total = null;
  attemptState.resets = 0;
  attemptState.counterText = "";
  attemptState.fromLog = false;
  renderAttemptBadge();
}

function addLog(line) {
  const log = $("log");
  const atBottom = log.scrollTop + log.clientHeight >= log.scrollHeight - 4;
  const selecting = hasLogSelection(log);
  const info = classifyLog(line);
  const row = el("div", "log-line log-" + info.level, line);
  const entry = {text: line, lower: line.toLowerCase(), level: info.level, isRng: info.isRng, el: row};
  const show = matchesLogFilter(entry, logMode, logFilterQuery());
  row.hidden = !show;
  if (show) logVisible++;
  logEntries.push(entry);
  log.append(row);
  if (!selecting) {
    while (logEntries.length > LOG_LINES) {
      const dropped = logEntries.shift();
      if (!dropped.el.hidden) logVisible--;
      dropped.el.remove();
    }
  }
  updateLogCount();
  if (atBottom && !selecting) log.scrollTop = log.scrollHeight;
  lastLogLine = line;
  grindLine(line);
  updateAttemptFromLog(line);
  if (lastPlan && lastPlan.events.some((e) => e.state === "current")) renderPlan();
}

for (const b of document.querySelectorAll("#log-modes button")) {
  b.addEventListener("click", () => setLogMode(b.dataset.logMode));
}
if ($("log-filter")) {
  $("log-filter").addEventListener("input", applyLogFilter);
}
setLogMode(logMode);
