const {chromium}=require('playwright');const assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({headless:true,executablePath:'/snap/bin/chromium'});
for(const width of [320,390,430]){const p=await b.newPage({viewport:{width,height:844},isMobile:true,hasTouch:true});await p.goto('http://127.0.0.1:8876/');
assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
const panel=await p.locator('#setsPanel').boundingBox(),stats=await p.locator('#stats').boundingBox();assert.ok(panel.y+panel.height<=stats.y);
const cards=await p.locator('#stats .card').evaluateAll(es=>es.map(e=>e.getBoundingClientRect().y));assert.ok(cards.every(y=>y===cards[0]));
if(width===390)await p.screenshot({path:'/home/jeremy/.cache/setter-dashboard-top.png'});
for(const selector of ['[data-stat="attacks"][data-change="1"]','[data-stat="errors"][data-change="1"]','[data-service-error]','#matchTools']){await p.locator(selector).scrollIntoViewIfNeeded();const r=await p.locator(selector).boundingBox(),nav=await p.locator('#bottomNav').boundingBox();if(r.y+r.height>nav.y)await p.evaluate(()=>scrollBy(0,100));const rr=await p.locator(selector).boundingBox();assert.ok(rr.y+rr.height<=nav.y,selector+' reachable above nav');}
if(width===390)await p.screenshot({path:'/home/jeremy/.cache/setter-dashboard-lower.png'});
await p.locator('#viewSaved').dblclick();await p.locator('#navTrack').click();assert.equal(await p.locator('#savedSetsView').isVisible(),true);await p.locator('#navTrack').dblclick();assert.equal(await p.locator('#entryView').isVisible(),true);assert.equal(await p.locator('#navTrack').getAttribute('aria-current'),'page');await p.close();}
console.log('PASS 320/390/430 widths: layout order, same-row stats, no overflow, controls reachable above bottom navigation, Track double-tap');await b.close();})().catch(e=>{console.error(e);process.exit(1)});
