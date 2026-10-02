const crypto = require('crypto');
const { GameError } = require('../../errors');
const SYMBOLS = ['🍎','🍌','🍇','🍉','🍓','🥝','🍒','🥭','🍑','🍍','🥥','🍋'];
const shuffle = a => { const r=[...a]; for(let i=r.length-1;i>0;i--){const j=crypto.randomInt(i+1);[r[i],r[j]]=[r[j],r[i]];} return r; };
function createMemory() {
  return {
    id:'memory', minPlayers:2, maxPlayers:4, implemented:true,
    create(room) {
      const values=shuffle([...SYMBOLS,...SYMBOLS]);
      return {players:room.players.map(p=>p.userId),names:Object.fromEntries(room.players.map(p=>[p.userId,p.username])),
        cards:values.map((value,id)=>({id,value,matched:false})),scores:Object.fromEntries(room.players.map(p=>[p.userId,0])),
        turn:room.players[0].userId,picks:[],phase:'turn',mismatchUntil:null};
    },
    onAction(s,uid,{type,payload},now=Date.now()) {
      if(!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if(type!=='memory:flip') throw new GameError('INVALID_ACTION');
      if(s.phase!=='turn'||s.turn!==uid) throw new GameError('BAD_PHASE');
      const id=payload&&payload.id;
      if(!Number.isInteger(id)||id<0||id>=s.cards.length) throw new GameError('INVALID_PAYLOAD');
      const card=s.cards[id];
      if(card.matched||s.picks.includes(id)) throw new GameError('INVALID_ACTION');
      s.picks.push(id);
      if(s.picks.length===1) return {flipped:id};
      const [a,b]=s.picks.map(i=>s.cards[i]);
      if(a.value===b.value){
        a.matched=b.matched=true; s.scores[uid]++; s.picks=[];
        if(s.cards.every(c=>c.matched)) s.phase='finished';
        return {match:true,ids:[a.id,b.id],score:s.scores[uid]};
      }
      s.phase='mismatch'; s.mismatchUntil=now+1000;
      return {match:false,ids:[a.id,b.id]};
    },
    onTick(s,now) {
      if(s.phase!=='mismatch'||now<s.mismatchUntil) return false;
      s.picks=[]; const i=s.players.indexOf(s.turn); s.turn=s.players[(i+1)%s.players.length];
      s.phase='turn'; s.mismatchUntil=null; return true;
    },
    getPublicState(s,uid) {
      const visible=new Set(s.picks);
      return {gameType:'memory',phase:s.phase,turn:s.turn,scores:s.scores,
        players:s.players.map(u=>({userId:u,username:s.names[u]})),
        cards:s.cards.map(c=>({id:c.id,matched:c.matched,value:c.matched||visible.has(c.id)?c.value:null})),
        selected:s.picks,mismatchEndsAt:s.phase==='mismatch'?s.mismatchUntil:null,you:{userId:uid}};
    },
    isFinished:s=>s.phase==='finished',
    getResult(s) {
      const ranking=s.players.map(u=>({userId:u,username:s.names[u],score:s.scores[u]})).sort((a,b)=>b.score-a.score);
      let rank=0; ranking.forEach((r,i)=>{if(i===0||r.score<ranking[i-1].score)rank=i+1;r.rank=rank;});
      return {gameType:'memory',scores:s.scores,ranking,winners:ranking.filter(r=>r.rank===1).map(r=>r.userId)};
    },
  };
}
module.exports={game:createMemory(),createMemory};