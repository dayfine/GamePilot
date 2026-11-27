let html =
  {|<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>GamePilot Hub</title>
<style>
  :root { --bg:#0f1218; --card:#171c26; --border:#273042; --text:#e6edf7; --muted:#8b9bb4; --accent:#4da3ff; --ok:#3ad29f; --warn:#f6b73c; --err:#ff5c77; }
  * { box-sizing:border-box; }
  body { margin:0; font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; background:var(--bg); color:var(--text); }
  header { display:flex; align-items:center; justify-content:space-between; padding:14px 24px; border-bottom:1px solid var(--border); background:#131822; }
  header h1 { margin:0; font-size:18px; letter-spacing:.2px; }
  .muted { color:var(--muted); font-size:12px; }
  main { max-width:1120px; margin:0 auto; padding:20px 24px 48px; display:grid; gap:20px; }
  section { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:16px 18px; }
  section h2 { margin:0 0 12px; font-size:15px; display:flex; align-items:center; justify-content:space-between; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(270px,1fr)); gap:12px; }
  .console-card { border:1px solid var(--border); border-radius:8px; padding:12px 14px; background:#121720; cursor:pointer; transition:border-color .15s; }
  .console-card:hover { border-color:#445577; }
  .console-card.selected { border-color:var(--accent); box-shadow:0 0 0 1px var(--accent); }
  .card-top { display:flex; align-items:center; justify-content:space-between; gap:8px; margin-bottom:6px; }
  .card-title { font-weight:600; font-size:15px; }
  .pill { font-size:11px; font-weight:600; padding:2px 8px; border-radius:99px; text-transform:uppercase; }
  .pill.ready, .pill.passed { background:rgba(58,210,159,.15); color:var(--ok); }
  .pill.running { background:rgba(77,163,255,.18); color:var(--accent); }
  .pill.offline, .pill.failed { background:rgba(255,92,119,.16); color:var(--err); }
  .pill.stopped { background:rgba(246,183,60,.16); color:var(--warn); }
  .row { display:flex; flex-wrap:wrap; gap:10px; align-items:flex-end; }
  label { display:flex; flex-direction:column; gap:4px; font-size:12px; color:var(--muted); min-width:160px; }
  input, select { background:#0d1118; color:var(--text); border:1px solid var(--border); border-radius:6px; padding:7px 9px; font:inherit; }
  button { background:var(--accent); color:#08111f; border:none; border-radius:6px; padding:8px 14px; font-weight:600; cursor:pointer; }
  button.secondary { background:#232c3d; color:var(--text); }
  button.danger { background:var(--err); color:#fff; }
  button:disabled { opacity:.45; cursor:not-allowed; }
  .opts { display:grid; grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:10px; margin-top:12px; }
  .run-item { border:1px solid var(--border); border-radius:8px; padding:10px 12px; background:#121720; margin-top:10px; }
  pre { margin:8px 0 0; padding:10px; background:#0a0d12; border-radius:6px; overflow:auto; max-height:200px; font-size:12px; color:#c8d4e6; }
  .err-banner { color:var(--err); margin-top:8px; font-size:13px; }
  .hidden { display:none; }
  a { color:var(--accent); }
</style>
</head>
<body>
<header>
  <div>
    <h1>GamePilot Control Hub</h1>
    <div id="cfgPath" class="muted">Loading...</div>
  </div>
  <div class="row">
    <button class="secondary" onclick="toggleAdd()">+ Add Console</button>
    <button class="secondary" onclick="refreshAll()">Refresh</button>
  </div>
</header>
<main>
  <section id="addSection" class="hidden">
    <h2>Add or Update Console</h2>
    <div class="row">
      <label>ID <input id="addId" placeholder="console-a"></label>
      <label>Name <input id="addName" placeholder="Console A"></label>
      <label>Backend
        <select id="addBackend" onchange="toggleBackendFields()">
          <option value="switch">Switch</option>
          <option value="mgba">mGBA</option>
        </select>
      </label>
      <label id="lblCapture">Capture Device <input id="addCapture" list="captureList" placeholder="0"></label>
      <datalist id="captureList"></datalist>
      <label id="lblSerial">Serial Port <input id="addSerial" list="serialList" placeholder="/dev/cu.usbmodem..."></label>
      <datalist id="serialList"></datalist>
      <label id="lblPort" class="hidden">mGBA Port <input id="addPort" type="number" value="47810"></label>
      <button onclick="saveConsole()">Save</button>
      <button class="secondary" onclick="toggleAdd()">Cancel</button>
    </div>
    <div id="addErr" class="err-banner"></div>
  </section>

  <section>
    <h2><span>Consoles</span><span id="consoleCount" class="muted"></span></h2>
    <div id="consolesGrid" class="grid"></div>
  </section>

  <section>
    <h2><span>Launch Program</span><span id="selectedConsoleLabel" class="muted"></span></h2>
    <div class="row">
      <label style="min-width:260px">Program
        <select id="progSelect" onchange="renderProgram()"></select>
      </label>
      <label>From Checkpoint <select id="fromSelect"></select></label>
      <label>To Checkpoint <select id="toSelect"></select></label>
      <label>Mode
        <select id="modeSelect">
          <option value="testing" selected>testing (single pass)</option>
          <option value="verification">verification (3 passes)</option>
        </select>
      </label>
    </div>
    <div id="progDesc" class="muted" style="margin-top:8px"></div>
    <div id="optsGrid" class="opts"></div>
    <div class="row" style="margin-top:14px">
      <button class="secondary" onclick="launch(true)">Preflight Check</button>
      <button onclick="launch(false)">Run (--watch)</button>
    </div>
    <div id="launchErr" class="err-banner"></div>
  </section>

  <section>
    <h2><span>Active &amp; Recent Runs</span><span id="runCount" class="muted"></span></h2>
    <div id="runsList" class="muted">No runs launched yet.</div>
  </section>
</main>
<script>
let consoles = [], programs = [], selectedConsole = null;

function esc(s) { return String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function toggleAdd() {
  const sec = document.getElementById('addSection');
  sec.classList.toggle('hidden');
  if (!sec.classList.contains('hidden')) loadDevices();
}
async function loadDevices() {
  const r = await fetch('/api/devices');
  if (!r.ok) return;
  const d = await r.json();
  document.getElementById('serialList').innerHTML = (d.serial_ports || []).map(s => `<option value="${esc(s)}"></option>`).join('');
  document.getElementById('captureList').innerHTML = (d.capture_devices || []).map(c => `<option value="${esc(c.index)}">${esc(c.name)} (${esc(c.device_id)})</option>`).join('');
}
function toggleBackendFields() {
  const sw = document.getElementById('addBackend').value === 'switch';
  document.getElementById('lblCapture').classList.toggle('hidden', !sw);
  document.getElementById('lblSerial').classList.toggle('hidden', !sw);
  document.getElementById('lblPort').classList.toggle('hidden', sw);
}

async function saveConsole() {
  const err = document.getElementById('addErr'); err.textContent = '';
  const backend = document.getElementById('addBackend').value;
  const body = { id: document.getElementById('addId').value.trim(), name: document.getElementById('addName').value.trim(), backend };
  if (backend === 'switch') {
    body.capture = document.getElementById('addCapture').value.trim();
    const ser = document.getElementById('addSerial').value.trim();
    if (ser) body.serial = ser;
  } else {
    body.mgba_port = parseInt(document.getElementById('addPort').value, 10) || 47810;
  }
  const r = await fetch('/api/consoles', { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body) });
  const j = await r.json();
  if (!r.ok) { err.textContent = j.error || 'Failed to save'; return; }
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
    grid.innerHTML = '<div class="muted">No consoles configured yet. Click "+ Add Console" or run <code>gamepilot setup</code>.</div>';
  } else {
    grid.innerHTML = consoles.map(c => `
      <div class="console-card ${c.id === selectedConsole ? 'selected' : ''}" onclick="selectConsole('${esc(c.id)}')">
        <div class="card-top">
          <div class="card-title">${esc(c.name)} <span class="muted">(${esc(c.id)})</span></div>
          <span class="pill ${esc(c.status)}">${esc(c.status)}</span>
        </div>
        <div class="muted">${esc(c.backend.toUpperCase())} &mdash; ${esc(c.detail)}</div>
        ${c.active_run ? `<div class="muted" style="margin-top:6px">Running: <strong>${esc(c.active_run.program)}</strong>${c.active_run.external ? ` (external, pid ${esc(c.active_run.pid)})` : ''}${c.active_run.watch_url ? ` &middot; <a href="${esc(c.active_run.watch_url)}" target="_blank" onclick="event.stopPropagation()">Open Watch Page</a>` : ''}</div>` : ''}
      </div>`).join('');
  }
  updateSelectedLabel();
}

function selectConsole(id) { selectedConsole = id; loadConsoles(); }
function updateSelectedLabel() {
  const c = consoles.find(x => x.id === selectedConsole);
  document.getElementById('selectedConsoleLabel').textContent = c ? ('Target: ' + c.name + ' (' + c.id + ')') : 'Select a console above';
}

async function loadPrograms() {
  const r = await fetch('/api/programs');
  const j = await r.json();
  programs = j.programs || [];
  const sel = document.getElementById('progSelect');
  sel.innerHTML = programs.map(p => `<option value="${esc(p.id)}">${esc(p.game_name)} — ${esc(p.name)} (${esc(p.id)})</option>`).join('');
  renderProgram();
}

function renderProgram() {
  const p = programs.find(x => x.id === document.getElementById('progSelect').value);
  if (!p) return;
  document.getElementById('progDesc').textContent = p.description + '  [Backends: ' + p.backends.join(', ') + ']';
  const cps = p.checkpoints || [];
  const optsHtml = cps.map(c => `<option value="${esc(c)}">${esc(c)}</option>`).join('');
  document.getElementById('fromSelect').innerHTML = optsHtml;
  document.getElementById('toSelect').innerHTML = optsHtml;
  if (cps.length) document.getElementById('toSelect').value = cps[cps.length - 1];
  const grid = document.getElementById('optsGrid');
  grid.innerHTML = (p.options || []).map(o => {
    const req = o.presence === 'required' ? ' *' : '';
    let ctrl = '';
    if (o.kind === 'one_of') {
      const blank = o.presence === 'optional' ? '<option value="">(default)</option>' : '';
      ctrl = `<select data-opt="${esc(o.key)}">${blank}${o.values.map(v => `<option value="${esc(v)}" ${o.default === v ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select>`;
    } else if (o.kind === 'int_range') {
      ctrl = `<input type="number" data-opt="${esc(o.key)}" min="${o.min}" max="${o.max}" value="${esc(o.default ?? '')}" placeholder="${o.min}..${o.max}">`;
    } else {
      ctrl = `<input type="text" data-opt="${esc(o.key)}" value="${esc(o.default ?? '')}" placeholder="${esc(o.presence)}">`;
    }
    return `<label title="${esc(o.doc)}">${esc(o.key)}${req}${ctrl}<span class="muted">${esc(o.doc)}</span></label>`;
  }).join('');
}

async function launch(preflight) {
  const err = document.getElementById('launchErr'); err.textContent = '';
  if (!selectedConsole) { err.textContent = 'Select a console first.'; return; }
  const options = {};
  document.querySelectorAll('[data-opt]').forEach(el => { if (el.value !== '') options[el.dataset.opt] = el.value; });
  const body = {
    console: selectedConsole,
    program: document.getElementById('progSelect').value,
    from: document.getElementById('fromSelect').value,
    to: document.getElementById('toSelect').value,
    mode: document.getElementById('modeSelect').value,
    preflight, options
  };
  const r = await fetch('/api/runs', { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body) });
  const j = await r.json();
  if (!r.ok) { err.textContent = j.error || 'Launch failed'; return; }
  await refreshAll();
}

async function stopRun(id) {
  await fetch('/api/runs/' + encodeURIComponent(id) + '/stop', { method:'POST' });
  await refreshAll();
}

async function loadRuns() {
  const r = await fetch('/api/runs');
  const j = await r.json();
  const runs = j.runs || [];
  document.getElementById('runCount').textContent = runs.length + ' run(s)';
  const el = document.getElementById('runsList');
  if (!runs.length) { el.innerHTML = '<div class="muted">No runs launched yet.</div>'; return; }
  el.innerHTML = runs.map(run => `
    <div class="run-item">
      <div class="card-top">
        <div><strong>${esc(run.program)}</strong> on <strong>${esc(run.console)}</strong> <span class="muted">(${esc(run.id)})</span></div>
        <div class="row">
          ${run.watch_url ? `<a href="${esc(run.watch_url)}" target="_blank">Open Watch Page</a>` : ''}
          ${run.external ? '<span class="pill stopped">external</span>' : ''}
          <span class="pill ${esc(run.status)}">${esc(run.status)}</span>
          ${run.status === 'running' && !run.external ? `<button class="danger" onclick="stopRun('${esc(run.id)}')">Stop</button>` : ''}
        </div>
      </div>
      <div class="muted">$ ${esc(run.command)}</div>
      <pre>${esc((run.logs || []).join('\n'))}</pre>
    </div>`).join('');
}

async function refreshAll() { await Promise.all([loadConsoles(), loadRuns()]); }
loadPrograms();
refreshAll();
setInterval(refreshAll, 2000);
</script>
</body>
</html>
|}
