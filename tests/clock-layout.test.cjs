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
console.log('PASS: clock composition, defaults, validation, movement and missing modules');
