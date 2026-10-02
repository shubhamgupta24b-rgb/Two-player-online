const test=require('node:test'); const assert=require('node:assert');
const {createFruitDuel}=require('../src/games/fruit_duel');
test('Fruit Duel validates lane and awards hits',()=>{
 const g=createFruitDuel({durationMs:5000,spawnMs:1000});
 const s=g.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},0);
 assert.strictEqual(s.fruitLane,1);
 assert.strictEqual(g.onAction(s,'a',{type:'fruit_duel:slash',payload:{fruitId:0,lane:1}},100).hit,true);
 assert.strictEqual(s.score.a,1);
 assert.strictEqual(g.onAction(s,'b',{type:'fruit_duel:slash',payload:{fruitId:0,lane:0}},100).hit,false);
 assert.strictEqual(s.score.b,0);
});
test('Fruit Duel advances fruit and ends',()=>{
 const g=createFruitDuel({durationMs:1000,spawnMs:500}); const s=g.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},0);
 assert.strictEqual(g.onTick(s,500),true); assert.strictEqual(s.fruitId,1);
 assert.strictEqual(g.onTick(s,1000),true); assert.strictEqual(g.isFinished(s),true);
});
test('Fruit Duel allows one slash per player per fruit',()=>{
 const g=createFruitDuel({durationMs:5000,spawnMs:1000});
 const s=g.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]},0);
 const slash={type:'fruit_duel:slash',payload:{fruitId:0,lane:s.fruitLane}};
 assert.strictEqual(g.onAction(s,'a',slash,100).hit,true);
 assert.throws(()=>g.onAction(s,'a',slash,150),e=>e.code==='ALREADY_SLASHED');
 assert.strictEqual(s.score.a,1);
 assert.strictEqual(g.onAction(s,'b',slash,150).hit,true);
 g.onTick(s,1000);
 assert.strictEqual(g.onAction(s,'a',{type:'fruit_duel:slash',payload:{fruitId:1,lane:s.fruitLane}},1100).hit,true);
 assert.strictEqual(s.score.a,2);
});
