const assert=require('node:assert/strict');
const m=require('../plugin/Dictation.js');
for(const value of ['',null,'error','Recording','idle']) assert.equal(m.state(value),'idle');
assert.equal(m.state('recording\n'),'recording');
assert.equal(m.state('transcribing'),'transcribing');
for(const raw of ['{}','null','[]','broken','{"peak":"1"}','{"status":"connected"}','{"peak":1e999}']) assert.equal(m.frame(raw),null);
assert.equal(m.frame('{"peak":0.4,"rms":0.2,"vad":1}'),0.4);
assert.equal(m.frame('{"peak":2}'),1);
assert.equal(m.frame('{"peak":-2}'),0);
assert.deepEqual(m.superwhisper('{"mode":"recording","peak":0.6}'),{mode:"recording",peak:0.6,inputMeter:false});
assert.deepEqual(m.superwhisper('{"mode":"recording","peak":null}'),{mode:"recording",peak:0,inputMeter:false});
assert.deepEqual(m.superwhisper('{"mode":"warming","peak":"0.5"}'),{mode:"idle",peak:0,inputMeter:false});
assert.equal(m.superwhisper('{"peak":0.7}'),null);
assert.equal(m.source("superwhisper","recording","transcribing"),"superwhisper");
assert.equal(m.source("voxtype","recording","recording"),"voxtype");
assert.equal(m.source("voxtype","idle","recording"),"superwhisper");
assert.equal(m.source("superwhisper","idle","idle"),"");
let history=m.empty();
for(let i=0;i<60;i++) history=m.push(history,i/100);
assert.equal(history.length,48);assert.equal(history[0],0.12);assert.equal(history[47],0.59);
assert.deepEqual(m.superwhisper('{"mode":"recording","peak":0,"inputMeter":true}'),
  {mode:"recording",peak:0,inputMeter:true});
const appInput={name:"chosen-microphone"};
const linkedInput=m.superwhisperInput([
  {target:{name:"voice-chat"},source:{name:"default-microphone"}},
  {target:{name:"superwhisper-capture"},source:appInput}
]);
assert.equal(linkedInput,appInput);
assert.equal(m.superwhisperInput([{target:{name:"voice-chat"},source:appInput}]),null);
assert.equal(m.meterPeak(0,0.08),0.08);
assert.equal(m.meterPeak(0.6,0.8),0.6);
assert.equal(m.meterPeak(0,-1),0);
const rowStep=3/28;
const quiet=m.waveAt(0.625,0,0,0,1,rowStep);
for(const u of [0.10,0.4,0.8,0.95]) for(const phase of [0,1,4]) {
  const still=m.waveAt(u,0,phase,0,1,rowStep);
  assert.equal(still.top,-rowStep/2);
  assert.equal(still.bottom,rowStep/2);
}
const voice=m.waveAt(0.625,m.voiceStrength(m.meterPeak(0,0.04)),0,0,1,rowStep);
assert.ok(voice.bottom>quiet.bottom+0.06);
assert.ok(m.waveInk(voice.bottom,voice)>0.8);
assert.ok(m.waveInk(quiet.bottom,quiet)<0.55);
assert.ok(m.waveInk(quiet.bottom+rowStep,quiet)>0.08); // A soft shoulder in silence.
const entered=m.waveAt(0.625,1,0,0,1,rowStep);
assert.ok(m.waveInk(0,entered)>0.26); // Filled between the two contours.
const travelling=m.waveAt(0.625,1,Math.PI/2,0,1,rowStep);
assert.ok(Math.abs(travelling.top-entered.top)>0.10);
assert.ok(Math.abs(travelling.bottom-entered.bottom)>0.10);
const halfway=m.waveAt(0.625,1,0,0,0.5,rowStep);
assert.equal(halfway.bottom,entered.bottom/2);
assert.equal(m.waveAt(0.625,1,0,0,0,rowStep).opacity,0);
assert.equal(m.waveAt(0,1,0,0,1,rowStep).opacity,0);
console.log('PASS: dictation states, routed peak fallback, soft stationary silence, bright flowing contours and center-line reveal.');
