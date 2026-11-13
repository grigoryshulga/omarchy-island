const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const model = require('../plugin/T3Model.js');
const settings = require('../plugin/SettingsModel.mjs');
const security = vm.createContext({});
vm.runInContext(readFileSync(require.resolve('../plugin/Security.js'), 'utf8').replace(/^\.pragma.*$/gm, ''), security);
assert.equal(settings.get({}, 't3Enabled'), false);
assert.equal(settings.get({}, 't3Responses'), true);
assert.equal(settings.valid('t3Enabled', 'true'), false);
assert.equal(security.t3ThreadUrl('env-1', 'thread-1'), 't3code://threads/env-1/thread-1');
for (const id of ['', '../secret', 'a/b', 'a?x=y', 'a#b', 'a%2fb', '$(touch bad)', '<b>', 'a'.repeat(129)]) {
  assert.equal(security.t3ThreadUrl('env', id), '');
  assert.equal(security.t3ThreadUrl(id, 'thread'), '');
}
assert.deepEqual(model.toggle(['a'], 'b', false), ['b']);
assert.deepEqual(model.toggle(['a'], 'b', true), ['a', 'b']);
assert.deepEqual(model.toggle(['a', 'b'], 'a', true), ['b']);
const question = {required:true, multiSelect:false, allowCustomAnswer:true};
assert.equal(model.valid(question, []), false);
assert.deepEqual(model.answer(question, ['a'], ' custom '), ['custom']);
assert.deepEqual(model.answer({...question, multiSelect:true}, ['a'], 'custom'), ['a', 'custom']);
assert.deepEqual(model.answer({...question, multiSelect:true}, ['a'], 'a'), ['a']);
assert.deepEqual(model.answer({...question, allowCustomAnswer:false}, ['a'], 'custom'), ['a']);
assert.equal(model.valid({...question, required:false}, []), true);
assert.equal(model.valid(question, ['a', 'b']), false);
assert.equal(model.optionDescription({label:'Вариант A',description:' Вариант A '}),'');
assert.equal(model.optionDescription({label:'Local',description:'On this machine'}),'On this machine');
assert.equal(model.duration({startedAt:100, finishedAt:165}, 200, String), '1:05');
assert.equal(model.duration({startedAt:100}, 225, String), '2:05');
assert.equal(model.duration({}, 200, String), '');
console.log('PASS: T3 settings, links, answer selection and durations');

const running={id:'a',status:'running',requestId:''};
assert.deepEqual(model.transitions(null,[running]),[]);
assert.deepEqual(model.transitions([running],[{...running,title:'renamed'}]),[]);
assert.deepEqual(model.transitions([{...running,status:'queued'}],[running]),[]);
assert.equal(model.transitions([], [running]).length,1);
assert.equal(model.transitions([running],[{...running,status:'completed'}]).length,1);
assert.equal(model.transitions([running],[{...running,requestId:'question'}]).length,1);
assert.deepEqual(model.transitions([], [{...running,status:'completed'}]),[]);
assert.deepEqual(model.transitions([running], []),[]);

assert.equal(model.statusRank({status:'running',requestId:'q'}),0);
assert.equal(model.statusRank({status:'completed'}),1);
assert.equal(model.statusRank({status:'failed'}),1);
assert.equal(model.statusRank({status:'running'}),2);
assert.equal(model.statusRank({status:'starting'}),2);

for(const [row,role] of [[{status:'running'},'info'],[{status:'completed'},'success'],[{status:'failed'},'danger'],[{status:'running',requestId:'q'},'warning'],[{status:'cancelled'},'secondaryText']]) assert.equal(model.statusRole(row),role);
const icons=require('../plugin/ProjectIconModel.js');
assert.equal(icons.color('red',true,'fallback'),'#ff6467');
assert.equal(icons.color('red',false,'fallback'),'#e7000b');
assert.equal(icons.color('unknown',true,'fallback'),'fallback');
assert.equal(icons.color('constructor',true,'fallback'),'fallback');


// Overview hides terminal successes and bounds working rows without hiding requests/failures.
const overviewRows = [
  {id:'done',status:'completed'}, {id:'a',status:'running'},
  {id:'b',status:'queued'}, {id:'c',status:'running'},
  {id:'question',status:'running',requestId:'request'}, {id:'failed',status:'failed'}
];
assert.deepEqual(model.overviewRows(overviewRows), ['a','b','question','failed']);
assert.deepEqual(model.counts(overviewRows), {attention:1,working:3,finished:1,failed:1,other:0});
assert.deepEqual(model.overviewRows([{id:'done',status:'completed'}]), []);

assert.deepEqual(model.counts([{status:'cancelled'}, {status:'idle'}, {status:'failed',requestId:'q'}]), {attention:1,working:0,finished:0,failed:0,other:2});
