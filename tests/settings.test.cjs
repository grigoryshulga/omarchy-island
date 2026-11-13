const assert = require('node:assert/strict');
const settings = require('../plugin/SettingsModel.mjs');
const osd = require('../plugin/Osd.js');

assert.deepEqual(settings.pages({}), [0, 1, 2, 3]);
assert.deepEqual(settings.pages({overviewEnabled:false, calendarEnabled:false, weatherEnabled:false}), [0]);
assert.deepEqual(settings.pages({}, false), [0, 1, 2]);
assert.equal(settings.nextPage([0, 2], 0, -1), 2);
assert.equal(settings.nextPage([0, 2], 2, 1), 0);
assert.equal(settings.nextPage([0], 0, 1), 0);
assert.equal(settings.openingPage({openingPage:'last'}, 2), 2);
assert.equal(settings.openingPage({openingPage:'last', calendarEnabled:false}, 2), 0);
assert.equal(settings.openingPage({overviewEnabled:false}, 1), 0);
assert.equal(settings.get({hoverDelay:-1}, 'hoverDelay'), 140);
assert.equal(settings.get({hoverDelay:1000}, 'hoverDelay'), 1000);
for (const invalid of [-1, 1001, 1.5, NaN, Infinity, '140']) assert.equal(settings.valid('hoverDelay', invalid), false);
for (const invalid of ['false', 0, null, undefined]) assert.equal(settings.valid('animationsEnabled', invalid), false);
assert.equal(settings.valid('controlsEnabled', false), false);
assert.equal(settings.valid('__proto__', true), false);
assert.equal(settings.valid('notificationStyle', 'invalid'), false);
assert.equal(settings.valid('notificationStyle', 'bar'), true);
assert.equal(settings.valid('notificationStyle', 'card'), true);
assert.equal(settings.valid('musicVisualizationStyle', 'future'), false);
assert.equal(settings.osdAllowed({osdVolume:false}, 'volume'), false);
assert.equal(settings.osdAllowed({osdVolume:false}, 'download'), true);
assert.equal(settings.osdAllowed({osdModes:false}, osd.parse(JSON.stringify({icon:'󰂛', message:'DND'})).kind), false);
// Every supported setting remains reachable, apart from the reserved style key.
assert.deepEqual(settings.sections.map(section => section.id), ['general', 'panel', 'alerts', 'modules']);
const rows = settings.sections.flatMap(section => section.groups.flatMap(group => group.rows));
assert.equal(new Set(rows.map(row => row.key)).size, rows.length);
assert.deepEqual(rows.filter(row => !row.fixed).map(row => row.key).sort(),
  Object.keys(settings.defaults).filter(key => !['musicVisualizationStyle', 'agentLimitsPins'].includes(key)).sort());
assert.deepEqual(rows.filter(row => row.dependsOn).map(row => [row.key, row.dependsOn]),
  [['hoverDelay', 'hoverPreview'], ['t3Responses', 't3Enabled']]);
for (const lang of ['en', 'ru']) {
  const strings = require(`../plugin/i18n/${lang}.json`);
  for (const section of settings.sections) {
    assert.ok(strings[`settings.tab.${section.id}`]);
    for (const group of section.groups) {
      assert.ok(strings[`settings.group.${group.id}`]);
      if (group.description) assert.ok(strings[`settings.description.${group.id}`]);
      for (const row of group.rows) assert.ok(strings[`settings.${row.key}`]);
    }
  }
}
console.log('PASS: Island settings validation, disabled pages, opening fallback and OSD filtering.');
