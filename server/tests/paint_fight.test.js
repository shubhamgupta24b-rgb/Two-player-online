const test=require('node:test'); const assert=require('node:assert');
const {createPaintFight}=require('../src/games/paint_fight');
test('Paint Fight claims cells and removes overwritten ownership',()=>{
 const g=createPaintFight({durationMs:1000,width:3,height:3});
 const s=g.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},0);
 assert.strictEqual(g.onAction(s,'a',{type:'paint_fight:paint',payload:{x:1,y:1}},100).changed,true);
 assert.strictEqual(s.scores.a,1);
 assert.strictEqual(g.onAction(s,'b',{type:'paint_fight:paint',payload:{x:1,y:1}},200).changed,true);
 assert.strictEqual(s.scores.b,1); assert.strictEqual(s.scores.a,0);
});
test('Paint Fight ends on server time',()=>{
 const g=createPaintFight({durationMs:1000}); const s=g.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},0);
 assert.strictEqual(g.onTick(s,999),false); assert.strictEqual(g.onTick(s,1000),true);
});
test('Paint Fight overwritten cells change the final ranking',()=>{
 const g=createPaintFight({durationMs:1000,width:3,height:3});
 const s=g.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},0);
 const paint=(u,x,y)=>g.onAction(s,u,{type:'paint_fight:paint',payload:{x,y}},100);
 paint('a',0,0);paint('a',1,0);paint('b',0,0);paint('b',1,0);paint('b',2,0);
 g.onTick(s,1000);
 const r=g.getResult(s);
 assert.deepStrictEqual(r.scores,{a:0,b:3});
 assert.deepStrictEqual(r.winners,['b']);
});

const room=(...ids)=>({players:ids.map(u=>({userId:u,username:u.toUpperCase()}))});
const paintAt=(g,s,u,x,y,now=10)=>g.onAction(s,u,{type:'paint_fight:paint',payload:{x,y}},now);
test('Paint Fight initial state uses the default 10x10 board',()=>{
 const g=createPaintFight(); const s=g.create(room('a','b'),0);
 assert.strictEqual(s.width,10); assert.strictEqual(s.height,10); assert.strictEqual(s.endsAt,25000);
 assert.deepStrictEqual(s.scores,{a:0,b:0});
 const pub=g.getPublicState(s,'a');
 assert.deepStrictEqual(pub.yourCells,[]); assert.strictEqual(pub.yourScore,0);
});
test('Paint Fight rejects out-of-bounds or non-integer cells, outsiders and wrong actions',()=>{
 const g=createPaintFight({width:3,height:3}); const s=g.create(room('a','b'),0);
 for(const [x,y] of [[-1,0],[0,-1],[3,0],[0,3],[1.5,1],['a',1],[undefined,1]])
  assert.throws(()=>paintAt(g,s,'a',x,y),e=>e.code==='INVALID_PAYLOAD',`${x},${y}`);
 assert.throws(()=>g.onAction(s,'a',{type:'paint_fight:paint'},10),e=>e.code==='INVALID_PAYLOAD');
 assert.throws(()=>paintAt(g,s,'x',0,0),e=>e.code==='NOT_IN_GAME');
 assert.throws(()=>g.onAction(s,'a',{type:'memory:flip',payload:{id:0}},10),e=>e.code==='INVALID_ACTION');
 assert.strictEqual(s.scores.a,0);
});
test('Paint Fight repainting your own cell changes nothing; corners are valid',()=>{
 const g=createPaintFight({width:3,height:3}); const s=g.create(room('a','b'),0);
 assert.strictEqual(paintAt(g,s,'a',0,0).changed,true);
 assert.deepStrictEqual(paintAt(g,s,'a',0,0),{changed:false,score:1});
 assert.strictEqual(paintAt(g,s,'a',2,2).changed,true);
 assert.deepStrictEqual(g.getPublicState(s,'a').yourCells.sort(),['0,0','2,2']);
 assert.deepStrictEqual(g.getPublicState(s,'b').yourCells,[],'players only see their own cells');
});
test('Paint Fight with three players: stealing takes the cell from whoever owned it',()=>{
 const g=createPaintFight({width:2,height:2}); const s=g.create(room('a','b','c'),0);
 paintAt(g,s,'a',0,0); paintAt(g,s,'b',1,0); paintAt(g,s,'c',0,0); paintAt(g,s,'c',1,0);
 assert.deepStrictEqual(s.scores,{a:0,b:0,c:2});
 const total=Object.values(s.cells).reduce((n,set)=>n+set.size,0);
 assert.strictEqual(total,2,'a cell has exactly one owner');
});
test('Paint Fight rejects painting at or after the end and ties share the win',()=>{
 const g=createPaintFight({durationMs:1000,width:3,height:3}); const s=g.create(room('a','b'),0);
 paintAt(g,s,'a',0,0); paintAt(g,s,'b',1,1);
 assert.throws(()=>paintAt(g,s,'a',2,2,1000),e=>e.code==='BAD_PHASE');
 g.onTick(s,1000);
 assert.strictEqual(g.onTick(s,1500),false);
 assert.deepStrictEqual(g.getResult(s).winners,['a','b']);
});
