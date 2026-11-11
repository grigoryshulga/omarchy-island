const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const model = vm.createContext({});
vm.runInContext(readFileSync(`${__dirname}/../plugin/SpotlightModel.js`, 'utf8'), model);
function item(props = {}) {
  return { width: 100, height: 60, radius: 10, visible: true, enabled: true,
    opacity: 1, z: 0, children: [], mapFromItem: (_, x, y) => ({ x, y }), ...props };
}
const button = item({ clicked() {} });
const card = item({ islandSpotlightSurface: true, children: [button] });
const pick = (x, y) => model.pick(card, null, { x, y });
assert.equal(pick(40, 30), button, 'nested button wins over its card');
button.visible = false;
assert.equal(pick(40, 30), card, 'hidden child is ignored');
button.visible = true; button.enabled = false;
assert.equal(pick(40, 30), card, 'disabled child is ignored');
assert.equal(pick(0, 0), null, 'rounded corners do not catch hover');
card.radius = 0;
assert.equal(pick(0, 0), card, 'zero-radius corners remain square');
assert.equal(pick(101, 20), null);
button.enabled = true;
const overlay = item({ clicked() {}, z: 2 });
card.children = [overlay, button];
assert.equal(pick(40, 30), overlay, 'paint order wins over declaration order');
card.clip = true; card.width = 20;
assert.equal(pick(40, 30), null, 'clipped descendants are ignored');
console.log('PASS: spotlight nested surfaces, clipping, corners and stacking.');
