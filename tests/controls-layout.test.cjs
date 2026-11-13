const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(require.resolve('../plugin/controls/Layout.js'), 'utf8'), model);
const plain = x => JSON.parse(JSON.stringify(x));
const initial = plain(model.normalize({}));
assert.equal(initial.main[5], 'settings');
assert.deepEqual(plain(model.normalize({main:['network','network','../bad','plugin:good.control'], hidden:['settings','network']})), {
  main:['network','plugin:good.control','audio','bluetooth','tailscale','monitors','settings'],
  quick:initial.quick, hidden:['network'], favorites:initial.favorites
});
assert.equal(model.move(initial, 'main', 'audio', 'network').main[2], 'audio');
assert.equal(model.move(initial, 'main', 'settings', 'audio').main[0], 'settings');
assert.deepEqual(plain(model.move(initial, 'quick', 'audio', 'dnd')), initial);
assert.deepEqual(plain(model.toggle(model.toggle(initial, 'audio'), 'audio')), initial);
assert.deepEqual(plain(model.toggle(initial, 'settings')), initial);
assert.equal(model.safeKey('plugin:bad/../../x'), false);
assert.equal(model.safeKey('plugin:a; touch bad'), false);
assert.equal(initial.main[0], 'audio');
console.log('Controls layout model passed');

assert.deepEqual(plain(model.favorite(model.favorite(initial, 'audio'), 'audio')).favorites, ['bluetooth','network','dnd','nightLight','audio']);

assert.equal(model.move(initial, "favorites", "audio", "network").favorites[2], "audio");
assert.deepEqual(plain(model.move(initial, "__proto__", "audio", "network")), initial);
