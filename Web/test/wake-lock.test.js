// Regression test: the live tracker requests a screen wake lock and reacquires
// it when the app becomes visible again.
const path = require('path');
const assert = require('assert');
const fs = require('fs');

const file = process.argv[2] || path.join(__dirname, '..', 'index.html');
const html = fs.readFileSync(file, 'utf8');
assert.ok(html.includes('navigator.wakeLock.request'), 'app requests the Screen Wake Lock API');
assert.ok(html.includes("document.addEventListener('visibilitychange'"), 'app handles returning from the background');
assert.ok(html.includes("wakeLock.addEventListener('release'"), 'app tracks wake-lock release');
console.log('PASS: screen wake-lock request, reacquisition, and release handling are present.');
