const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const catalog = require('../plugin/ModuleCatalog.mjs');

const ids = catalog.definitions.map(entry => entry.id);
assert.equal(new Set(ids).size, ids.length, 'Module IDs must be unique');
const pages = catalog.pages();
assert.equal(new Set(pages.map(entry => entry.pageIndex)).size, pages.length);
assert.equal(pages[0].id, 'overview');
assert.equal(pages[0].enabledSetting, undefined, 'Overview must keep Controls reachable');
for (const entry of catalog.definitions) {
  for (const slot of ['state', 'page', 'overview', 'indicator', 'tab']) {
    if (entry[slot]) assert.ok(fs.existsSync(path.join(__dirname, '../plugin', entry[slot])), `${entry.id}: missing ${slot}`);
  }
}
// An added page and its settings participate without another host branch.
catalog.definitions.push({id:'fixture',page:'fixture.qml',pageIndex:4,enabledSetting:'fixtureEnabled',
  defaults:{fixtureEnabled:false,fixtureMode:'small'},choices:{fixtureMode:['small','large']},
  groups:[{id:'fixture',rows:[{key:'fixtureEnabled'},{key:'fixtureMode',type:'choice'}]}]});
const settings = require('../plugin/SettingsModel.mjs');
assert.deepEqual(settings.pages({}), [1,2,3]);
assert.deepEqual(settings.pages({fixtureEnabled:true}), [1,2,3,4]);
assert.equal(settings.openingPage({fixtureEnabled:true,openingPage:'last'},4),4);
assert.equal(settings.openingPage({openingPage:'last'},4),1);
assert.equal(settings.nextPage(settings.pages({fixtureEnabled:true}),3,1),4);
assert.equal(settings.valid('fixtureMode','large'),true);
assert.equal(settings.valid('fixtureMode','unknown'),false);
assert.ok(settings.sections.find(section => section.id==='modules').groups.some(group => group.id==='fixture'));
console.log('PASS: module composition, unique registrations, required Controls, contributed page/settings and navigation.');
