#!/usr/bin/env node
// Optional dev/CI JS tests for the GamePilot Control Hub web frontend
// (src/hub/web/index.html + src/hub/web/app.js) using Node's built-in
// node:test and vm (zero npm packages). Node is NOT a build or runtime
// dependency of gamepilot itself; CI runs this on Linux where Node is
// preinstalled.
//
// Run: node --test src/hub/test/test_hub_ui.mjs

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const webDir = path.resolve(
  path.dirname(new URL(import.meta.url).pathname),
  '../web'
);

function loadWebAssets() {
  const html = fs.readFileSync(path.join(webDir, 'index.html'), 'utf8');
  const script = fs.readFileSync(path.join(webDir, 'app.js'), 'utf8');
  return { html, script };
}

function makeFakeElement(id) {
  const classes = new Set();
  return {
    id,
    innerHTML: '',
    textContent: '',
    value: '',
    href: '',
    checked: false,
    disabled: false,
    dataset: {},
    classList: {
      toggle(c, force) {
        if (force === undefined) {
          if (classes.has(c)) classes.delete(c);
          else classes.add(c);
        } else if (force) {
          classes.add(c);
        } else {
          classes.delete(c);
        }
      },
      contains(c) {
        return classes.has(c);
      },
    },
  };
}

function createHubSandbox(mockRoutes, opts = {}) {
  const { html, script } = loadWebAssets();
  const ids = [
    'cfgPath',
    'liveRunLink',
    'addSection',
    'addId',
    'addName',
    'addBackend',
    'addCapture',
    'addSerial',
    'addPort',
    'lblCapture',
    'lblSerial',
    'lblPort',
    'addErr',
    'captureList',
    'serialList',
    'consoleCount',
    'consolesGrid',
    'selectedConsoleLabel',
    'progSelect',
    'fromSelect',
    'toSelect',
    'modeSelect',
    'progDesc',
    'optsGrid',
    'launchErr',
    'runCount',
    'runsList',
    'historyDir',
    'historyList',
    'historyGame',
    'historyProgram',
    'historyBackend',
    'historyMode',
    'historyResult',
    'historySince',
    'historyUntil',
    'historySearch',
    'historyGroup',
    'historyClear',
    'historyCount',
    'historyPager',
    'historyPageInfo',
    'historyPrev',
    'historyNext',
  ];
  const els = Object.fromEntries(ids.map((id) => [id, makeFakeElement(id)]));
  els.addSection.classList.toggle('hidden', true);
  els.modeSelect.value = 'default';
  els.addBackend.value = 'switch';

  const optInputs = [];
  const fetchLog = [];
  const replacedUrls = [];

  const document = {
    getElementById(id) {
      assert.ok(els[id], `unexpected getElementById(${id})`);
      return els[id];
    },
    querySelectorAll(sel) {
      if (sel === '[data-opt]') return optInputs;
      return [];
    },
  };

  async function fetch(url, init = {}) {
    const method = (init.method || 'GET').toUpperCase();
    const body = init.body ? JSON.parse(init.body) : null;
    fetchLog.push({ method, url, body });
    const handler = mockRoutes[`${method} ${url}`];
    assert.ok(handler, `unmocked fetch: ${method} ${url}`);
    const res = typeof handler === 'function' ? handler(body) : handler;
    return {
      ok: (res.status || 200) >= 200 && (res.status || 200) < 300,
      status: res.status || 200,
      async json() {
        return res.json;
      },
    };
  }

  const sandbox = {
    document,
    window: {
      location: {
        hostname: 'Mac-mini.local',
        pathname: '/',
        search: opts.search || '',
      },
      history: {
        replaceState(_s, _t, url) {
          replacedUrls.push(url);
        },
      },
    },
    URLSearchParams,
    fetch,
    setInterval: () => 0,
    encodeURIComponent,
    parseInt,
    console,
  };
  vm.createContext(sandbox);
  vm.runInContext(script, sandbox);
  return { html, sandbox, els, optInputs, fetchLog, replacedUrls };
}

