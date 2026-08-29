// Headless harness: loads the embedded <script> from a Web html file under a
// fake DOM + localStorage, then exercises real product behavior (assist recording
// and the actual reset handler) and reports on the assist table state.
const fs = require('fs');
const vm = require('vm');
const path = require('path');

function loadHtml(file) {
  return fs.readFileSync(file, 'utf8');
}

function extractScript(html) {
  const m = html.match(/<script>([\s\S]*?)<\/script>/g);
  if (!m) throw new Error('no script block');
  // last <script> block is the app logic
  const last = m[m.length - 1];
  return last.replace(/^<script>/, '').replace(/<\/script>$/, '');
}

function makeEl(id) {
  const el = {
    _id: id,
    dataset: {},
    style: {},
    classList: { add() {}, remove() {}, contains() { return false; } },
    _text: '',
    get textContent() { return this._text; },
    set textContent(v) { this._text = String(v); },
    value: '',
    hidden: false,
    className: '',
    insertAdjacentHTML() {},
    appendChild() {},
    addEventListener() {},
    closest() { return this; },
    ondblclick: null,
    click() {},
    remove() {},
  };
  return el;
}

function runHarness(file) {
  const html = loadHtml(file);
  const script = extractScript(html);

  const registry = new Map();
  const getEl = (id) => {
    if (!registry.has(id)) registry.set(id, makeEl(id));
    return registry.get(id);
  };

  let docDblclick = null;
  const document = {
    getElementById: getEl,
    createElement: () => makeEl('created'),
    addEventListener: (type, handler) => { if (type === 'dblclick') docDblclick = handler; },
    activeElement: null,
    body: { appendChild() {} },
  };

  const store = new Map();
  const localStorage = {
    getItem: (k) => (store.has(k) ? store.get(k) : null),
    setItem: (k, v) => store.set(k, String(v)),
    removeItem: (k) => store.delete(k),
  };

  const sandbox = {
    document,
    localStorage,
    navigator: {},
    confirm: () => true,
    alert: () => {},
    setTimeout: () => {},
    console,
    JSON,
    Math,
    URL: { createObjectURL: () => 'blob:x', revokeObjectURL() {} },
    Blob: function () {},
    Date,
    parseInt, parseFloat, Number, String, Array, Object,
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(script, sandbox, { filename: file });

  const readGame = () => JSON.parse(localStorage.getItem('setter-stats-game'));

  const recordAssist = (key) => {
    docDblclick({ target: { closest: () => ({ dataset: { assist: key } }) } });
  };
  const clickReset = () => {
    const el = getEl('reset');
    el.ondblclick();
  };

  return { getEl, readGame, recordAssist, clickReset, registry };
}

module.exports = { runHarness };

if (require.main === module) {
  const file = process.argv[2] || path.join(__dirname, 'index.html');
  const h = runHarness(file);
  // populate assists
  h.recordAssist('front-perfect');
  h.recordAssist('front-perfect');
  h.recordAssist('front-decent');
  h.recordAssist('backRow-perfect');
  h.recordAssist('backRow-offTheMark');
  const before = h.readGame();
  console.log('BEFORE reset assists:', JSON.stringify(before.assists));
  console.log('BEFORE reset savedSets:', before.savedSets.length);
  h.clickReset();
  const after = h.readGame();
  console.log('AFTER reset assists:', JSON.stringify(after.assists));
  console.log('AFTER reset savedSets:', after.savedSets.length);
  const frontTotal = h.getEl('assistcount-front').textContent;
  const backRowTotal = h.getEl('assistcount-backRow').textContent;
  console.log('Rendered front row total:', frontTotal, ' backRow row total:', backRowTotal);
}
