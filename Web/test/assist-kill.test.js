// Legacy K entries migrate to assists; quality-only entries count as sets.
const assert=require('node:assert/strict');
const path=require('node:path');
const {runHarness}=require('./harness');
const file=path.join(__dirname,'..','index.html');
for(const loc of ['front','back','middle','backRow']){
 for(const q of ['perfect','decent','offTheMark']){
  const assists={[loc+'-'+q]:2,[loc+'-'+q+'Kill']:3};
  const h=runHarness(file,{assists,savedSets:[{assists,setNumber:1}]});
  assert.equal(h.readGame().totalSets,5);
  assert.equal(h.readGame().assistCount,3);
  assert.equal(h.readGame().savedSets[0].assistCount,3);
  assert.equal(h.readGame().assists[loc+'-'+q+'Kill'],3);
 }
}
console.log('PASS all legacy locations and K categories migrate without discarding buckets');
