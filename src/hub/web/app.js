let consoles = [];
let programs = [];
let selectedConsole = null;
let historyEntries = [];
let historyPage = 0;
const historyPageSize = 25;
let watchHubPort = 47901;

const HISTORY_CHOICES = ['game', 'program', 'backend', 'mode', 'result'];
const HISTORY_FILTERS = ['game', 'program', 'backend', 'mode', 'result', 'since', 'until', 'q'];
const HISTORY_FILTER_IDS = {
  game: 'historyGame',
  program: 'historyProgram',
  backend: 'historyBackend',
  mode: 'historyMode',
  result: 'historyResult',
  since: 'historySince',
  until: 'historyUntil',
  q: 'historySearch',
};
const HISTORY_UNKNOWN = '(unknown)';
const BACKEND_NAMES = { mgba: 'mGBA', switch: 'Switch', view: 'View' };
const NAME_OF = { game: 'game_name', program: 'program_name' };
const HISTORY_COLUMNS = [
  ['run', 'Run'],
  ['game', 'Game'],
  ['program', 'Program'],
  ['checkpoint', 'Checkpoints'],
  ['backend', 'Backend'],
  ['mode', 'Mode'],
  ['result', 'Result'],
  ['start', 'Started'],
  ['duration', 'Duration'],
];
const FIRST_SORT_DIR = { start: 'desc', duration: 'desc' };
let historySort = { key: 'start', dir: 'desc' };

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

function watchHref(url) {
  if (!url || typeof window === 'undefined' || !window.location) return url;
  return url.replace(
    /^http:\/\/(127\.0\.0\.1|localhost|0\.0\.0\.0)(?=[:/])/,
    'http://' + window.location.hostname
  );
}

function watchHubBase() {
  const host =
    (typeof window !== 'undefined' && window.location && window.location.hostname) ||
    '127.0.0.1';
  return 'http://' + host + ':' + watchHubPort;
}

function updateLiveLink() {
  const link = document.getElementById('liveRunLink');
  if (link) link.href = watchHubBase() + '/live';
}

function toggleAdd() {
  const sec = document.getElementById('addSection');
  sec.classList.toggle('hidden');
  if (!sec.classList.contains('hidden')) loadDevices();
}

async function loadDevices() {
  const r = await fetch('/api/devices');
  if (!r.ok) return;
  const d = await r.json();
  document.getElementById('serialList').innerHTML = (d.serial_ports || [])
    .map((s) => `<option value="${esc(s)}"></option>`)
    .join('');
  document.getElementById('captureList').innerHTML = (d.capture_devices || [])
    .map((c) => `<option value="${esc(c.index)}">${esc(c.name)} (${esc(c.device_id)})</option>`)
    .join('');
}

function toggleBackendFields() {
  const sw = document.getElementById('addBackend').value === 'switch';
  document.getElementById('lblCapture').classList.toggle('hidden', !sw);
  document.getElementById('lblSerial').classList.toggle('hidden', !sw);
  document.getElementById('lblPort').classList.toggle('hidden', sw);
}