const sampleFixtures = () => ({
  'GET /api/consoles': {
    json: {
      config_path: '/tmp/consoles.json',
      consoles: [
        {
          id: 'console-a',
          name: 'Console A',
          backend: 'switch',
          ready: true,
          status: 'running',
          detail: 'serial /dev/cu.usbmodemA, capture 0',
          active_run: {
            id: 'ext-80610',
            program: 'bdsp.underground',
            external: true,
            pid: 80610,
            watch_url: 'http://127.0.0.1:57023/',
          },
        },
        {
          id: 'console-b',
          name: 'Console B',
          backend: 'switch',
          ready: true,
          status: 'ready',
          detail: 'serial /dev/cu.usbmodemB, capture 1',
          active_run: null,
        },
      ],
    },
  },
  'GET /api/programs': {
    json: {
      programs: [
        {
          id: 'frlg.supplies',
          name: 'Supplies',
          game_name: 'Pokemon FireRed / LeafGreen',
          description: 'Stock Retro Mail and Super Repel.',
          backends: ['mgba', 'switch'],
          checkpoints: ['su-01'],
          options: [
            {
              key: 'retro-mail',
              doc: 'Retro Mail count',
              kind: 'int_range',
              min: 0,
              max: 999,
              presence: 'default',
              default: '100',
            },
          ],
        },
      ],
    },
  },
  'GET /api/runs': {
    json: {
      runs: [
        {
          id: 'ext-80610',
          console: 'console-a',
          program: 'bdsp.underground',
          command: 'gamepilot_daemon ...',
          status: 'running',
          external: true,
          watch_url: 'http://127.0.0.1:57023/',
          logs: [],
        },
      ],
    },
  },
  'GET /api/devices': {
    json: {
      serial_ports: ['/dev/cu.usbmodemA', '/dev/cu.usbmodemB'],
      capture_devices: [{ index: '0', device_id: '0x1100', name: 'USB Video' }],
    },
  },
  'GET /api/history': {
    json: {
      runs_dir: '/tmp/runs',
      watch_hub_port: 47901,
      entries: [
        {
          run: '2026-11-26-bdsp.underground-run-15',
          kind: 'checkpoints',
          game: 'bdsp',
          game_name: 'Pokemon BDSP',
          program: 'bdsp.underground',
          program_name: 'Underground',
          group: 'Farming',
          checkpoint: 'bdsp.underground',
          from: 'bdsp.underground',
          to: 'bdsp.underground',
          backend: 'switch',
          mode: 'run',
          result: 'pass',
          at: '',
          reason: '',
          started_ms: 1795700000000,
          ended_ms: 1795700125000,
          recorded: true,
        },
        {
          run: '2026-11-25-su-01-testing-3',
          kind: 'checkpoints',
          game: 'frlg',
          game_name: 'Pokemon FireRed / LeafGreen',
          program: 'frlg.supplies',
          program_name: 'Supplies',
          group: 'Farming',
          checkpoint: 'su-01',
          from: 'su-01',
          to: 'su-02',
          backend: 'mgba',
          mode: 'testing',
          result: 'fail',
          at: '#4 mart',
          reason: 'menu cursor timed out',
          started_ms: 1795600000000,
          ended_ms: 1795600060000,
          recorded: false,
        },
      ],
    },
  },
});

test('Hub HTML offers default/verification modes and Newest Live Run link', () => {
  const { html } = loadWebAssets();
  assert.match(html, /<option value="default" selected>default<\/option>/);
  assert.match(html, /<option value="verification">verification<\/option>/);
  assert.match(html, /id="liveRunLink"/);
  assert.match(html, /Newest Live Run/);
  assert.match(html, /<link rel="stylesheet" href="\/style\.css">/);
  assert.match(html, /<script src="\/app\.js"><\/script>/);
});

