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