async function saveConsole() {
  const err = document.getElementById('addErr');
  err.textContent = '';
  const backend = document.getElementById('addBackend').value;
  const body = {
    id: document.getElementById('addId').value.trim(),
    name: document.getElementById('addName').value.trim(),
    backend,
  };
  if (backend === 'switch') {
    body.capture = document.getElementById('addCapture').value.trim();
    const ser = document.getElementById('addSerial').value.trim();
    if (ser) body.serial = ser;
  } else {
    body.mgba_port = parseInt(document.getElementById('addPort').value, 10) || 47810;
  }
  const r = await fetch('/api/consoles', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const j = await r.json();
  if (!r.ok) {
    err.textContent = j.error || 'Failed to save';
    return;
  }
  toggleAdd();
  await loadConsoles();
}

async function loadConsoles() {
  const r = await fetch('/api/consoles');
  const j = await r.json();
  document.getElementById('cfgPath').textContent = 'Config: ' + (j.config_path || '');
  consoles = j.consoles || [];
  if (!selectedConsole && consoles.length) selectedConsole = consoles[0].id;
  document.getElementById('consoleCount').textContent = consoles.length + ' configured';
  const grid = document.getElementById('consolesGrid');
  if (!consoles.length) {
    grid.innerHTML =
      '<div class="muted">No consoles configured yet. Click "+ Add Console" or run <code>gamepilot setup</code>.</div>';
  } else {
    grid.innerHTML = consoles
      .map((c) => `
      <div class="console-card ${c.id === selectedConsole ? 'selected' : ''}" onclick="selectConsole('${esc(c.id)}')">
        <div class="card-top">
          <div class="card-title">${esc(c.name)} <span class="muted">(${esc(c.id)})</span></div>
          <span class="pill ${esc(c.status)}">${esc(c.status)}</span>
        </div>
        <div class="muted">${esc(c.backend.toUpperCase())} &mdash; ${esc(c.detail)}</div>
        ${c.active_run ? `<div class="muted" style="margin-top:6px">Running: <strong>${esc(c.active_run.program)}</strong>${c.active_run.external ? ` (external, pid ${esc(c.active_run.pid)})` : ''}${c.active_run.watch_url ? ` &middot; <a href="${esc(watchHref(c.active_run.watch_url))}" target="_blank" onclick="event.stopPropagation()">Open Watch Page</a>` : ''}</div>` : ''}
      </div>`)
      .join('');
  }
  updateSelectedLabel();
}

function selectConsole(id) {
  selectedConsole = id;
  loadConsoles();
}

function updateSelectedLabel() {
  const c = consoles.find((x) => x.id === selectedConsole);
  document.getElementById('selectedConsoleLabel').textContent = c
    ? 'Target: ' + c.name + ' (' + c.id + ')'
    : 'Select a console above';
}

async function loadPrograms() {
  const r = await fetch('/api/programs');
  const j = await r.json();
  programs = j.programs || [];
  const sel = document.getElementById('progSelect');
  sel.innerHTML = programs
    .map((p) => `<option value="${esc(p.id)}">${esc(p.game_name)} — ${esc(p.name)} (${esc(p.id)})</option>`)
    .join('');
  renderProgram();
}

function renderProgram() {
  const p = programs.find((x) => x.id === document.getElementById('progSelect').value);
  if (!p) return;
  document.getElementById('progDesc').textContent =
    p.description + '  [Backends: ' + p.backends.join(', ') + ']';
  const cps = p.checkpoints || [];
  const optsHtml = cps.map((c) => `<option value="${esc(c)}">${esc(c)}</option>`).join('');
  document.getElementById('fromSelect').innerHTML = optsHtml;
  document.getElementById('toSelect').innerHTML = optsHtml;
  if (cps.length) document.getElementById('toSelect').value = cps[cps.length - 1];
  const grid = document.getElementById('optsGrid');
  grid.innerHTML = (p.options || [])
    .map((o) => {
      const req = o.presence === 'required' ? ' *' : '';
      let ctrl = '';
      if (o.kind === 'one_of') {
        const blank = o.presence === 'optional' ? '<option value="">(default)</option>' : '';
        ctrl = `<select data-opt="${esc(o.key)}">${blank}${o.values.map((v) => `<option value="${esc(v)}" ${o.default === v ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select>`;
      } else if (o.kind === 'int_range') {
        ctrl = `<input type="number" data-opt="${esc(o.key)}" min="${o.min}" max="${o.max}" value="${esc(o.default ?? '')}" placeholder="${o.min}..${o.max}">`;
      } else {
        ctrl = `<input type="text" data-opt="${esc(o.key)}" value="${esc(o.default ?? '')}" placeholder="${esc(o.presence)}">`;
      }
      return `<label title="${esc(o.doc)}">${esc(o.key)}${req}${ctrl}<span class="muted">${esc(o.doc)}</span></label>`;
    })
    .join('');
}

async function launch(preflight) {
  const err = document.getElementById('launchErr');
  err.textContent = '';
  if (!selectedConsole) {
    err.textContent = 'Select a console first.';
    return;
  }
  const options = {};
  document.querySelectorAll('[data-opt]').forEach((el) => {
    if (el.value !== '') options[el.dataset.opt] = el.value;
  });
  const body = {
    console: selectedConsole,
    program: document.getElementById('progSelect').value,
    from: document.getElementById('fromSelect').value,
    to: document.getElementById('toSelect').value,
    mode: document.getElementById('modeSelect').value,
    preflight,
    options,
  };
  const r = await fetch('/api/runs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const j = await r.json();
  if (!r.ok) {
    err.textContent = j.error || 'Launch failed';
    return;
  }
  await refreshAll();
}

async function stopRun(id) {
  await fetch('/api/runs/' + encodeURIComponent(id) + '/stop', { method: 'POST' });
  await refreshAll();
}

const runCards = new Map();

function hasSelectionInside(el) {
  if (!el || typeof window === 'undefined' || typeof window.getSelection !== 'function') {
    return false;
  }
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed || !sel.rangeCount) return false;
  if (typeof el.contains !== 'function') return false;
  return Boolean(
    (sel.anchorNode && el.contains(sel.anchorNode)) ||
      (sel.focusNode && el.contains(sel.focusNode))
  );
}

function findLogOverlap(prev, next) {
  for (let shift = 0; shift < prev.length; shift++) {
    const overlap = prev.length - shift;
    if (overlap > next.length) continue;
    let same = true;
    for (let i = 0; i < overlap; i++) {
      if (prev[shift + i] !== next[i]) {
        same = false;
        break;
      }
    }
    if (same) return { shift, matched: overlap };
  }
  return null;
}

function makeLogLine(line) {
  const div = document.createElement('div');
  div.className = 'log-line';
  div.textContent = line;
  return div;
}

function syncRunLogs(entry, logs) {
  const nextLines = logs || [];
  if (!nextLines.length) {
    if (entry.pre && !hasSelectionInside(entry.pre)) {
      entry.pre.remove();
      entry.pre = null;
      entry.renderedLines = [];
    }
    return;
  }

  let isNewPre = false;
  if (!entry.pre) {
    const pre = document.createElement('pre');
    pre.className = 'run-log';
    entry.card.appendChild(pre);
    entry.pre = pre;
    entry.renderedLines = [];
    isNewPre = true;
  }

  const pre = entry.pre;
  const prevLines = entry.renderedLines;
  if (
    prevLines.length === nextLines.length &&
    prevLines.every((line, i) => line === nextLines[i])
  ) {
    return;
  }

  const selecting = hasSelectionInside(pre);
  const atBottom =
    isNewPre || pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 4;
  const overlap = findLogOverlap(prevLines, nextLines);

  if (overlap) {
    if (overlap.shift > 0 && !selecting) {
      for (let i = 0; i < overlap.shift && pre.firstChild; i++) {
        pre.removeChild(pre.firstChild);
      }
      prevLines.splice(0, overlap.shift);
    }
    for (let i = overlap.matched; i < nextLines.length; i++) {
      pre.appendChild(makeLogLine(nextLines[i]));
      prevLines.push(nextLines[i]);
    }
  } else if (prevLines.length === 0) {
    for (const line of nextLines) {
      pre.appendChild(makeLogLine(line));
      prevLines.push(line);
    }
  } else if (!selecting) {
    while (pre.firstChild) pre.removeChild(pre.firstChild);
    prevLines.length = 0;
    for (const line of nextLines) {
      pre.appendChild(makeLogLine(line));
      prevLines.push(line);
    }
  }

  if (atBottom && !selecting) {
    pre.scrollTop = pre.scrollHeight;
  }
}

function createRunCard(run) {
  const card = document.createElement('div');
  card.className = 'run-item';
  card.dataset.runId = run.id;

  const top = document.createElement('div');
  top.className = 'card-top';

  const title = document.createElement('div');
  const progStrong = document.createElement('strong');
  progStrong.textContent = run.program || '';
  const consStrong = document.createElement('strong');
  consStrong.textContent = run.console || '';
  const idSpan = document.createElement('span');
  idSpan.className = 'muted';
  idSpan.textContent = `(${run.id})`;
  title.appendChild(progStrong);
  title.appendChild(document.createTextNode(' on '));
  title.appendChild(consStrong);
  title.appendChild(document.createTextNode(' '));
  title.appendChild(idSpan);

  const actions = document.createElement('div');
  actions.className = 'row';

  const watchLink = document.createElement('a');
  watchLink.target = '_blank';
  watchLink.textContent = 'Open Watch Page';

  const extPill = document.createElement('span');
  extPill.className = 'pill stopped';
  extPill.textContent = 'external';

  const statusPill = document.createElement('span');

  const stopBtn = document.createElement('button');
  stopBtn.className = 'danger';
  stopBtn.textContent = 'Stop';
  stopBtn.onclick = () => stopRun(run.id);

  actions.appendChild(watchLink);
  actions.appendChild(extPill);
  actions.appendChild(statusPill);
  actions.appendChild(stopBtn);

  top.appendChild(title);
  top.appendChild(actions);

  const cmdEl = document.createElement('div');
  cmdEl.className = 'muted';

  card.appendChild(top);
  card.appendChild(cmdEl);

  const entry = {
    id: run.id,
    card,
    watchLink,
    extPill,
    statusPill,
    stopBtn,
    cmdEl,
    pre: null,
    renderedLines: [],
  };
  updateRunCard(entry, run);
  return entry;
}

function updateRunCard(entry, run) {
  const href = run.watch_url ? watchHref(run.watch_url) : '';
  entry.watchLink.classList.toggle('hidden', !href);
  if (href && entry.watchLink.href !== href) entry.watchLink.href = href;

  entry.extPill.classList.toggle('hidden', !run.external);

  const statusClass = 'pill ' + (run.status || '');
  if (entry.statusPill.className !== statusClass) entry.statusPill.className = statusClass;
  if (entry.statusPill.textContent !== (run.status || '')) {
    entry.statusPill.textContent = run.status || '';
  }

  const showStop = run.status === 'running' && !run.external;
  entry.stopBtn.classList.toggle('hidden', !showStop);

  const cmdText = '$ ' + (run.command || '');
  if (entry.cmdEl.textContent !== cmdText) entry.cmdEl.textContent = cmdText;

  syncRunLogs(entry, run.logs);
}

async function loadRuns() {
  const r = await fetch('/api/runs');
  const j = await r.json();
  const runs = j.runs || [];
  document.getElementById('runCount').textContent = runs.length + ' run(s)';
  const el = document.getElementById('runsList');
  if (!runs.length) {
    runCards.clear();
    el.innerHTML = '<div class="muted">No runs launched yet.</div>';
    return;
  }
  if (!runCards.size) {
    el.innerHTML = '';
  }
  const activeIds = new Set(runs.map((run) => run.id));
  for (const [id, entry] of runCards) {
    if (!activeIds.has(id)) {
      entry.card.remove();
      runCards.delete(id);
    }
  }
  runs.forEach((run, idx) => {
    let entry = runCards.get(run.id);
    if (!entry) {
      entry = createRunCard(run);
      runCards.set(run.id, entry);
    } else {
      updateRunCard(entry, run);
    }
    const currentAtIdx = el.children[idx];
    if (currentAtIdx !== entry.card) {
      el.insertBefore(entry.card, currentAtIdx || null);
    }
  });
}

// --- Run History ---------------------------------------------------------------

function runEndMs(r) {
  return r.result === 'running' ? Date.now() : r.ended_ms || 0;
}

const HISTORY_SORT_KEYS = {
  run: (r) => r.run || '',
  game: (r) => r.game_name || r.game || '',
  program: (r) => r.program_name || r.program || '',
  checkpoint: (r) => r.checkpoint || '',
  backend: (r) => BACKEND_NAMES[r.backend] || r.backend || '',
  mode: (r) => r.mode || r.kind || '',
  result: (r) => r.result || '',
  start: (r) => r.started_ms || 0,
  duration: (r) => (r.started_ms && runEndMs(r) ? runEndMs(r) - r.started_ms : 0),
};

function compareHistoryRuns(a, b) {
  const key = HISTORY_SORT_KEYS[historySort.key] || HISTORY_SORT_KEYS.start;
  const x = key(a);
  const y = key(b);
  const known = (v) => v !== '' && v !== 0 && v != null;
  if (known(x) !== known(y)) return known(x) ? -1 : 1;
  let c =
    typeof x === 'number'
      ? x - y
      : String(x).localeCompare(String(y), undefined, { numeric: true });
  if (historySort.dir === 'desc') c = -c;
  return c || (b.started_ms || 0) - (a.started_ms || 0) || (a.run < b.run ? 1 : -1);
}

function historyFilterValues() {
  const values = {};
  for (const name of HISTORY_FILTERS) {
    const el = document.getElementById(HISTORY_FILTER_IDS[name]);
    values[name] = el ? el.value || '' : '';
  }
  return values;
}

function isHistoryGrouped() {
  const el = document.getElementById('historyGroup');
  return Boolean(el && el.checked);
}

function readHistoryQuery() {
  if (typeof window === 'undefined' || !window.location || typeof URLSearchParams === 'undefined') {
    return;
  }
  const query = new URLSearchParams(window.location.search || '');
  const s = query.get('sort');
  if (s && HISTORY_SORT_KEYS[s]) historySort.key = s;
  const dir = query.get('dir');
  if (dir === 'asc' || dir === 'desc') historySort.dir = dir;
  else if (s && HISTORY_SORT_KEYS[s]) historySort.dir = FIRST_SORT_DIR[s] || 'asc';
  const grp = document.getElementById('historyGroup');
  if (grp) grp.checked = query.get('group') === 'program';
  for (const name of HISTORY_FILTERS) {
    const v = query.get(name);
    if (v === null) continue;
    const el = document.getElementById(HISTORY_FILTER_IDS[name]);
    if (el) el.value = v;
  }
}

function writeHistoryQuery() {
  if (
    typeof window === 'undefined' ||
    !window.location ||
    !window.history ||
    typeof window.history.replaceState !== 'function' ||
    typeof URLSearchParams === 'undefined'
  ) {
    return;
  }
  const query = new URLSearchParams();
  for (const [k, v] of Object.entries(historyFilterValues())) {
    if (v) query.set(k, v);
  }
  query.set('sort', historySort.key);
  query.set('dir', historySort.dir);
  if (isHistoryGrouped()) query.set('group', 'program');
  const text = query.toString();
  const base = window.location.pathname || '/';
  try {
    window.history.replaceState(null, '', base + (text ? '?' + text : ''));
  } catch (e) {}
}

function fillHistoryChoices() {
  for (const name of HISTORY_CHOICES) {
    const sel = document.getElementById(HISTORY_FILTER_IDS[name]);
    if (!sel) continue;
    const chosen = sel.value || '';
    const values = new Set(historyEntries.map((r) => r[name] || HISTORY_UNKNOWN));
    if (chosen) values.add(chosen);
    const names = new Map();
    if (NAME_OF[name]) {
      for (const r of historyEntries) {
        if (r[NAME_OF[name]]) names.set(r[name], r[NAME_OF[name]]);
      }
    }
    const label = (v) =>
      name === 'backend' ? BACKEND_NAMES[v] || v : names.get(v) || v;
    const sorted = Array.from(values).sort((a, b) => label(a).localeCompare(label(b)));
    sel.innerHTML =
      '<option value="">all</option>' +
      sorted.map((v) => `<option value="${esc(v)}">${esc(label(v))}</option>`).join('');
    sel.value = chosen;
  }
}

function dayStartMs(text) {
  const parts = String(text).split('-').map(Number);
  if (parts.length !== 3 || parts.some((n) => !Number.isFinite(n))) return 0;
  return new Date(parts[0], parts[1] - 1, parts[2]).getTime();
}

function matchesHistory(row, f) {
  for (const name of HISTORY_CHOICES) {
    if (f[name] && (row[name] || HISTORY_UNKNOWN) !== f[name]) return false;
  }
  const t = row.started_ms || row.ended_ms || 0;
  if (f.since && (!t || t < dayStartMs(f.since))) return false;
  if (f.until && (!t || t >= dayStartMs(f.until) + 86400000)) return false;
  if (f.q) {
    const q = f.q.toLowerCase();
    const hay = [
      row.run,
      row.game,
      row.game_name,
      row.program,
      row.program_name,
      row.checkpoint,
      row.from,
      row.to,
      row.reason,
      row.at,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    if (!hay.includes(q)) return false;
  }
  return true;
}

function formatWhen(ms) {
  if (!ms) return '–';
  const d = new Date(ms);
  const hm = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
  return d.toDateString() === new Date().toDateString()
    ? 'today ' + hm
    : d.toLocaleDateString([], { month: 'short', day: 'numeric' }) + ' ' + hm;
}

function formatDuration(ms) {
  const s = Math.max(0, Math.floor(ms / 1000));
  const two = (n) => String(n).padStart(2, '0');
  const h = Math.floor(s / 3600);
  const m = Math.floor(s / 60) % 60;
  return (h ? h + ':' + two(m) : String(m)) + ':' + two(s % 60);
}

function formatRangeHtml(row) {
  const part = (id) =>
    id === row.checkpoint ? `<b>${esc(id)}</b>` : esc(id || '–');
  if (!row.from || row.from === row.to) {
    return part(row.checkpoint || row.from);
  }
  let html = part(row.from) + ' → ' + part(row.to);
  if (row.checkpoint && row.checkpoint !== row.from && row.checkpoint !== row.to) {
    html += ` (<b>${esc(row.checkpoint)}</b>)`;
  }
  return html;
}

function formatResultHtml(row) {
  if (row.result === 'running') return '<span class="pill running">running</span>';
  if (row.result === 'pass') return '<span class="pill pass">passed</span>';
  if (row.result === 'fail') {
    const title = row.reason ? ` title="${esc(row.reason)}"` : '';
    const at = row.at ? ' at ' + esc(row.at) : '';
    return `<span class="pill fail"${title}>failed${at}</span>`;
  }
  return `<span class="muted">${esc(row.result || '–')}</span>`;
}

function sortedHistoryRows(rows) {
  const sorted = rows.slice().sort(compareHistoryRuns);
  if (!isHistoryGrouped()) return sorted;
  const name = (r) => r.program_name || r.program || '';
  return sorted
    .map((r, i) => [r, i])
    .sort(
      ([a, i], [b, j]) =>
        (!name(a) - !name(b)) || name(a).localeCompare(name(b)) || i - j
    )
    .map(([r]) => r);
}

function onHistoryFilter() {
  historyPage = 0;
  writeHistoryQuery();
  renderHistory();
}

function clearHistoryFilters() {
  for (const name of HISTORY_FILTERS) {
    const el = document.getElementById(HISTORY_FILTER_IDS[name]);
    if (el) el.value = '';
  }
  const grp = document.getElementById('historyGroup');
  if (grp) grp.checked = false;
  historyPage = 0;
  writeHistoryQuery();
  renderHistory();
}

function sortHistory(key) {
  if (!HISTORY_SORT_KEYS[key]) return;
  historySort =
    key === historySort.key
      ? { key, dir: historySort.dir === 'asc' ? 'desc' : 'asc' }
      : { key, dir: FIRST_SORT_DIR[key] || 'asc' };
  historyPage = 0;
  writeHistoryQuery();
  renderHistory();
}

function pageHistory(delta) {
  historyPage = Math.max(0, historyPage + delta);
  renderHistory();
}

function renderHistoryRow(row) {
  const isSeries = row.kind === 'series';
  const runUrl =
    watchHubBase() +
    (isSeries ? '/series/' : '/runs/') +
    encodeURIComponent(row.run) +
    '/';
  const seriesTag = isSeries ? '<span class="tag">series</span>' : '';
  const framesTag = row.recorded ? '<span class="tag">frames</span>' : '';
  const why =
    row.result === 'fail' && row.reason
      ? `<div class="muted why">${esc(row.reason.slice(0, 90))}</div>`
      : '';
  const gameTitle = row.game_name ? ` title="${esc(row.game)}"` : '';
  const progTitle = row.program_name
    ? ` title="${esc(row.program + (row.group ? ' · ' + row.group : ''))}"`
    : '';
  const end = runEndMs(row);
  const dur = row.started_ms && end ? formatDuration(end - row.started_ms) : '–';
  return `<tr>
    <td><a href="${esc(runUrl)}" target="_blank">${esc(row.run)}</a>${seriesTag}${framesTag}${why}</td>
    <td class="nowrap"${gameTitle}>${esc(row.game_name || row.game || '–')}</td>
    <td class="nowrap"${progTitle}>${esc(row.program_name || row.program || '–')}</td>
    <td class="range">${formatRangeHtml(row)}</td>
    <td class="nowrap">${esc(BACKEND_NAMES[row.backend] || row.backend || '–')}</td>
    <td class="nowrap">${esc(row.mode || row.kind || '–')}</td>
    <td class="nowrap">${formatResultHtml(row)}</td>
    <td class="num">${esc(formatWhen(row.started_ms))}</td>
    <td class="num">${esc(dur)}</td>
  </tr>`;
}

function renderHistory() {
  const f = historyFilterValues();
  const rows = sortedHistoryRows(historyEntries.filter((r) => matchesHistory(r, f)));
  const total = rows.length;
  const countEl = document.getElementById('historyCount');
  if (countEl) countEl.textContent = total + ' of ' + historyEntries.length + ' runs';

  const maxPage = Math.max(0, Math.ceil(total / historyPageSize) - 1);
  if (historyPage > maxPage) historyPage = maxPage;
  const start = historyPage * historyPageSize;
  const slice = rows.slice(start, start + historyPageSize);

  const thead = HISTORY_COLUMNS.map(([key, label]) => {
    const aria =
      historySort.key === key
        ? ` aria-sort="${historySort.dir === 'asc' ? 'ascending' : 'descending'}"`
        : '';
    return `<th class="sortable" data-sort="${key}"${aria} onclick="sortHistory('${key}')">${label}</th>`;
  }).join('');

  let bodyHtml = '';
  if (!slice.length) {
    const msg = historyEntries.length ? 'no run matches the filters' : 'no runs yet';
    bodyHtml = `<tr><td class="empty" colspan="9">${msg}</td></tr>`;
  } else {
    const grouped = isHistoryGrouped();
    let curGroup = null;
    const parts = [];
    for (const row of slice) {
      const pid = row.program || '';
      if (grouped && pid !== curGroup) {
        curGroup = pid;
        const n = rows.filter((r) => (r.program || '') === pid).length;
        const meta = [row.group, row.program, n + ' run' + (n === 1 ? '' : 's')]
          .filter(Boolean)
          .join(' · ');
        parts.push(
          `<tr class="group"><td colspan="9">${esc(row.program_name || row.program || HISTORY_UNKNOWN)}<span class="muted">${esc(meta)}</span></td></tr>`
        );
      }
      parts.push(renderHistoryRow(row));
    }
    bodyHtml = parts.join('');
  }

  document.getElementById('historyList').innerHTML =
    `<table><thead><tr id="historyColumns">${thead}</tr></thead><tbody>${bodyHtml}</tbody></table>`;

  const pager = document.getElementById('historyPager');
  pager.classList.toggle('hidden', total <= historyPageSize);
  document.getElementById('historyPageInfo').textContent =
    total ? `Showing ${start + 1}–${start + slice.length} of ${total}` : '';
  document.getElementById('historyPrev').disabled = historyPage === 0;
  document.getElementById('historyNext').disabled = historyPage >= maxPage;
}

async function loadHistory() {
  const r = await fetch('/api/history');
  if (!r.ok) return;
  const j = await r.json();
  if (j.watch_hub_port) watchHubPort = j.watch_hub_port;
  updateLiveLink();
  document.getElementById('historyDir').textContent = j.runs_dir || '';
  historyEntries = j.entries || [];
  fillHistoryChoices();
  renderHistory();
}

async function refreshAll() {
  await Promise.all([loadConsoles(), loadRuns(), loadHistory()]);
}

updateLiveLink();
readHistoryQuery();
loadPrograms();
refreshAll();
setInterval(refreshAll, 2000);
