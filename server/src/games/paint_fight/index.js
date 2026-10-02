const { GameError } = require('../../errors');

function createPaintFight(opts = {}) {
  const durationMs = opts.durationMs ?? 25000;
  const width = opts.width ?? 10;
  const height = opts.height ?? 10;
  return {
    id:'paint_fight', minPlayers:2, maxPlayers:4, implemented:true,
    create(room,now=Date.now()) {
      return {
        players:room.players.map(p=>p.userId),
        names:Object.fromEntries(room.players.map(p=>[p.userId,p.username])),
        scores:Object.fromEntries(room.players.map(p=>[p.userId,0])),
        cells:Object.fromEntries(room.players.map(p=>[p.userId,new Set()])),
        startedAt:now,endsAt:now+durationMs,phase:'playing',width,height,
      };
    },
    onAction(s,uid,{type,payload},now=Date.now()) {
      if(!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if(type!=='paint_fight:paint') throw new GameError('INVALID_ACTION');
      if(s.phase!=='playing'||now>=s.endsAt) throw new GameError('BAD_PHASE');
      const x=Number(payload?.x),y=Number(payload?.y);
      if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||x>=s.width||y<0||y>=s.height) throw new GameError('INVALID_PAYLOAD');
      const key=x+','+y;
      const owned=s.cells[uid];
      if(owned.has(key)) return {changed:false,score:s.scores[uid]};
      owned.add(key);
      s.players.forEach(p=>{if(p!==uid&&s.cells[p].delete(key))s.scores[p]=s.cells[p].size;});
      s.scores[uid]=owned.size;
      return {changed:true,score:s.scores[uid]};
    },
    onTick(s,now){if(s.phase==='playing'&&now>=s.endsAt){s.phase='finished';return true;}return false;},
    getPublicState(s,uid,now=Date.now()) {
      return {gameType:'paint_fight',phase:s.phase,startedAt:s.startedAt,endsAt:s.endsAt,width:s.width,height:s.height,
        players:s.players.map(u=>({userId:u,username:s.names[u],score:s.scores[u]})),
        yourCells:[...s.cells[uid]],yourScore:s.scores[uid]??0};
    },
    isFinished:s=>s.phase==='finished',
    getResult(s){
      const ranking=s.players.map(u=>({userId:u,username:s.names[u],score:s.scores[u]})).sort((a,b)=>b.score-a.score);
      let rank=0;ranking.forEach((r,i)=>{if(i===0||r.score<ranking[i-1].score)rank=i+1;r.rank=rank;});
      return {gameType:'paint_fight',scores:Object.fromEntries(s.players.map(u=>[u,s.scores[u]])),ranking,winners:ranking.filter(r=>r.rank===1).map(r=>r.userId)};
    }
  };
}
module.exports={game:createPaintFight(),createPaintFight};
