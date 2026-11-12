const assert = require('node:assert/strict');
const g = require('../plugin/PanelGeometry.js');
for (const edge of ['top','bottom','left','right']) {
  const vertical = g.vertical(edge);
  assert.deepEqual(g.available(edge,1000,800,30,10),vertical ? {width:950,height:780} : {width:980,height:750});
  for (const anchor of [0,25,500,975,1000]) {
    const p = g.origin(edge,1000,800,30,10,400,250,anchor,anchor);
    assert(p.x>=10 && p.x+400<=990);
    assert(p.y>=10 && p.y+250<=790);
    if (edge==='top') assert.equal(p.y,40);
    if (edge==='bottom') assert.equal(p.y+250,760);
    if (edge==='left') assert.equal(p.x,40);
    if (edge==='right') assert.equal(p.x+400,960);
    if (!vertical) assert.equal(p.x+200,Math.max(210,Math.min(anchor,790)));
    else assert.equal(p.y+125,Math.max(135,Math.min(anchor,665)));
  }
  // Fitting on small/portrait screens must reserve the panel's own axis only.
  const size=g.available(edge,320,480,48,8);
  const p=g.origin(edge,320,480,48,8,size.width,size.height,0,0);
  assert(p.x>=8 && p.x+size.width<=312);
  assert(p.y>=8 && p.y+size.height<=472);
}
console.log('PASS: popup placement at all panel edges and clock positions, including small screens.');
