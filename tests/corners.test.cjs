const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const model=vm.createContext({});
vm.runInContext(readFileSync(`${__dirname}/../plugin/CornerGeometry.js`,'utf8'),model);
assert.equal(model.parsePower('{"float":4}',2),4);
assert.equal(model.parsePower('invalid',4),4);
assert.equal(model.parsePower('{}',4),4);
assert.equal(model.parsePower('{"float":null}',4),4);
assert.equal(model.parsePower('{"float":100}',2),10);
assert.equal(model.parsePower('{"float":0}',2),1);
assert.equal(model.effectiveRadius(20,4,400,200),40,'match Hyprland perceived-roundness normalization');
assert.equal(model.effectiveRadius(20,2,400,200),20);
assert.equal(model.effectiveRadius(20,1,400,200),10);
assert.equal(model.effectiveRadius(20,4,60,40),20,'clamp after normalization');
assert.equal(model.effectiveRadius(0,4,400,200),0);
for(const width of [0,1,3,20]) assert.equal(model.parseBorderWidth(JSON.stringify({int:width}),2),width);
for(const invalid of ['invalid','{}','{"int":null}','{"int":-1}','{"int":1.5}','{"int":"3"}'])
  assert.equal(model.parseBorderWidth(invalid,3),3,'failed reads preserve the last known width');
function points(path) {return [...path.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map(m=>({x:+m[1],y:+m[2]}));}
function outline(path, left, top, right, bottom) {
  assert.match(path, /^M.*Z$/, 'a drawable contour must be closed');
  const vertices = points(path);
  assert.ok(vertices.length >= 4, 'a contour must not be empty or degenerate');
  assert.equal(Math.min(...vertices.map(p => p.x)), left);
  assert.equal(Math.max(...vertices.map(p => p.x)), right);
  assert.equal(Math.min(...vertices.map(p => p.y)), top);
  assert.equal(Math.max(...vertices.map(p => p.y)), bottom);
  const area = Math.abs(vertices.reduce((sum, p, i) => {
    const next = vertices[(i + 1) % vertices.length];
    return sum + p.x * next.y - next.x * p.y;
  }, 0)) / 2;
  assert.ok(area > (right - left) * (bottom - top) / 2, 'contour must enclose the card');
  return vertices;
}
for(const power of [1,2,4,10]) {
  const outer=outline(model.contour(160,100,20,power),0,0,160,100);
  for(const {x,y} of outer) {
    const dx=Math.max(20-x,x-140,0),dy=Math.max(20-y,y-80,0);
    assert.ok(Math.abs((dx/20)**power+(dy/20)**power-1)<0.0001);
  }
  outline(model.contour(160,100,20,power,{top:2,right:3,bottom:4,left:5}),5,2,157,96);
}
assert.equal(model.contour(5,5,20,4,{top:3,bottom:3}), '');
assert.ok(outline(model.contour(20,10,0,4),0,0,20,10).every(({x,y})=>(x===0 || x===20) && (y===0 || y===10)));
console.log('PASS: compositor power, superellipse contours, square corners and asymmetric insets');
