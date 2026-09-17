const assert=require('node:assert/strict');const fs=require('node:fs');const html=fs.readFileSync(require('node:path').join(__dirname,'..','index.html'),'utf8');
assert.match(html,/id="bottomNav"/);
assert.match(html,/id="navTrack"/);
assert.match(html,/id="setsPanel"/);
assert.ok(html.indexOf('id="setsPanel"')<html.indexOf('id="stats"'));
assert.match(html,/id="matchTools"/);
console.log('PASS dashboard structure and primary panel order');
