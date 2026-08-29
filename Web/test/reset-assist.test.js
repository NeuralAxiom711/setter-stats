// Regression test for: "Reset everything must reset the Assist Quality by Set
// Location table, not just other stats." It exercises the REAL product reset
// behavior (the #reset button's dblclick handler -> resetGame()) under a fake
// DOM/localStorage, then asserts the assist table is fully cleared.
const path = require('path');
const assert = require('assert');
const { runHarness } = require('./harness');

const file = process.argv[2] || path.join(__dirname, '..', 'index.html');

const locations = ['front', 'back', 'middle', 'backRow'];
const qualities = ['perfect', 'decent', 'offTheMark'];
const akey = (c, q) => c + '-' + q;
const allKeys = [];
locations.forEach((c) => qualities.forEach((q) => allKeys.push(akey(c, q))));

const h = runHarness(file);

// 1) Populate at least Front Set and Back Row Set assist-quality counts.
h.recordAssist(akey('front', 'perfect'));
h.recordAssist(akey('front', 'perfect'));
h.recordAssist(akey('front', 'decent'));
h.recordAssist(akey('front', 'offTheMark'));
h.recordAssist(akey('backRow', 'perfect'));
h.recordAssist(akey('backRow', 'decent'));
const before = h.readGame();
assert.ok(before.assists[akey('front', 'perfect')] === 2, 'front-perfect should be 2 before reset');
assert.ok(before.assists[akey('backRow', 'decent')] === 1, 'backRow-decent should be 1 before reset');

// Save the current set (moves these counts into savedSets and zeroes the live
// counters), so we can also prove reset empties savedSets.
// (confirm is stubbed true inside the harness)
h.getEl('set-plus').ondblclick();
const saved = h.readGame();
assert.ok(saved.savedSets.length === 1, 'a set should be saved before reset');

// 2) Record FRESH current-set assists AFTER saving, so the reset must clear the
//    live Assist Quality by Set Location table (not just the already-zeroed one).
h.recordAssist(akey('front', 'decent'));
h.recordAssist(akey('backRow', 'offTheMark'));
const liveBefore = h.readGame();
assert.ok(liveBefore.assists[akey('front', 'decent')] === 1, 'current front-decent must be 1 pre-reset');
assert.ok(liveBefore.assists[akey('backRow', 'offTheMark')] === 1, 'current backRow-offTheMark must be 1 pre-reset');

// 3) Invoke the ACTUAL reset behavior (real #reset dblclick handler).
h.clickReset();

// 4) Assert all 12 current assist location-quality values are zero.
const after = h.readGame();
let allZero = true;
for (const k of allKeys) {
  if ((after.assists[k] || 0) !== 0) { allZero = false; console.error('FAIL: ' + k + ' = ' + after.assists[k]); }
}
assert.ok(allZero, 'all 12 assist location-quality values must be zero after reset');

// 5) Assert all per-location row totals render zero.
let rowsZero = true;
for (const c of locations) {
  const rendered = h.getEl('assistcount-' + c).textContent;
  if (String(rendered) !== '0') { rowsZero = false; console.error('FAIL row total ' + c + ' = ' + rendered); }
}
assert.ok(rowsZero, 'every per-location assist row total must render 0 after reset');

// 6) savedSets is empty.
assert.ok(after.savedSets.length === 0, 'savedSets must be empty after reset');

// 7) Other behavior preserved: non-assist stats also reset.
assert.ok(after.attacks === 0 && after.serves === 0 && after.setNumber === 1 && after.opponent === '',
  'other stats must also reset');

console.log('PASS: reset clears all 12 assist values, all row totals render 0, and savedSets is empty.');