test('Initial load renders consoles, Newest Live Run link, and full 9-column Run History', async () => {
  const { sandbox, els } = createHubSandbox(sampleFixtures());
  await sandbox.refreshAll();
  assert.equal(els.liveRunLink.href, 'http://Mac-mini.local:47901/live');
  assert.equal(els.consoleCount.textContent, '2 configured');
  assert.match(els.consolesGrid.innerHTML, /Console A/);
  assert.match(els.consolesGrid.innerHTML, /bdsp\.underground/);
  assert.match(els.consolesGrid.innerHTML, /http:\/\/Mac-mini\.local:57023\//);
  assert.match(els.consolesGrid.innerHTML, /Console B/);
  assert.equal(els.runCount.textContent, '1 run(s)');
  assert.doesNotMatch(els.runsList.innerHTML, /stopRun\('ext-80610'\)/);
  assert.equal(els.historyCount.textContent, '2 of 2 runs');
  assert.match(
    els.historyList.innerHTML,
    /http:\/\/Mac-mini\.local:47901\/runs\/2026-11-26-bdsp\.underground-run-15\//
  );
  assert.match(els.historyList.innerHTML, /<span class="tag">frames<\/span>/);
  assert.match(els.historyList.innerHTML, /<b>su-01<\/b> → su-02/);
  assert.match(els.historyList.innerHTML, /failed at #4 mart/);
  assert.match(els.historyList.innerHTML, /menu cursor timed out/);
  assert.match(els.historyList.innerHTML, /Switch/);
  assert.match(els.historyList.innerHTML, /mGBA/);
  assert.match(els.historyList.innerHTML, /2:05/);
});

test('Run History filters, Group by program, Clear, and column sorting work', async () => {
  const { sandbox, els } = createHubSandbox(sampleFixtures());
  await sandbox.refreshAll();

  // Filter by Game
  els.historyGame.value = 'frlg';
  sandbox.onHistoryFilter();
  assert.equal(els.historyCount.textContent, '1 of 2 runs');
  assert.match(els.historyList.innerHTML, /2026-11-25-su-01-testing-3/);
  assert.doesNotMatch(els.historyList.innerHTML, /bdsp\.underground-run-15/);

  // Filter by Backend + Mode + Result + Program + Search
  sandbox.clearHistoryFilters();
  assert.equal(els.historyCount.textContent, '2 of 2 runs');

  els.historyProgram.value = 'bdsp.underground';
  els.historyBackend.value = 'switch';
  els.historyMode.value = 'run';
  els.historyResult.value = 'pass';
  sandbox.onHistoryFilter();
  assert.equal(els.historyCount.textContent, '1 of 2 runs');
  assert.match(els.historyList.innerHTML, /bdsp\.underground-run-15/);

  // Search by failure reason after clearing
  sandbox.clearHistoryFilters();
  els.historySearch.value = 'cursor timed out';
  sandbox.onHistoryFilter();
  assert.equal(els.historyCount.textContent, '1 of 2 runs');
  assert.match(els.historyList.innerHTML, /2026-11-25-su-01-testing-3/);

  // Group by program
  sandbox.clearHistoryFilters();
  els.historyGroup.checked = true;
  sandbox.onHistoryFilter();
  assert.match(els.historyList.innerHTML, /<tr class="group">/);
  assert.match(els.historyList.innerHTML, /Supplies/);
  assert.match(els.historyList.innerHTML, /Underground/);

  // Column sorting: click 'run' -> asc, click again -> desc
  els.historyGroup.checked = false;
  sandbox.sortHistory('run');
  assert.match(els.historyList.innerHTML, /data-sort="run" aria-sort="ascending"/);
  const idxFrlgAsc = els.historyList.innerHTML.indexOf('2026-11-25-su-01-testing-3');
  const idxBdspAsc = els.historyList.innerHTML.indexOf('2026-11-26-bdsp.underground-run-15');
  assert.ok(idxFrlgAsc < idxBdspAsc, 'expected ascending run order');

  sandbox.sortHistory('run');
  assert.match(els.historyList.innerHTML, /data-sort="run" aria-sort="descending"/);
  const idxFrlgDesc = els.historyList.innerHTML.indexOf('2026-11-25-su-01-testing-3');
  const idxBdspDesc = els.historyList.innerHTML.indexOf('2026-11-26-bdsp.underground-run-15');
  assert.ok(idxBdspDesc < idxFrlgDesc, 'expected descending run order');
});

test('Opening + Add Console loads /api/devices into datalists', async () => {
  const { sandbox, els } = createHubSandbox(sampleFixtures());
  sandbox.toggleAdd();
  await new Promise((r) => setImmediate(r));
  assert.match(els.serialList.innerHTML, /\/dev\/cu\.usbmodemA/);
  assert.match(els.captureList.innerHTML, /USB Video/);
});

test('Launch posts default mode and surfaces 409 conflict error banner', async () => {
  const routes = {
    ...sampleFixtures(),
    'POST /api/runs': {
      status: 409,
      json: { error: 'console console-a is busy with external run bdsp.underground (pid 80610)' },
    },
  };
  const { sandbox, els, fetchLog } = createHubSandbox(routes);
  await sandbox.loadPrograms();
  await sandbox.refreshAll();
  els.progSelect.value = 'frlg.supplies';
  els.fromSelect.value = 'su-01';
  els.toSelect.value = 'su-01';
  els.modeSelect.value = 'default';
  await sandbox.launch(false);
  const post = fetchLog.find((x) => x.method === 'POST' && x.url === '/api/runs');
  assert.ok(post, 'expected POST /api/runs');
  assert.equal(post.body.mode, 'default');
  assert.match(els.launchErr.textContent, /busy with external run/);
});

test('Series Run History entry links to /series/<id>/ with series tag', async () => {
  const routes = sampleFixtures();
  routes['GET /api/history'].json.entries.unshift({
    run: '2026-11-26-su-01-su-02-42',
    kind: 'series',
    game: 'frlg',
    game_name: 'Pokemon FireRed / LeafGreen',
    program: 'frlg.supplies',
    program_name: 'Supplies',
    group: 'Farming',
    checkpoint: 'su-02',
    from: 'su-01',
    to: 'su-02',
    backend: 'switch',
    mode: 'testing',
    result: 'fail',
    at: '#3 mart',
    reason: 'menu timed out',
    started_ms: 1795800000000,
    ended_ms: 1795800090000,
    recorded: true,
  });
  const { sandbox, els } = createHubSandbox(routes);
  await sandbox.refreshAll();
  assert.equal(els.historyCount.textContent, '3 of 3 runs');
  assert.match(
    els.historyList.innerHTML,
    /http:\/\/Mac-mini\.local:47901\/series\/2026-11-26-su-01-su-02-42\//
  );
  assert.doesNotMatch(
    els.historyList.innerHTML,
    /\/runs\/2026-11-26-su-01-su-02-42\//
  );
  assert.match(els.historyList.innerHTML, /<span class="tag">series<\/span>/);
  assert.match(els.historyList.innerHTML, /su-01 → <b>su-02<\/b>/);
});
