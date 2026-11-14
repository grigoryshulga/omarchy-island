const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const model=vm.createContext({});
vm.runInContext(readFileSync(`${__dirname}/../plugin/CornerGeometry.js`,'utf8'),model);
assert.equal(model.parsePower('{"float":4}',2),4);
assert.equal(model.parsePower('invalid',4),4);
assert.equal(model.parsePower('{}',4),4);
assert.equal(model.parsePower('{"float":null}',4),4);
assert.equal(model.power(NaN),2);
assert.equal(model.power(100),10);
assert.equal(model.power(0),1);
assert.equal(model.effectiveRadius(20,4,400,200),40,'match Hyprland perceived-roundness normalization');
assert.equal(model.effectiveRadius(20,2,400,200),20);
assert.equal(model.effectiveRadius(20,1,400,200),10);
assert.equal(model.effectiveRadius(20,4,60,40),20,'clamp after normalization');
assert.equal(model.effectiveRadius(0,4,400,200),0);
function points(path) {return [...path.matchAll(/(-?[\d.]+),(-?[\d.]+)/g)].map(m=>({x:+m[1],y:+m[2]}));}
for(const power of [1,2,4,10]) {
  const outline=points(model.contour(160,100,20,power));
  for(const {x,y} of outline) {
    assert.ok(x>=0 && x<=160 && y>=0 && y<=100);
    const dx=Math.max(20-x,x-140,0),dy=Math.max(20-y,y-80,0);
    assert.ok(Math.abs((dx/20)**power+(dy/20)**power-1)<0.0001);
  }
  const inner=points(model.contour(160,100,20,power,{top:2,right:3,bottom:4,left:5}));
  assert.ok(inner.every(({x,y})=>x>=5 && x<=157 && y>=2 && y<=96));
}
assert.equal(model.contour(5,5,20,4,{top:3,bottom:3}), '');
assert.ok(points(model.contour(20,10,0,4)).every(({x,y})=>(x===0 || x===20) && (y===0 || y===10)));
console.log('PASS: compositor power, superellipse contours, square corners and asymmetric insets');
