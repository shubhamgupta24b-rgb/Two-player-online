const { GameError } = require('../../errors');

function createCrushIt(opts = {}) {
  const durationMs = opts.durationMs ?? 10000;
  return {
    id:'crush_it', minPlayers:2, maxPlayers:4, implemented:true,
    create(room, now=Date.now()) {
      return {
        players:room.players.map(p=>p.userId),
        names:Object.fromEntries(room.players.map(p=>[p.userId,p.username])),
        taps:Object.fromEntries(room.players.map(p=>[p.userId,0])),
        startedAt:now, endsAt:now+durationMs, phase:'playing',
      };
    },
    onAction(s,uid,{type,payload},now=Date.now()) {
      if(!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if(type!=='crush_it:tap') throw new GameError('INVALID_ACTION');
      if(s.phase!=='playing'||now>=s.endsAt) throw new GameError('BAD_PHASE');
      if(payload && Object.keys(payload).length>0) throw new GameError('INVALID_PAYLOAD');
      s.taps[uid]++;
      return {taps:s.taps[uid]};
    },
    onTick(s,now) {
      if(s.phase==='playing'&&now>=s.endsAt){s.phase='finished';return true;}
      return false;
    },
    getPublicState(s,uid) {
      return {
        gameType:'crush_it',phase:s.phase,startedAt:s.startedAt,endsAt:s.endsAt,
        players:s.players.map(u=>({userId:u,username:s.names[u],taps:s.taps[u]})),
        yourTaps:s.taps[uid]??0,
      };
    },
    isFinished:s=>s.phase==='finished',
    getResult(s) {
      const ranking=s.players.map(u=>({userId:u,username:s.names[u],score:s.taps[u]}))
        .sort((a,b)=>b.score-a.score);
      let rank=0;
      ranking.forEach((r,i)=>{if(i===0||r.score<ranking[i-1].score)rank=i+1;r.rank=rank;});
      return {gameType:'crush_it',scores:Object.fromEntries(s.players.map(u=>[u,s.taps[u]])),
        ranking,winners:ranking.filter(r=>r.rank===1).map(r=>r.userId)};
    },
  };
}
module.exports={game:createCrushIt(),createCrushIt};