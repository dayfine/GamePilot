let consoles = [];
let programs = [];
let selectedConsole = null;
let historyEntries = [];
let historyPage = 0;
const historyPageSize = 25;

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

async function loadRuns() {
  const r = await fetch('/api/runs');
  const j = await r.json();
  const runs = j.runs || [];
  document.getElementById('runCount').textContent = runs.length + ' run(s)';
  const el = document.getElementById('runsList');
  if (!runs.length) {
    el.innerHTML = '<div class="muted">No runs launched yet.</div>';
    return;
  }
  el.innerHTML = runs
    .map((run) => `
    <div class="run-item">
      <div class="card-top">
        <div><strong>${esc(run.program)}</strong> on <strong>${esc(run.console)}</strong> <span class="muted">(${esc(run.id)})</span></div>
        <div class="row">
          ${run.watch_url ? `<a href="${esc(watchHref(run.watch_url))}" target="_blank">Open Watch Page</a>` : ''}
          ${run.external ? '<span class="pill stopped">external</span>' : ''}
          <span class="pill ${esc(run.status)}">${esc(run.status)}</span>
          ${run.status === 'running' && !run.external ? `<button class="danger" onclick="stopRun('${esc(run.id)}')">Stop</button>` : ''}
        </div>
      </div>
      <div class="muted">$ ${esc(run.command)}</div>
      ${(run.logs || []).length ? `<pre>${esc(run.logs.join('\n'))}</pre>` : ''}
    </div>`)
    .join('');
}

function onHistoryFilter() {
  historyPage = 0;
  renderHistory();
}

function pageHistory(delta) {
  historyPage = Math.max(0, historyPage + delta);
  renderHistory();
}

function renderHistory() {
  const q = (document.getElementById('historySearch').value || '').trim().toLowerCase();
  const gameFilter = document.getElementById('historyGame').value || 'all';
  const resFilter = document.getElementById('historyResult').value || 'all';
  const sort = document.getElementById('historySort').value || 'newest';
  let filtered = historyEntries.filter((e) => {
    if (gameFilter !== 'all' && (e.game || '') !== gameFilter) return false;
    if (resFilter !== 'all' && e.result !== resFilter) return false;
    if (!q) return true;
    const hay = `${e.game || ''} ${e.checkpoint} ${e.run} ${e.mode} ${e.at} ${e.reason}`.toLowerCase();
    return hay.includes(q);
  });
  if (sort === 'oldest') filtered = filtered.slice().reverse();

  const total = filtered.length;
  const maxPage = Math.max(0, Math.ceil(total / historyPageSize) - 1);
  if (historyPage > maxPage) historyPage = maxPage;
  const start = historyPage * historyPageSize;
  const slice = filtered.slice(start, start + historyPageSize);

  const el = document.getElementById('historyList');
  const pager = document.getElementById('historyPager');
  if (!total) {
    el.innerHTML = '<div class="muted">No matching runs in RESULTS.tsv.</div>';
    pager.classList.toggle('hidden', true);
    return;
  }
  el.innerHTML = `<table><thead><tr><th>Time</th><th>Game</th><th>Program / Checkpoint</th><th>Mode</th><th>Result</th><th>Detail</th></tr></thead><tbody>${slice.map((e) => `
    <tr>
      <td class="muted nowrap">${esc(e.time.replace('T', ' '))}</td>
      <td class="muted nowrap">${esc((e.game || '—').toUpperCase())}</td>
      <td class="nowrap"><strong>${esc(e.checkpoint)}</strong><div class="muted">${esc(e.run)}</div></td>
      <td class="muted nowrap">${esc(e.mode)}</td>
      <td class="nowrap"><span class="pill ${esc(e.result)}">${esc(e.result)}</span></td>
      <td class="muted detail">${esc([e.at, e.reason].filter(Boolean).join(' — '))}</td>
    </tr>`).join('')}</tbody></table>`;

  pager.classList.toggle('hidden', total <= historyPageSize);
  document.getElementById('historyPageInfo').textContent =
    `Showing ${start + 1}–${start + slice.length} of ${total}`;
  document.getElementById('historyPrev').disabled = historyPage === 0;
  document.getElementById('historyNext').disabled = historyPage >= maxPage;
}

async function loadHistory() {
  const r = await fetch('/api/history');
  if (!r.ok) return;
  const j = await r.json();
  document.getElementById('historyDir').textContent = j.runs_dir || '';
  historyEntries = j.entries || [];
  const gameSel = document.getElementById('historyGame');
  const prev = gameSel.value || 'all';
  const games = Array.from(new Set(historyEntries.map((e) => e.game).filter(Boolean))).sort();
  gameSel.innerHTML =
    '<option value="all">all</option>' +
    games.map((g) => `<option value="${esc(g)}">${esc(g.toUpperCase())}</option>`).join('');
  gameSel.value = games.includes(prev) ? prev : 'all';
  renderHistory();
}

async function refreshAll() {
  await Promise.all([loadConsoles(), loadRuns(), loadHistory()]);
}

loadPrograms();
refreshAll();
setInterval(refreshAll, 2000);
