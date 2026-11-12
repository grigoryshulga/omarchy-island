const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
function load(name) {const context=vm.createContext({});vm.runInContext(fs.readFileSync(require.resolve('../plugin/'+name),'utf8').replace(/^\.pragma.*$/gm,''),context);return context}
const security=load('Security.js'),model=load('CalendarEvents.js');
assert.equal(security.calendarUrl('webcal://EXAMPLE.com:443/feed.ics?secret=ok'),'https://example.com/feed.ics?secret=ok');
for(const url of ['http://example.com/a','https://example.com:444/a','https://example.com/a#secret','https://user:password@example.com/a','file:///etc/passwd','https://127.0.0.1/a','https://example.com/%250a']) assert.equal(security.calendarUrl(url),'');
const event={title:'<b>literal</b>',location:'Home',sourceName:'Private',start:1,end:2,startDay:'2026-03-28',endDay:'2026-03-30',allDay:true};
assert.deepEqual(Array.from(model.days([event])),['2026-03-28','2026-03-29','2026-03-30']);
assert.equal(model.onDay([event],'2026-03-31').length,0);
assert.equal(model.onDay([event],'2026-03-29').length,1);
assert.equal(model.parse(JSON.stringify({year:2026,sources:[],events:[event]})).events[0].title,'<b>literal</b>');
assert.equal(model.parse('garbage'),null);
assert.equal(model.parse(JSON.stringify({year:2026,sources:[],events:[{}]})),null);
console.log('PASS: ICS URL policy, day markers, agenda selection and report validation.');
