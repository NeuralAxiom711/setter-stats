const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const handlers={},deleted=[];
 const cache={addAll:async()=>{},match:async()=> 'CURRENT'};
 const sandbox={self:{addEventListener:(k,v)=>handlers[k]=v},caches:{open:async()=>cache,keys:async()=>['setter-stats-v36','setter-stats-v37','other-app'],delete:async k=>deleted.push(k),match:async()=> 'STALE'},fetch:async()=> 'NETWORK'};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'..','sw.js'),'utf8'),sandbox);
 let pending;
 handlers.fetch({request:{},respondWith:p=>pending=p});
 assert.equal(await pending,'CURRENT','fetch must use only the current version cache');
 assert.equal(typeof handlers.activate,'function');
 handlers.activate({waitUntil:p=>pending=p});await pending;
 assert.deepEqual(deleted,['setter-stats-v36','setter-stats-v37']);
 console.log('PASS service worker uses current cache and removes only obsolete app cache');
})().catch(e=>{console.error(e);process.exit(1)});
