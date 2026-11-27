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

function createHubSandbox(mockRoutes) {
  const { html, script } = loadWebAssets();
  const ids = [
    'cfgPath',
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
    'historySearch',
    'historyGame',
    'historyResult',
    'historySort',
    'historyPager',
    'historyPageInfo',
    'historyPrev',
    'historyNext',
  ];
  const els = Object.fromEntries(ids.map((id) => [id, makeFakeElement(id)]));
  els.addSection.classList.toggle('hidden', true);
  els.modeSelect.value = 'default';
  els.addBackend.value = 'switch';
  els.historyResult.value = 'all';
  els.historyGame.value = 'all';
  els.historySort.value = 'newest';

  const optInputs = [];
  const fetchLog = [];

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
    window: { location: { hostname: 'Mac-mini.local' } },
    fetch,
    setInterval: () => 0,
    encodeURIComponent,
    parseInt,
    console,
  };
  vm.createContext(sandbox);
  vm.runInContext(script, sandbox);
  return { html, sandbox, els, optInputs, fetchLog };
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
      entries: [
        {
          time: '2026-11-26T15:14:19',
          game: 'bdsp',
          run: '2026-11-26-bdsp.underground-run-15',
          checkpoint: 'bdsp.underground',
          mode: 'run',
          result: 'pass',
          at: '',
          reason: '',
        },
      ],
    },
  },
});

test('Hub HTML offers default and verification modes', () => {
  const { html } = loadWebAssets();
  assert.match(html, /<option value="default" selected>default<\/option>/);
  assert.match(html, /<option value="verification">verification<\/option>/);
  assert.match(html, /<link rel="stylesheet" href="\/style\.css">/);
  assert.match(html, /<script src="\/app\.js"><\/script>/);
});

test('Initial load renders Console A external run + Watch link and Console B ready', async () => {
  const { sandbox, els } = createHubSandbox(sampleFixtures());
  await sandbox.refreshAll();
  assert.equal(els.consoleCount.textContent, '2 configured');
  assert.match(els.consolesGrid.innerHTML, /Console A/);
  assert.match(els.consolesGrid.innerHTML, /bdsp\.underground/);
  assert.match(els.consolesGrid.innerHTML, /http:\/\/Mac-mini\.local:57023\//);
  assert.match(els.consolesGrid.innerHTML, /Console B/);
  assert.equal(els.runCount.textContent, '1 run(s)');
  assert.doesNotMatch(els.runsList.innerHTML, /stopRun\('ext-80610'\)/);
  assert.match(els.historyList.innerHTML, /2026-11-26-bdsp\.underground-run-15/);
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
