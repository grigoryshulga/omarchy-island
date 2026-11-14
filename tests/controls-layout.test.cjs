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
  quick:initial.quick, order:["network","plugin:good.control","audio","bluetooth","tailscale","monitors","settings"].concat(initial.quick), sizes:{}, labels:{}, sections:{}, hidden:['network'], favorites:initial.favorites
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

const resized=plain(model.resize(initial,'audio',1,3));
assert.deepEqual(resized.sizes.audio,{width:1,height:3});
assert.deepEqual(plain(model.resize(resized,'audio',8,-2)).sizes.audio,{width:4,height:1});
assert.deepEqual(plain(model.resize(resized,'../bad',2,2)),resized);
assert.deepEqual(plain(model.normalize({sizes:{audio:{width:'4',height:Infinity}}})).sizes.audio,{width:2,height:1});
const spans=plain(model.resize(model.resize(initial,'audio',3,2),'bluetooth',1,1));
const placed=plain(model.tiles(spans));
const occupied=new Set();
for(const tile of placed) {
  assert.ok(tile.column+tile.width<=4);
  for(let y=0;y<tile.height;y++) for(let x=0;x<tile.width;x++) {
    const cell=(tile.row+y)*4+tile.column+x;
    assert.ok(!occupied.has(cell),'overlapping tiles');occupied.add(cell);
  }
}
assert.deepEqual(placed.map(p=>p.key),initial.order);
assert.equal(model.move(initial,'order','audio','remote').order.at(-1),'audio');
assert.ok(!model.tiles(model.toggle(initial,'audio')).some(p=>p.key==='audio'));

const labeled=model.label(initial,'audio',' Speakers ','🔊');
assert.equal(model.normalize(labeled).labels.audio.title,'Speakers');
assert.equal(model.normalize(labeled).labels.audio.icon,'🔊');
assert.deepEqual(plain(model.label(initial,'__proto__','bad','bad')),initial);
const grouped=model.addSection(spans,'network','Connections');
const sectionKey=grouped.order.find(model.sectionKey);
assert.equal(grouped.order.indexOf(sectionKey)+1,grouped.order.indexOf('network'));
const spaced=model.section(grouped,sectionKey,'Network',2);
const groupedTiles=plain(model.tiles(spaced));
const header=groupedTiles.find(p=>p.section);
assert.equal(header.row,4); // two-row audio, followed by two blank rows
assert.equal(groupedTiles.find(p=>p.key==='network').row,5);
assert.equal(model.normalize(spaced).sections[sectionKey].title,'Network');
assert.ok(!model.move(spaced,'order',sectionKey,'audio').main.includes(sectionKey));
assert.ok(!model.removeSection(spaced,sectionKey).order.includes(sectionKey));
assert.equal(model.section(spaced,sectionKey,'x',999).sections[sectionKey].gap,4);
assert.equal(model.label(initial,'audio','x'.repeat(100),'').labels.audio.title.length,80);
