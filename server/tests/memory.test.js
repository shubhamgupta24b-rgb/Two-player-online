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