const assert = require('node:assert/strict');
const model = require('../plugin/OverviewModel.mjs');
const settings = require('../plugin/SettingsModel.mjs');
const {ordered} = require('../plugin/ModuleCatalog.mjs');
const defs = ordered('overview');
const defaults = model.layout(defs, []);
assert.deepEqual(defaults.map(r => r.id), ['media','battery','agentLimits','t3','notifications','downloads']);
assert(defaults.every(r => r.visible && r.size === 'standard'));
let saved = model.update(defs, [], 'notifications', {visible:false,size:'compact'}, -1);
assert.equal(saved[3].id, 'notifications');
assert.equal(saved[3].visible, false);
assert.equal(saved[3].size, 'compact');
assert(settings.valid('overviewLayout', saved));
assert.deepEqual(model.layout(defs, JSON.parse(JSON.stringify(saved))), saved);
assert.equal(model.layout(defs, [{id:'t3',visible:true,size:'large'}])[0].size, 'standard');
const future = {id:'future',visible:false,size:'large'};
assert.deepEqual(model.update(defs, [future], 'media', {}, -1).at(-1), future);
assert.equal(model.layout(defs, [future]).length, defaults.length);
for(const invalid of [null, {}, [{id:'media',visible:'false',size:'standard'}], [{id:'media',visible:true,size:'huge'}], [defaults[0],defaults[0]], [{id:'../media',visible:true,size:'standard'}]]) {
  assert.equal(model.valid(invalid), false);
  assert.deepEqual(model.layout(defs, invalid), defaults);
}
assert.deepEqual(model.supported({overviewSizes:['large','invented','minimal']}), ['minimal','standard','large']);
console.log('Overview layout checks passed');
