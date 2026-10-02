const test=require('node:test');
const assert=require('node:assert');
const {createCrushIt}=require('../src/games/crush_it');
test('Crush It counts taps and finishes on server time',()=>{
 const game=createCrushIt({durationMs:1000});
 const s=game.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},100);
 assert.strictEqual(game.onAction(s,'a',{type:'crush_it:tap',payload:{}},200).taps,1);
 assert.strictEqual(game.onAction(s,'a',{type:'crush_it:tap',payload:{}},300).taps,2);
 assert.strictEqual(game.onTick(s,1099),false);
 assert.strictEqual(game.onTick(s,1100),true);
 assert.strictEqual(s.phase,'finished');
 assert.deepStrictEqual(game.getResult(s).winners,['a']);
});

const room=(...ids)=>({players:ids.map(u=>({userId:u,username:u.toUpperCase()}))});
const tap=(g,s,u,now,payload={})=>g.onAction(s,u,{type:'crush_it:tap',payload},now);
test('Crush It initial state: zero taps, playing, ends after the duration',()=>{
 const g=createCrushIt({durationMs:2000}); const s=g.create(room('a','b','c'),500);
 assert.deepStrictEqual(s.taps,{a:0,b:0,c:0});
 assert.strictEqual(s.phase,'playing'); assert.strictEqual(s.endsAt,2500);
 assert.strictEqual(g.isFinished(s),false);
 const pub=g.getPublicState(s,'b');
 assert.strictEqual(pub.gameType,'crush_it'); assert.strictEqual(pub.yourTaps,0); assert.strictEqual(pub.players.length,3);
});
test('Crush It rejects outsiders, wrong action types, payload data and late taps',()=>{
 const g=createCrushIt({durationMs:1000}); const s=g.create(room('a','b'),0);
 assert.throws(()=>tap(g,s,'x',10),e=>e.code==='NOT_IN_GAME');
 assert.throws(()=>g.onAction(s,'a',{type:'memory:flip',payload:{}},10),e=>e.code==='INVALID_ACTION');
 assert.throws(()=>tap(g,s,'a',10,{taps:99}),e=>e.code==='INVALID_PAYLOAD');
 assert.strictEqual(tap(g,s,'a',10,undefined).taps,1,'missing payload is fine');
 assert.throws(()=>tap(g,s,'a',1000),e=>e.code==='BAD_PHASE','tap exactly at endsAt');
 g.onTick(s,1000);
 assert.throws(()=>tap(g,s,'a',1001),e=>e.code==='BAD_PHASE');
 assert.strictEqual(s.taps.a,1);
});
test('Crush It public state shows each player their own taps',()=>{
 const g=createCrushIt(); const s=g.create(room('a','b'),0);
 tap(g,s,'a',1); tap(g,s,'a',2); tap(g,s,'b',3);
 assert.strictEqual(g.getPublicState(s,'a').yourTaps,2);
 assert.strictEqual(g.getPublicState(s,'b').yourTaps,1);
 assert.strictEqual(g.getPublicState(s,'zzz').yourTaps,0);
});
test('Crush It ties share first place; ticks after finishing change nothing',()=>{
 const g=createCrushIt({durationMs:100}); const s=g.create(room('a','b','c'),0);
 tap(g,s,'a',1); tap(g,s,'b',2); tap(g,s,'a',3); tap(g,s,'b',4); tap(g,s,'c',5);
 assert.strictEqual(g.onTick(s,100),true); assert.strictEqual(g.onTick(s,200),false);
 const r=g.getResult(s);
 assert.deepStrictEqual(r.winners,['a','b']);
 assert.deepStrictEqual(r.ranking.map(x=>x.rank),[1,1,3]);
 assert.deepStrictEqual(r.scores,{a:2,b:2,c:1});
});