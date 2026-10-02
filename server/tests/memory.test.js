const test=require('node:test');
const assert=require('node:assert');
const {createMemory}=require('../src/games/memory');
test('memory matching and turn rotation',()=>{
  const game=createMemory(); const room={players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]}; const s=game.create(room);
  const pair=s.cards.findIndex(c=>c.value===s.cards[0].value&&c.id!==0);
  assert.deepStrictEqual(game.onAction(s,'a',{type:'memory:flip',payload:{id:0}}),{flipped:0});
  const match=game.onAction(s,'a',{type:'memory:flip',payload:{id:pair}});
  assert.strictEqual(match.match,true); assert.strictEqual(s.scores.a,1); assert.strictEqual(s.turn,'a');
  const x=s.cards.findIndex(c=>!c.matched), y=s.cards.findIndex(c=>!c.matched&&c.value!==s.cards[x].value);
  game.onAction(s,'a',{type:'memory:flip',payload:{id:x}},1000);
  const miss=game.onAction(s,'a',{type:'memory:flip',payload:{id:y}},1000);
  assert.strictEqual(miss.match,false); assert.strictEqual(s.phase,'mismatch');
  assert.strictEqual(game.onTick(s,1999),false); assert.strictEqual(game.onTick(s,2000),true);
  assert.strictEqual(s.turn,'b'); assert.strictEqual(s.phase,'turn');
});
test('memory hides unmatched cards',()=>{
  const game=createMemory(); const s=game.create({players:[{userId:'a',username:'A'},{userId:'b',username:'B'}]});
  assert.ok(game.getPublicState(s,'b').cards.every(c=>c.value===null));
  game.onAction(s,'a',{type:'memory:flip',payload:{id:0}});
  assert.notStrictEqual(game.getPublicState(s,'b').cards[0].value,null);
});
const room=(...ids)=>({players:ids.map(u=>({userId:u,username:u.toUpperCase()}))});
const flip=(g,s,u,id,now=0)=>g.onAction(s,u,{type:'memory:flip',payload:{id}},now);
test('memory deals 12 pairs, first player starts, all cards hidden',()=>{
  const g=createMemory(); const s=g.create(room('a','b'));
  assert.strictEqual(s.cards.length,24);
  const counts={}; for(const c of s.cards) counts[c.value]=(counts[c.value]||0)+1;
  assert.strictEqual(Object.keys(counts).length,12); assert.ok(Object.values(counts).every(n=>n===2));
  assert.deepStrictEqual(s.cards.map(c=>c.id),[...Array(24).keys()]);
  assert.strictEqual(s.turn,'a'); assert.strictEqual(s.phase,'turn'); assert.deepStrictEqual(s.scores,{a:0,b:0});
});
test('memory rejects bad ids, wrong turn, outsiders and repeated flips',()=>{
  const g=createMemory(); const s=g.create(room('a','b'));
  for(const id of [-1,24,1.5,'0',undefined]) assert.throws(()=>flip(g,s,'a',id),e=>e.code==='INVALID_PAYLOAD',String(id));
  assert.throws(()=>flip(g,s,'b',0),e=>e.code==='BAD_PHASE','not your turn');
  assert.throws(()=>flip(g,s,'x',0),e=>e.code==='NOT_IN_GAME');
  assert.throws(()=>g.onAction(s,'a',{type:'crush_it:tap',payload:{}}),e=>e.code==='INVALID_ACTION');
  flip(g,s,'a',0);
  assert.throws(()=>flip(g,s,'a',0),e=>e.code==='INVALID_ACTION','same card twice');
  const pair=s.cards.findIndex(c=>c.id!==0&&c.value===s.cards[0].value);
  flip(g,s,'a',pair);
  assert.throws(()=>flip(g,s,'a',0),e=>e.code==='INVALID_ACTION','already matched');
});
test('memory locks the board during a mismatch and shows both picks to everyone',()=>{
  const g=createMemory(); const s=g.create(room('a','b'));
  const x=0, y=s.cards.findIndex(c=>c.value!==s.cards[0].value);
  flip(g,s,'a',x,100); flip(g,s,'a',y,100);
  assert.strictEqual(s.phase,'mismatch');
  assert.throws(()=>flip(g,s,'a',2,200),e=>e.code==='BAD_PHASE');
  assert.throws(()=>flip(g,s,'b',2,200),e=>e.code==='BAD_PHASE');
  const pub=g.getPublicState(s,'b');
  assert.strictEqual(pub.mismatchEndsAt,1100);
  assert.ok(pub.cards[x].value&&pub.cards[y].value);
  assert.strictEqual(pub.cards.filter(c=>c.value!==null).length,2);
  assert.strictEqual(g.onTick(s,1100),true);
  assert.strictEqual(g.getPublicState(s,'b').cards.filter(c=>c.value!==null).length,0);
  assert.strictEqual(g.getPublicState(s,'b').mismatchEndsAt,null);
});
test('memory turn order wraps around with three players',()=>{
  const g=createMemory(); const s=g.create(room('a','b','c'));
  const miss=(u,now)=>{const i=s.cards.findIndex(c=>!c.matched);const j=s.cards.findIndex(c=>!c.matched&&c.value!==s.cards[i].value);flip(g,s,u,i,now);flip(g,s,u,j,now);g.onTick(s,now+1000);};
  miss('a',0); assert.strictEqual(s.turn,'b');
  miss('b',2000); assert.strictEqual(s.turn,'c');
  miss('c',4000); assert.strictEqual(s.turn,'a');
});
test('memory ends when every pair is found; winners and ties',()=>{
  const g=createMemory(); const s=g.create(room('a','b'));
  const matchNext=u=>{const i=s.cards.findIndex(c=>!c.matched);const j=s.cards.findIndex(c=>!c.matched&&c.id!==i&&c.value===s.cards[i].value);flip(g,s,u,i);return flip(g,s,u,j);};
  for(let k=0;k<11;k++) assert.strictEqual(matchNext('a').match,true);
  assert.strictEqual(g.isFinished(s),false);
  matchNext('a');
  assert.strictEqual(g.isFinished(s),true); assert.strictEqual(s.phase,'finished');
  assert.throws(()=>flip(g,s,'a',0),e=>e.code==='BAD_PHASE');
  const r=g.getResult(s);
  assert.deepStrictEqual(r.winners,['a']); assert.deepStrictEqual(r.scores,{a:12,b:0});
  const s2=g.create(room('a','b'));
  assert.deepStrictEqual(g.getResult(s2).winners,['a','b'],'0-0 is a shared win');
});