const { GameError } = require('../../errors');

const laneFor = (fruitId) => (fruitId * 7 + 1) % 3;

function createFruitDuel(opts = {}) {
  const durationMs = opts.durationMs ?? 20000;
  const spawnMs = opts.spawnMs ?? 900;
  return {
    id:'fruit_duel', minPlayers:2, maxPlayers:4, implemented:true,
    create(room, now=Date.now()) {
      return {
        players:room.players.map(p=>p.userId),
        names:Object.fromEntries(room.players.map(p=>[p.userId,p.username])),
        score:Object.fromEntries(room.players.map(p=>[p.userId,0])),
        hits:Object.fromEntries(room.players.map(p=>[p.userId,0])),
        misses:Object.fromEntries(room.players.map(p=>[p.userId,0])),
        lastSlashed:Object.fromEntries(room.players.map(p=>[p.userId,-1])),
        startedAt:now, endsAt:now+durationMs, spawnMs, phase:'playing',
        fruitId:0, fruitLane:laneFor(0), fruitExpiresAt:now+spawnMs,
      };
    },
    onAction(s,uid,{type,payload},now=Date.now()) {
      if(!s.players.includes(uid)) throw new GameError('NOT_IN_GAME');
      if(type!=='fruit_duel:slash') throw new GameError('INVALID_ACTION');
      if(s.phase!=='playing'||now>=s.endsAt) throw new GameError('BAD_PHASE');
      const lane=Number(payload?.lane);
      const fruitId=Number(payload?.fruitId);
      if(!Number.isInteger(lane)||lane<0||lane>2||fruitId!==s.fruitId) throw new GameError('INVALID_PAYLOAD');
      if(s.lastSlashed[uid]===fruitId) throw new GameError('ALREADY_SLASHED');
      s.lastSlashed[uid]=fruitId;
      if(now>s.fruitExpiresAt) { s.misses[uid]++; return {hit:false,score:s.score[uid]}; }
      const hit=lane===s.fruitLane;
      if(hit){s.score[uid]+=1;s.hits[uid]++;}else{s.misses[uid]++;}
      return {hit,score:s.score[uid],fruitId};
    },
    onTick(s,now) {
      if(s.phase!=='playing') return false;
      if(now>=s.endsAt){s.phase='finished';return true;}
      if(now>=s.fruitExpiresAt){
        s.fruitId++;
        s.fruitLane=laneFor(s.fruitId);
        s.fruitExpiresAt=now+s.spawnMs;
        return true;
      }
      return false;
    },
    getPublicState(s,uid,now=Date.now()) {
      return {gameType:'fruit_duel',phase:s.phase,startedAt:s.startedAt,endsAt:s.endsAt,
        fruitId:s.fruitId,fruitLane:s.fruitLane,fruitExpiresAt:s.fruitExpiresAt,
        players:s.players.map(u=>({userId:u,username:s.names[u],score:s.score[u],hits:s.hits[u],misses:s.misses[u]})),
        yourScore:s.score[uid]??0,yourHits:s.hits[uid]??0};
    },
    isFinished:s=>s.phase==='finished',
    getResult(s) {
      const ranking=s.players.map(u=>({userId:u,username:s.names[u],score:s.score[u],hits:s.hits[u],misses:s.misses[u]}))
        .sort((a,b)=>b.score-a.score||b.hits-a.hits);
      let rank=0; ranking.forEach((r,i)=>{if(i===0||r.score<ranking[i-1].score)rank=i+1;r.rank=rank;});
      return {gameType:'fruit_duel',scores:Object.fromEntries(s.players.map(u=>[u,s.score[u]])),ranking,winners:ranking.filter(r=>r.rank===1).map(r=>r.userId)};
    }
  };
}
module.exports={game:createFruitDuel(),createFruitDuel};
