const assert = require('node:assert/strict');
const layout = require('../plugin/ClockLayout.mjs');
const catalog = require('../plugin/ModuleCatalog.mjs');
const settings = require('../plugin/SettingsModel.mjs');
const entries = layout.catalog(catalog.ordered('indicator'));
const defaults = layout.layout(entries);
assert.deepEqual(defaults.filter(r => r.side === 'left').map(r => r.id),
  ['module:battery', 'module:t3', 'module:herdr', 'module:agentLimits', 'recording', 'remote']);
assert.equal(layout.valid(defaults), true);
assert.equal(entries.find(e => e.id === "module:weather").pageIndex, 3);
assert.ok(!defaults.some(r => r.id === "module:weather"));
assert.equal(settings.valid('clockLayout', null), true);
assert.deepEqual(layout.layout(entries, []), []);
for (const invalid of [{}, false, [null], [{id:'x',kind:'indicator',side:'top'}],
  [{id:'x',kind:'script',side:'left'}], defaults.concat(defaults), Array(33).fill(defaults[0])]) {
  assert.equal(settings.valid('clockLayout', invalid), false);
}
let rows = layout.add(defaults, 'separator', 'left');
rows = layout.add(rows, 'separator', 'left');
assert.equal(rows.at(-1).id, 'separator:2');
assert.equal(layout.add(rows, 'dnd', 'left').length, rows.length);
rows = layout.move(rows, 'dnd', 'left', 'recording');
assert.equal(rows.find(r => r.id === 'dnd').side, 'left');
assert.equal(rows[rows.findIndex(r => r.id === 'recording')-1].id, 'dnd');
rows = layout.step(rows, 'dnd', 1);
assert.equal(rows[rows.findIndex(r => r.id === 'recording')+1].id, 'dnd');
assert.ok(!layout.layout(entries, null, {indicatorDnd:false}).some(r => r.id === 'dnd'));
assert.ok(layout.layout(entries, defaults, {indicatorDnd:false}).some(r => r.id === 'dnd'));
const missing = [{id:'module:uninstalled',side:'right',kind:'indicator'}];
assert.deepEqual(layout.layout(entries, missing), missing);
assert.deepEqual(layout.layout([], rows), rows);
assert.deepEqual(layout.layout(entries, null), defaults);
for (const lang of ['en', 'ru']) {
  const strings = require(`../plugin/i18n/${lang}.json`);
  for (const entry of entries) assert.ok(entry.title || strings[entry.titleKey], entry.id);
}
const now = require('../plugin/NowActivity.mjs');
assert.ok(entries.some(r => r.id === 'now') && !defaults.some(r => r.id === 'now'));
assert.equal(layout.add(defaults, 'now', 'right').at(-1).id, 'now');
assert.equal(now.current(null), null);
const download = {active:true, downloadPath:'a', ts:2};
const other = {...download, downloadPath:'b'};
const older = {...download, ts:1, downloadPath:'z'};
const player = {trackTitle:'Playing'};
const service = {playing:true, player, downloads:[other, download], t3:{connected:true, rows:[{id:'a',requestId:'q'}]}};
assert.equal(now.current(service).row.id, 'a');
service.t3.connected = false;
assert.equal(now.current(service).row, download);
service.downloads.reverse();
assert.equal(now.current(service).row, download);
service.downloads.push(older);
assert.equal(now.current(service).row, older);
service.t3.connected = true;
service.t3.rows.push({id:'b',requestId:'q2'});
service.modules = {timers:{now:1000, records:{
  timer:{status:'running', startedAt:0, duration:60000},
  stopwatch:{status:'running', startedAt:0}
}}};
const activities = now.activities(service);
assert.deepEqual(activities.map(activity=>activity.kind), ['t3','t3','timers','timers','downloads','downloads','downloads']);
assert.deepEqual(now.target(activities[1]), {sessionId:'b',requestId:'q2'});
assert.equal(activities[4].row, older, 'Oldest download should stay at the top of the download group');
assert.equal(new Set(activities.map(activity=>activity.id)).size, activities.length);
service.t3.connected = false;
delete service.modules;
service.downloads = [{...download, active:false}];
assert.equal(now.current(service), null);
service.player = {trackTitle:"Next track"};
assert.equal(now.current(service), null);
service.playing = false;
assert.equal(now.current(service), null);
console.log('PASS: clock composition, defaults, validation, movement and missing modules');
