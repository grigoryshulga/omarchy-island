const assert=require('node:assert/strict');
const M=require('../plugin/AgentLimitsModel.js'),S=require('../plugin/SettingsModel.mjs');
const now=Date.now(),id=M.key('codex','Weekly');
function cache(percent,extra={}) {return {schemaVersion:1,providers:[{id:'codex',name:'Codex',limits:[{label:'Weekly',percent,...extra}]}]}}
assert.equal(M.parse('invalid'),null);
assert.equal(M.parse('{"schemaVersion":9,"providers":[]}'),null);
assert.deepEqual(M.parse('{"schemaVersion":1,"providers":[null,{}]}').providers,[]);
assert.equal(M.windows(cache(92),now)[0].remaining,8);
for(const bad of [null,'90',NaN,Infinity,-1,101]) assert.equal(M.windows(cache(bad),now)[0].remaining,null);
assert.equal(M.windows(cache(99,{exhausted:true}),now)[0].remaining,0);
assert.equal(M.windows(cache(0,{rolledWindows:1}),now)[0].remaining,null);
assert.equal(M.windows(cache(99,{resetsAt:new Date(now-1).toISOString()}),now)[0].pendingReset,true);
assert.deepEqual(M.attention(M.windows(cache(79),now),[],20),[]);
assert.deepEqual(M.attention(M.windows(cache(80),now),[],20),[id]);
assert.deepEqual(M.attention(M.windows(cache(76),now),[id],20),[id]);
assert.deepEqual(M.attention(M.windows(cache(74),now),[id],20),[]);
assert.deepEqual(M.attention(M.windows(cache(0,{rolledWindows:1}),now),[id],20),[id]);
assert.deepEqual(M.summary(M.windows(cache(92),now),[id],[id],'combined').map(r=>r.id),[id]);
assert.equal(M.summary(M.windows(cache(92),now),[],[id],'pinned').length,0);
assert.equal(M.summary([], [id], [id], 'combined').length,0);
assert.equal(M.tightest(M.windows(cache(null),now)),null);
assert.deepEqual(M.toggle([id],id),[]);
assert.equal(S.valid('agentLimitsPins',[id]),true);
for(const pins of [[id,id],['codex'],[null],['["../x","window"]'],['["codex",""]']]) assert.equal(S.valid('agentLimitsPins',pins),false);
for(const value of [-1,101,1.5,'20',NaN]) assert.equal(S.valid('agentLimitsWarning',value),false);
assert.equal(S.get({},'agentLimitsEnabled'),false);
assert.equal(S.get({},'agentLimitsIndicator'),'off');
assert.equal(M.metrics({days:[{tokens:100,cost:1,priced:true,unpricedTokens:20}]},'today').unpriced,true);
assert.equal(M.metrics({},'week').available,false);
assert.equal(M.metrics({total:{tokens:100},days:[{tokens:0,priced:true}]},'today').available,true);
assert.equal(M.metrics({days:[{tokens:100,priced:true},{tokens:200,priced:true}]},'today').tokens,200);
console.log('PASS: Agent Limits quota semantics, reset uncertainty, hysteresis, pins and mixed pricing.');

const resetStrings={t:key=>({'limits.resetIn':'Reset in %1','limits.daysHoursMinutes':'%1 d %2 h %3 min','limits.hoursMinutes':'%1 h %2 min','limits.minutes':'%1 min','limits.awaitingReset':'Awaiting confirmed reset'})[key]};
const countdown=(offset,extra={})=>M.resetCountdown({resetsAt:now+offset,...extra},now,resetStrings,String);
assert.equal(countdown((26*60+5)*60000),'Reset in 1 d 2 h 5 min');
assert.equal(countdown(65*60000),'Reset in 1 h 5 min');
assert.equal(countdown(59999),'Reset in 1 min');
assert.equal(countdown(60001),'Reset in 2 min');
assert.equal(countdown(0),'Awaiting confirmed reset');
assert.equal(countdown(60000,{pendingReset:true}),'Awaiting confirmed reset');
assert.equal(countdown(60000,{resetsAt:0}),'');
assert.equal(countdown(60000,{resetsAt:NaN}),'');
assert.equal(M.resetCountdown({resetsAt:now+60000},now,resetStrings,v=>'['+v+']'),'Reset in [1] min');

assert.equal(M.displayName({providerId:"codex",name:"ChatGPT / Codex",label:"Weekly (7-day)"}), "Codex Weekly");
assert.equal(M.displayName({providerId:"codex",name:"Codex",label:"Weekly"}), "Codex Weekly");
assert.equal(M.displayName({providerId:"claude",name:"Claude",label:"Weekly (7-day)"}), "Claude · Weekly (7-day)");

// Presentation semantics: do not claim freshness from absent or future timestamps.
const freshnessStrings={t:key=>({
  'limits.cached':'Cached','limits.checkedUnknown':'Unknown',
  'limits.checkedNow':'Just now','limits.checkedMinutes':'%1 min ago',
  'limits.window.weekly':'Weekly window','limits.window.session':'Session window'
})[key]};
assert.equal(M.freshness({checkedAt:now-180000},now,freshnessStrings,String),'3 min ago');
assert.equal(M.freshness({checkedAt:now},now,freshnessStrings,String),'Just now');
for(const checkedAt of [undefined,0,NaN,now+1])
  assert.equal(M.freshness({checkedAt},now,freshnessStrings,String),'Unknown');
assert.equal(M.freshness({checkedAt:now,stale:true},now,freshnessStrings,String),'Cached');
assert.equal(M.windows({providers:[{...cache(20).providers[0],status:'error',limitsCheckedAt:now}]},now)[0].stale,true);
assert.equal(M.windowLabel({label:'Weekly (7-day)'},freshnessStrings),'Weekly window');
assert.equal(M.windowLabel({label:'Custom quota'},freshnessStrings),'Custom quota');
assert.equal(M.windowLabel({label:'constructor'},freshnessStrings),'constructor');
assert.equal(M.balances({balance:[{currency:'USD',total:0},{currency:'CNY',total:12.5},{currency:'USD',total:null}]},n=>n.toFixed(2)),'USD 0.00 · CNY 12.50');
const pinIds=[id,M.key('claude','Session'),M.key('disabled','Weekly')];
assert.deepEqual(M.movePin(pinIds,id,1),[pinIds[1],id,pinIds[2]]);
for(const [target,step] of [[id,-1],[pinIds[2],1],['missing',1],[id,2]])
  assert.deepEqual(M.movePin(pinIds,target,step),pinIds);
assert.equal(pinIds[0],id,'moving pins mutated preferences');
// A reordered snapshot must preserve surviving delegates, while removed windows disappear.
const entries=[{id:'a'},{id:'b'}],first=entries[0];
const list={get count(){return entries.length},get:i=>entries[i],remove:i=>entries.splice(i,1),append:item=>entries.push(item)};
M.syncIdentities(list,['b','a','c'],'id');
assert.deepEqual(entries.map(x=>x.id),['a','b','c']);
assert.equal(entries[0],first);
M.syncIdentities(list,['c','a'],'id');
assert.deepEqual(entries.map(x=>x.id),['a','c']);
console.log('PASS: Limits freshness, balances, pin ordering and stable identities.');
