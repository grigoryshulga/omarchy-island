const assert = require('node:assert/strict');
const visual = require('../plugin/MusicVisual.js');
let state = visual.empty();
assert.deepEqual(visual.sample(state, 0, 0, 0).strengths, [0, 0, 0, 0]);
let attack = visual.sample(state, 0.1, 0.6, 0.8);
assert.equal(attack.times[0], 0.1);
assert.ok(attack.strengths[0] > 0);
assert.deepEqual(state, visual.empty(), 'sampling must not mutate shared state');
state = visual.sample(attack, 0.2, 1, 1);
assert.deepEqual(state.times, attack.times, 'nearby peaks must coalesce');
state = visual.sample(state, 0.5, 1, 1);
assert.deepEqual(state.times, attack.times, 'sustained audio must not invent attacks');
for (let time = 1; time < 8; time++) {
  state = visual.sample(state, time, 0, 0);
  state = visual.sample(state, time + 0.1, 0.5, 0.5);
}
assert.equal(state.times.length, 4);
assert.equal(state.strengths.length, 4);
assert.deepEqual(state.times, [7.1, 6.1, 5.1, 4.1]);
const quiet = visual.sample(state, 8, 0, 0);
assert.deepEqual(quiet.times, state.times, 'tails must retain their birth time through silence');
assert.ok(quiet.strengths.every(value => value >= 0 && value <= 1));
assert.deepEqual(visual.empty().strengths, [0, 0, 0, 0], 'a new track starts without old tails');
console.log('PASS: bounded music attack history, cooldown, sustained audio and silent tails.');
