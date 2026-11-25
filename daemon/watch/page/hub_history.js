"use strict";

// --- All runs ------------------------------------------------------------------

const FILTERS = ["game", "program", "backend", "mode", "result", "since", "until", "q"];
const CHOICES = ["game", "program", "backend", "mode", "result"];
const UNKNOWN = "(unknown)";
const BACKEND_NAMES = {mgba: "mGBA", switch: "Switch", view: "View"};
// What a choice filter shows for a run's value: the registry's name.
const NAME_OF = {game: "game_name", program: "program_name"};
let allRuns = [];

// The sort: a column's key and its direction; newest first by default.
const SORT_DEFAULT = {key: "start", dir: "desc"};
let sort = {...SORT_DEFAULT};

// Each column's value to sort by; "" and 0 are unknown and always go last.
const runEnd = (r) => r.live ? Date.now() : r.ended_ms;
const SORT_KEYS = {
  run: (r) => r.run,
  game: (r) => r.game_name || r.game,
  program: (r) => r.program_name || r.program,
  checkpoint: (r) => r.checkpoint,
  backend: (r) => BACKEND_NAMES[r.backend] || r.backend,
  mode: (r) => r.mode || r.kind,
  result: (r) => r.result,
  start: (r) => r.started_ms,
  duration: (r) => r.started_ms && runEnd(r) ? runEnd(r) - r.started_ms : 0,
};
// Numbers start newest or longest first; text starts A to Z.
const FIRST_DIR = {start: "desc", duration: "desc"};

function compareRuns(a, b) {
  const key = SORT_KEYS[sort.key];
  const x = key(a), y = key(b);
  const known = (v) => v !== "" && v !== 0 && v != null;
  if (known(x) !== known(y)) return known(x) ? -1 : 1;
  let c = typeof x === "number" ? x - y : String(x).localeCompare(String(y), undefined, {numeric: true});
  if (sort.dir === "desc") c = -c;
  return c || (b.started_ms || 0) - (a.started_ms || 0) || (a.run < b.run ? 1 : -1);
}

function showSort() {
  for (const th of $("columns").children) {
    th.classList.add("sortable");
    if (th.dataset.sort === sort.key) th.setAttribute("aria-sort", sort.dir === "asc" ? "ascending" : "descending");
    else th.removeAttribute("aria-sort");
  }
}

function filterValues() {
  const form = $("filters");
  const values = {};
  for (const name of FILTERS) values[name] = form.elements[name].value;
  return values;
}
const grouped = () => $("filters").elements.group.checked;

// The filters from the URL (?backend=switch&result=fail), once at load.
function readQuery() {
  const query = new URLSearchParams(location.search);
  const form = $("filters");
  if (SORT_KEYS[query.get("sort")]) sort.key = query.get("sort");
  if (["asc", "desc"].includes(query.get("dir"))) sort.dir = query.get("dir");
  else if (query.get("sort")) sort.dir = FIRST_DIR[sort.key] || "asc";
  form.elements.group.checked = query.get("group") === "program";
  for (const name of FILTERS) {
    const v = query.get(name);
    if (v === null) continue;
    if (form.elements[name].tagName === "SELECT") {
      const select = form.elements[name];
      if (![...select.options].some((o) => o.value === v)) select.append(new Option(v, v));
    }
    form.elements[name].value = v;
  }
}

function writeQuery() {
  const query = new URLSearchParams();
  for (const [k, v] of Object.entries(filterValues())) if (v) query.set(k, v);
  query.set("sort", sort.key);
  query.set("dir", sort.dir);
  if (grouped()) query.set("group", "program");
  const text = query.toString();
  replaceUrl(location.pathname + (text ? "?" + text : ""));
}
function replaceUrl(url) {
  try { window.history.replaceState(null, "", url); } catch (e) {}
}

// Each choice filter offers the values the runs have, keeping the chosen one.
function fillChoices() {
  const form = $("filters");
  for (const name of CHOICES) {
    const select = form.elements[name];
    const chosen = select.value;
    const values = new Set(allRuns.map((r) => r[name] || UNKNOWN));
    if (chosen) values.add(chosen);
    const names = new Map();
    if (NAME_OF[name]) for (const r of allRuns) if (r[NAME_OF[name]]) names.set(r[name], r[NAME_OF[name]]);
    const label = (v) => name === "backend" ? (BACKEND_NAMES[v] || v) : (names.get(v) || v);
    select.replaceChildren(new Option("all", ""),
      ...[...values].sort((a, b) => label(a).localeCompare(label(b)))
        .map((v) => new Option(label(v), v)));
    select.value = chosen;
  }
}

// Local midnight of a yyyy-mm-dd input.
function dayStart(text) {
  const [y, m, d] = text.split("-").map(Number);
  return new Date(y, m - 1, d).getTime();
}

function matches(row, f) {
  for (const name of CHOICES) {
    if (f[name] && (row[name] || UNKNOWN) !== f[name]) return false;
  }
  const t = row.started_ms || row.ended_ms;
  if (f.since && (!t || t < dayStart(f.since))) return false;
  if (f.until && (!t || t >= dayStart(f.until) + 86400000)) return false;
  if (f.q) {
    const q = f.q.toLowerCase();
    const text = (row.run + " " + row.reason + " " + row.at).toLowerCase();
    if (!text.includes(q)) return false;
  }
  return true;
}

