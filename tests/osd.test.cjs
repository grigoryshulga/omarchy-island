const assert=require('node:assert/strict');
const {parse}=require('../plugin/Osd.js');
const read=data=>parse(JSON.stringify(data));
for(const data of [null,[],true,{}, {icon:{x:1}}, {message:[]},{icon:'volume',value:'oops'}, {icon:'brightness',value:10,max:0}, {icon:'keyboard',value:true}, {icon:'keyboard',value:10,duration:'NaN'}]) assert.equal(read(data),null);
for(const icon of ['microphone','microphone-muted','touchpad','touchscreen','reboot','shutdown','logout','volume-high','media-source']) {
 const data=read({icon,message:'<img src="https://example.invalid">',duration:5000});
 assert.equal(data.message,'<img src="https://example.invalid">');assert.equal(data.hasProgress,false);assert.equal(data.duration,5000);
}
assert.equal(read({icon:'keyboard',value:128,max:255}).value,128/255);
assert.equal(read({icon:'brightness',value:200}).value,1);
assert.equal(read({icon:'volume',value:-5}).value,0);
assert.equal(read({icon:'keyboard',value:50,duration:0}).duration,0);
assert.equal(read({icon:'keyboard',value:'0',duration:''}).duration,1200);
assert.equal(read({icon:'󰇚',value:30,duration:8000}).duration,8000);
assert.equal(read({icon:'keyboard',value:1,max:2,progressText:'On'}).progressText,'On');
assert.equal(read({message:'x'.repeat(4000)}).message.length,2048);
assert.equal(parse('x'.repeat(8193)),null);
console.log('PASS: all OSD messages/progress, native timing, bounds and malformed payloads.');
