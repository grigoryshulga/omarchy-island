const assert = require('node:assert/strict');
const {readFileSync,readdirSync} = require('node:fs');
const {join} = require('node:path');
const tokens = require('../plugin/DesignTokens.js');

// A bad theme must not produce unreadable normal text or selected text.
for (const bg of [[0.05,0.07,0.1,1],[0.96,0.95,0.92,1],[0.48,0.48,0.48,1]]) {
  for (const fg of [[0.1,0.1,0.1,1],[0.9,0.9,0.9,1],[0.2,0.4,0.8,1],[0.5,0.5,0.5,0.2]]) {
    for(const minimum of [3,4.5]) {
      const corrected=tokens.readable(fg,bg,minimum);
      assert.ok(tokens.contrast(corrected,bg)>=minimum-0.00001);
      assert.ok(corrected.every(c=>Number.isFinite(c)&&c>=0&&c<=1));
    }
  }
}
const themeAccent=[0.62,0.72,1,1], dark=[0.04,0.05,0.08,1];
assert.deepEqual(tokens.readable(themeAccent,dark,4.5),themeAccent,'Legible theme colors must not change');
assert.ok(tokens.contrast([0,0,0,1],[1,1,1,1])===21);

// Architectural guard: a new screen cannot silently bring separator chrome back.
for(const file of readdirSync(join(__dirname,'../plugin')).filter(name=>name.endsWith('.qml'))) {
  const source=readFileSync(join(__dirname,'../plugin',file),'utf8');
  assert.ok(!/\bPanelSeparator\s*\{/.test(source),`${file} introduces a decorative separator`);
}
console.log('Design palette and no-divider checks passed');