// "Nov 23 21:31", or "21:31" today.
function when(ms) {
  if (!ms) return "–";
  const d = new Date(ms);
  const hm = d.toLocaleTimeString([], {hour: "2-digit", minute: "2-digit", hour12: false});
  return d.toDateString() === new Date().toDateString() ? "today " + hm :
    d.toLocaleDateString([], {month: "short", day: "numeric"}) + " " + hm;
}

// from → to, the run's own checkpoint in bold.
function rangeCell(row) {
  const td = el("td", "range");
  const part = (id) => id === row.checkpoint ? el("b", "", id) : document.createTextNode(id || "–");
  if (!row.from || row.from === row.to) {
    td.append(part(row.checkpoint || row.from));
  } else {
    td.append(part(row.from), " → ", part(row.to));
    if (row.checkpoint !== row.from && row.checkpoint !== row.to) {
      td.append(" (", el("b", "", row.checkpoint), ")");
    }
  }
  return td;
}

function resultCell(row) {
  if (row.result === "running") return el("td", "running", "running");
  if (row.result === "pass") return el("td", "passed", "passed");
  if (row.result === "fail") {
    const td = el("td", "failed", "failed" + (row.at ? " at " + row.at : ""));
    if (row.reason) td.title = row.reason;
    return td;
  }
  return el("td", "muted", row.result || "–");
}

// A program's heading row: its name, group and run count.
function groupRow(row, count) {
  const td = el("td", "", row.program_name || row.program || UNKNOWN);
  td.colSpan = 9;
  td.append(el("span", "muted", [row.group, row.program, count + " run" + (count === 1 ? "" : "s")]
    .filter(Boolean).join(" · ")));
  const tr = el("tr", "group");
  tr.append(td);
  return tr;
}

// Grouped: by program name (unknown last), the sort inside each group.
function sortedRows(rows) {
  rows.sort(compareRuns);
  if (!grouped()) return rows;
  const name = (r) => r.program_name || r.program || "";
  return rows.map((r, i) => [r, i]).sort(([a, i], [b, j]) =>
    (!name(a) - !name(b)) || name(a).localeCompare(name(b)) || i - j).map(([r]) => r);
}

function renderHistory() {
  const body = $("history");
  const f = filterValues();
  const rows = sortedRows(allRuns.filter((r) => matches(r, f)));
  body.replaceChildren();
  showSort();
  let group = null;
  for (const row of rows) {
    const programId = row.program || "";
    if (grouped() && programId !== group) {
      group = programId;
      body.append(groupRow(row, rows.filter((r) => (r.program || "") === programId).length));
    }
    const tr = el("tr");
    const name = el("td");
    const link = el("a", "", row.run);
    link.href = runUrl(row.run);
    name.append(link);
    if (row.recorded) name.append(el("span", "tag", "frames"));
    if (row.result === "fail" && row.reason) name.append(el("div", "muted why", row.reason.slice(0, 90)));
    const end = row.live ? Date.now() : row.ended_ms;
    const game = el("td", "", row.game_name || row.game || "–");
    if (row.game_name) game.title = row.game;
    const program = el("td", "", row.program_name || row.program || "–");
    if (row.program_name) program.title = row.program + (row.group ? " · " + row.group : "");
    tr.append(name, game, program,
              rangeCell(row), el("td", "", BACKEND_NAMES[row.backend] || row.backend || "–"),
              el("td", "", row.mode || row.kind || "–"), resultCell(row),
              el("td", "num", when(row.started_ms)),
              el("td", "num", row.started_ms && end ? duration(end - row.started_ms) : "–"));
    body.append(tr);
  }
  if (!rows.length) {
    const td = el("td", "empty", allRuns.length ? "no run matches the filters" : "no runs yet");
    td.colSpan = 9;
    const tr = el("tr");
    tr.append(td);
    body.append(tr);
  }
  $("count").textContent = rows.length + " of " + allRuns.length + " runs";
}

async function pollHistory() {
  if (!document.hidden) {
    try {
      const reply = await fetch("history.json", {cache: "no-store"});
      allRuns = await reply.json();
      fillChoices();
      renderHistory();
    } catch (e) {}
  }
  setTimeout(pollHistory, HISTORY_POLL_MS);
}
const HISTORY_POLL_MS = 5000;

$("filters").addEventListener("input", () => { writeQuery(); renderHistory(); });
$("clear").addEventListener("click", () => {
  for (const name of FILTERS) $("filters").elements[name].value = "";
  writeQuery();
  renderHistory();
});
$("columns").addEventListener("click", (event) => {
  const th = event.target.closest("th");
  if (!th || !th.dataset.sort) return;
  sort = th.dataset.sort === sort.key ?
    {key: sort.key, dir: sort.dir === "asc" ? "desc" : "asc"} :
    {key: th.dataset.sort, dir: FIRST_DIR[th.dataset.sort] || "asc"};
  writeQuery();
  renderHistory();
});
readQuery();
showSort();
