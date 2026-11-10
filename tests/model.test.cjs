const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
function load(name, deps={}) {
 const s=readFileSync(path.join(__dirname,'../plugin',name+'.js'),'utf8').replace(/^\.(?:pragma|import).*$/gm,'');
 const context=vm.createContext({...deps});vm.runInContext(s,context);return context;
}
const Calendar=load('CalendarModel');
const Security=load('Security'), Detect=load('Detect',{Security}), Markup=load('Markup',{Security}), Store=load('Store',{Security,Detect,Markup}), Model=load('Model');
for (const text of ['Код подтверждения: 482913','Your code: 482913','482913','Ваш код AB12-CD34','OTP 482-913']) assert.ok(Detect.codes(text).length,text);
assert.equal(Detect.codes('2026-11-09').length,0);
assert.equal(Detect.codes('Build 427 passed').length,0);
assert.equal(Detect.codes('Login: AB12-CD34')[0],'AB12-CD34');
assert.equal(Security.safeHttpUrl('javascript:alert(1)'), '');
assert.equal(Security.safeHttpUrl('https://example.com/path'), 'https://example.com/path');
for(const text of ['Your code: 482913','Код AB12-CD34','482913']) {
 const row=Store.normalise({key:'test',summary:text,body:'secret'});
 const persisted=JSON.stringify(Store.closedEntry(row,'closed',Date.now()/1000));
 assert.ok(!persisted.includes('482913')&&!persisted.includes('AB12-CD34'),persisted);
 assert.ok(persisted.includes('redacted'));
}
assert.ok(Model.musicPlayer({identity:'Spotifast'},['spotifast']));
assert.ok(!Model.musicPlayer({identity:'Chromium'},['spotifast','spotify']));
assert.equal(Model.time(125),'2:05');
const rows=Model.collect([{key:'one',ts:2},{key:'two',ts:3}],[{key:'one',ts:1}]);
assert.equal(rows.length,2);assert.equal(rows[0].key,'two');
assert.equal(Model.plain('<img src="https://example.com/pixel">hello'),'hello');
const groups=Model.previewGroups([
 {key:'1',app:'A'}, {key:'2',app:'A'}, {key:'3',app:'B'}, {key:'4',app:'A'}
],3);
assert.equal(groups.length,2);assert.equal(groups[0].rows.length,2);assert.equal(groups[0].total,3);
assert.equal(Model.previewGroups(Array.from({length:10},(_,i)=>({key:String(i),app:'A'})),3)[0].rows.length,3);
assert.equal(Model.hasMedia(null,0),false);
assert.equal(Model.hasMedia({playbackState:0,trackTitle:'Old track'},0),false);
assert.equal(Model.hasMedia({playbackState:2,trackTitle:'Paused track'},0),true);
assert.equal(Model.hasMedia({playbackState:1,trackTitle:'Playing track'},0),true);
assert.equal(Model.hasMedia({playbackState:1,trackTitle:'   ',trackArtist:''},0),false);
const leap=Calendar.monthCells(2024,1,1,'2024-02-29');
assert.equal(leap.length,42);assert.equal(new Set(leap.map(c=>c.key)).size,42);
assert.equal(leap.filter(c=>c.inMonth).length,29);assert.equal(leap.find(c=>c.today).day,29);
assert.equal(leap[0].key,'2024-01-29');
assert.equal(Calendar.monthCells(2025,1,1,'').filter(c=>c.inMonth).length,28);
assert.equal(Calendar.stepMonth(2026,11,1).key,'2027-01-01');
assert.equal(Calendar.stepMonth(2026,0,-1).key,'2025-12-01');
assert.equal(Calendar.stepDay({year:2024,month:1,day:28},1).key,'2024-02-29');
for(const tz of ['America/Santiago','America/Havana','Pacific/Apia']) {
 process.env.TZ=tz;
 const grid=Calendar.monthCells(2026,8,0,'');
 assert.equal(new Set(grid.map(c=>c.key)).size,42,tz);
 assert.equal(Calendar.stepMonth(2026,8,1).key,'2026-10-01');
}
console.log('PASS: code detection, redaction, URL policy, music filtering, notification ordering.');
