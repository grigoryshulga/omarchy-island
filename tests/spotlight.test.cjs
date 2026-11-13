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
const trail = vm.createContext({});
vm.runInContext(readFileSync(`${__dirname}/../plugin/SpotlightTrail.js`, 'utf8'), trail);
let samples = trail.advance([], {x: 10, y: 20}, {x: 40, y: 20}, 100);
assert.equal(samples.length, 2, 'a movement keeps the previous position');
assert.equal(samples[0].x, 10);
samples = trail.advance(samples, {x: 40, y: 20}, {x: 40, y: 60}, 164);
assert.equal(samples.length, 3, 'turns keep the path rather than one straight tail');
assert.equal(samples[1].y, 20);
assert.equal(samples[2].y, 60);
assert.equal(trail.advance(samples, {x: 40, y: 60}, {x: 40, y: 60}, 196).length, 3,
  'standing still does not replenish the wake');
assert.equal(trail.weight(0), 1);
assert.equal(trail.weight(360), 0.5);
assert.equal(trail.weight(720), 0);
assert.ok(trail.weight(1) > 0.999, 'fade starts gently');
assert.ok(trail.weight(719) < 0.001, 'fade ends gently');
assert.equal(trail.advance(samples, {x: 40, y: 60}, {x: 40, y: 60}, 1000).length, 0,
  'all old light expires after stopping');
let bounded = [], previous = {x: 0, y: 0};
for (let i = 0; i < 100; i++) {
  const point = {x: i * 5, y: i % 2 * 5};
  bounded = trail.advance(bounded, previous, point, i * 32);
  previous = point;
  assert.ok(bounded.length <= 24, 'path memory stays bounded');
}
assert.ok(bounded.length >= 22, 'continuous motion retains a denser path throughout the fade');
console.log('PASS: visible path retention, curved motion, smooth fading and bounded history.');
const box = {x: 40, y: 30, width: 220, height: 130};
let hit = model.collision({x: 180, y: 95}, {x: 254, y: 95}, box, 18, 25);
assert.ok(hit, 'approaching the right rim starts a split');
assert.equal(hit.x, 258); assert.equal(hit.y, 95);
assert.equal(hit.nx, 1); assert.equal(hit.ny, 0);
assert.equal(model.collision({x: 254, y: 95}, {x: 180, y: 95}, box, 18, 25), null,
  'moving away from the edge does not collide');
assert.equal(model.collision({x: 252, y: 95}, {x: 254, y: 100}, box, 18, 25), null,
  'sliding along the rim does not repeatedly burst');
assert.equal(model.collision({x: 180, y: 95}, {x: 265, y: 95}, box, 18, 25), null,
  'outside points do not start a burst');
hit = model.collision({x: 200, y: 95}, {x: 250, y: 40}, box, 18, 25);
assert.ok(hit && hit.nx > 0 && hit.ny < 0, 'rounded corners split along the curved rim');
hit = model.collision({x: 140, y: 95}, {x: 140, y: 32}, box, 0, 25);
assert.ok(hit && hit.ny === -1 && hit.nx === 0, 'square corners retain correct normals');
assert.equal(model.collision({x: 0, y: 0}, {x: 1, y: 1}, {...box, width: 0}, 0, 25), null);
console.log('PASS: rim collisions, outward approach, curved/square corners and no repeated bursts.');

function surface(x, y, props = {}) {
  return item({islandSpotlightSurface: true, mapToItem: () => ({x, y}), ...props});
}
const current = surface(0, 0);
const adjacent = surface(110, 0, {radius: 0});
const hidden = surface(105, 0, {visible: false});
const disabled = surface(106, 0, {enabled: false});
const wrapper = surface(103, 0, {islandSpotlightSurface: false});
const distant = surface(300, 0);
const scene = surface(0, 0, {islandSpotlightSurface: false, width: 500,
  children: [current, adjacent, hidden, disabled, wrapper, distant]});
let rims = model.neighbors(scene, null, {x: 95, y: 30}, 60);
assert.equal(rims.length, 1, 'only the nearby visible enabled surface receives light');
assert.equal(rims[0].rect.x, 110);
assert.equal(rims[0].radius, 0, 'square theme corners are preserved');
assert.equal(model.neighbors(scene, null, {x: 105, y: 30}, 60).length, 2,
  'a cursor in the gap lights both adjacent rims');
scene.children.push(surface(0, 0, {width: 250, height: 100}));
assert.equal(model.neighbors(scene, null, {x: 95, y: 30}, 60).length, 1,
  'enclosing containers do not add another rim');
scene.clip = true; scene.width = 150;
assert.equal(model.neighbors(scene, null, {x: 95, y: 30}, 60).length, 0,
  'partially clipped neighbors do not paint across a viewport boundary');
scene.clip = false;
scene.children = Array.from({length: 8}, (_, i) => surface(110 + i * 5, 0));
rims = model.neighbors(scene, null, {x: 95, y: 30}, 60);
assert.equal(rims.length, 4, 'neighbor shader work is bounded');
assert.equal(rims[0].rect.x, 110, 'nearest rims take priority');
assert.equal(rims[3].rect.x, 125);
console.log('PASS: adjacent rims, invisible wrappers, clipping, square corners and bounded proximity selection.');

const decorative = item({
  mapFromItem() { throw new Error('button decoration must not be picked'); },
  mapToItem() { throw new Error('button decoration must not be scanned for neighbors'); }
});
const leafButton = surface(110, 0, {clicked() {}, islandSpotlightLeaf: true, children: [decorative]});
assert.equal(model.pick(leafButton, null, {x: 50, y: 30}), leafButton);
scene.children = [leafButton];
assert.equal(model.neighbors(scene, null, {x: 95, y: 30}, 60).length, 1);
leafButton.islandSpotlightLeaf = false;
leafButton.children = [button];
assert.equal(model.pick(leafButton, null, {x: 50, y: 30}), button,
  'composite controls may opt back into descendant picking');
console.log('PASS: leaf controls skip decorative subtrees while composite controls retain nested picking.');
