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
