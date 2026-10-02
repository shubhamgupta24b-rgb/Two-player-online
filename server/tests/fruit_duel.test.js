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

const room=(...ids)=>({players:ids.map(u=>({userId:u,username:u.toUpperCase()}))});
const slashAt=(g,s,u,fruitId,lane,now)=>g.onAction(s,u,{type:'fruit_duel:slash',payload:{fruitId,lane}},now);
test('Fruit Duel initial state and lane sequence',()=>{
 const g=createFruitDuel({durationMs:5000,spawnMs:500}); const s=g.create(room('a','b'),100);
 assert.strictEqual(s.fruitId,0); assert.strictEqual(s.fruitExpiresAt,600); assert.strictEqual(s.endsAt,5100);
 assert.deepStrictEqual(s.score,{a:0,b:0});
 const lanes=[]; for(let i=0;i<6;i++){lanes.push(s.fruitLane);g.onTick(s,s.fruitExpiresAt);}
 assert.deepStrictEqual(lanes,[1,2,0,1,2,0]);
});
test('Fruit Duel rejects invalid lanes, stale fruit ids, outsiders and wrong actions',()=>{
 const g=createFruitDuel({durationMs:5000,spawnMs:1000}); const s=g.create(room('a','b'),0);
 for(const lane of [-1,3,1.5,'x',undefined]) assert.throws(()=>slashAt(g,s,'a',0,lane,10),e=>e.code==='INVALID_PAYLOAD',String(lane));
 assert.throws(()=>slashAt(g,s,'a',1,1,10),e=>e.code==='INVALID_PAYLOAD','future fruit');
 g.onTick(s,1000);
 assert.throws(()=>slashAt(g,s,'a',0,1,1010),e=>e.code==='INVALID_PAYLOAD','old fruit');
 assert.throws(()=>slashAt(g,s,'x',1,2,1010),e=>e.code==='NOT_IN_GAME');
 assert.throws(()=>g.onAction(s,'a',{type:'paint_fight:paint',payload:{}},1010),e=>e.code==='INVALID_ACTION');
 assert.deepStrictEqual(s.misses,{a:0,b:0},'rejected slashes are not misses');
});
test('Fruit Duel counts a slash after the fruit expired (before the tick) as a miss',()=>{
 const g=createFruitDuel({durationMs:5000,spawnMs:1000}); const s=g.create(room('a','b'),0);
 const r=slashAt(g,s,'a',0,s.fruitLane,1001);
 assert.strictEqual(r.hit,false); assert.strictEqual(s.misses.a,1); assert.strictEqual(s.score.a,0);
});
test('Fruit Duel stops at the end and ranks by score then hits',()=>{
 const g=createFruitDuel({durationMs:2000,spawnMs:1000}); const s=g.create(room('a','b','c'),0);
 slashAt(g,s,'a',0,1,10); slashAt(g,s,'b',0,0,10);
 g.onTick(s,1000); slashAt(g,s,'b',1,s.fruitLane,1010);
 assert.throws(()=>slashAt(g,s,'c',1,s.fruitLane,2000),e=>e.code==='BAD_PHASE');
 assert.strictEqual(g.onTick(s,2000),true); assert.strictEqual(g.isFinished(s),true);
 assert.strictEqual(g.onTick(s,3000),false);
 const r=g.getResult(s);
 assert.deepStrictEqual(r.winners,['a','b']);
 assert.deepStrictEqual(r.scores,{a:1,b:1,c:0});
 assert.strictEqual(r.ranking[2].userId,'c'); assert.strictEqual(r.ranking[2].rank,3);
 const pub=g.getPublicState(s,'b');
 assert.strictEqual(pub.yourHits,1); assert.strictEqual(pub.players.find(p=>p.userId==='b').misses,1);
});
