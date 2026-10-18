import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../solo/solo_common.dart' show SoloFrame;

enum CompetitiveMode { carrom, eightBallPool, darts, hotPotato, hungryHippos }

const _titles = {
  CompetitiveMode.carrom: 'Carrom Clash',
  CompetitiveMode.eightBallPool: '8-Ball Pool',
  CompetitiveMode.darts: 'Darts Duel',
  CompetitiveMode.hotPotato: 'Hot Potato',
  CompetitiveMode.hungryHippos: 'Hungry Hippos',
};
const _emojis = {
  CompetitiveMode.carrom: '🔴',
  CompetitiveMode.eightBallPool: '🎱',
  CompetitiveMode.darts: '🎯',
  CompetitiveMode.hotPotato: '🥔',
  CompetitiveMode.hungryHippos: '🦛',
};
const _taglines = {
  CompetitiveMode.carrom: 'Aim, strike, pocket coins. Highest score wins.',
  CompetitiveMode.eightBallPool: 'Pocket balls with timed, turn-based shots.',
  CompetitiveMode.darts: 'Three throws per turn. First to 50 wins.',
  CompetitiveMode.hotPotato: 'Pass before the timer expires.',
  CompetitiveMode.hungryHippos: 'Mash your hippo to gobble the marbles.',
};

class TableBall {
  double x, y, vx, vy;
  final int kind; // 0 = striker/cue, 1 = ordinary ball, 2 = queen/eight ball
  bool pocketed;
  TableBall(this.x, this.y, {this.vx = 0, this.vy = 0, this.kind = 1, this.pocketed = false});
  Map<String, dynamic> toJson() => {'x':x,'y':y,'vx':vx,'vy':vy,'kind':kind,'p':pocketed};
  static TableBall fromJson(Object? value) {
    final m = value as Map;
    return TableBall((m['x'] as num).toDouble(), (m['y'] as num).toDouble(),
      vx:(m['vx'] as num).toDouble(), vy:(m['vy'] as num).toDouble(),
      kind:(m['kind'] as num).toInt(), pocketed:m['p'] == true);
  }
}

/// Shared deterministic host-side rules for five online-ready competitive games.
class CompetitiveLogic extends LocalGameLogic {
  final CompetitiveMode mode;
  final int players;
  final Random rng;
  late List<int> score;
  late List<TableBall> balls;
  late List<int> darts;
  late List<int> eliminated;
  int turn = 0, round = 1, now = 0, _last = 0;
  int potatoHolder = 0, potatoUntil = 8500, nextMarble = 0, marbles = 0;
  bool done = false, _shotStarted = false;
  String notice = 'YOUR TURN';

  CompetitiveLogic(this.mode, {int players = 2, Random? random})
      : players = players, rng = random ?? Random() {
    score = List.filled(players, 0);
    darts = List.filled(players, 0);
    eliminated = [];
    balls = _initialBalls();
    potatoHolder = rng.nextInt(players);
    potatoUntil = 7000 + rng.nextInt(6000);
    nextMarble = 450;
  }

  List<TableBall> _initialBalls() {
    if (mode == CompetitiveMode.carrom) {
      final out = <TableBall>[TableBall(.5,.78,kind:0)];
      for (var i=0;i<9;i++) {
        final a = i * pi * 2 / 9;
        out.add(TableBall(.5 + cos(a)*.115,.48 + sin(a)*.115,kind:i==0?2:1));
      }
      return out;
    }
    if (mode == CompetitiveMode.eightBallPool) {
      final out = <TableBall>[TableBall(.25,.5,kind:0)];
      var k=0;
      for (var row=0;row<5;row++) {
        for(var col=0;col<=row;col++) {
          out.add(TableBall(.69 + row*.043, .5 + (col-row/2)*.048,kind:k==7?2:1));
          k++;
        }
      }
      return out;
    }
    return [];
  }

  @override
  List<int> get scores => score;
  @override
  bool get finished => done || (mode == CompetitiveMode.darts && score.any((s)=>s>=50)) ||
      (mode == CompetitiveMode.hungryHippos && now >= 30000) ||
      (mode == CompetitiveMode.hotPotato && eliminated.length >= players-1);

  @override
  void update(int elapsed) {
    final dt = ((elapsed-_last)/1000).clamp(0.0,.04);
    _last = now = elapsed;
    if (finished) { notifyListeners(); return; }
    if (mode == CompetitiveMode.carrom || mode == CompetitiveMode.eightBallPool) _stepBalls(dt);
    if (mode == CompetitiveMode.hotPotato && elapsed >= potatoUntil) {
      if (!eliminated.contains(potatoHolder)) eliminated.add(potatoHolder);
      final alive = [for(var i=0;i<players;i++) if(!eliminated.contains(i)) i];
      if(alive.length<=1) { if(alive.isNotEmpty) score[alive.first]=1; done=true; }
      else { potatoHolder=alive[rng.nextInt(alive.length)]; potatoUntil=elapsed+6500+rng.nextInt(5500); round++; notice='PASS IT!'; }
    }
    if(mode == CompetitiveMode.hungryHippos && elapsed>=nextMarble) {
      marbles = min(12,marbles+1);
      nextMarble = elapsed + 350 + rng.nextInt(600);
    }
    notifyListeners();
  }

  void _stepBalls(double dt) {
    var moving=false;
    final pocketCenters = mode == CompetitiveMode.carrom
      ? <Offset>[const Offset(.06,.06),const Offset(.94,.06),const Offset(.06,.94),const Offset(.94,.94)]
      : <Offset>[const Offset(.05,.05),const Offset(.5,.05),const Offset(.95,.05),const Offset(.05,.95),const Offset(.5,.95),const Offset(.95,.95)];
    for(final b in balls) {
      if(b.pocketed) continue;
      b.x += b.vx*dt; b.y += b.vy*dt;
      final friction = mode == CompetitiveMode.carrom ? .985 : .99;
      b.vx *= pow(friction,dt*60).toDouble(); b.vy *= pow(friction,dt*60).toDouble();
      if(b.x<.035){b.x=.035;b.vx=b.vx.abs()*.8;} if(b.x>.965){b.x=.965;b.vx=-b.vx.abs()*.8;}
      if(b.y<.055){b.y=.055;b.vy=b.vy.abs()*.8;} if(b.y>.945){b.y=.945;b.vy=-b.vy.abs()*.8;}
      if(sqrt(b.vx*b.vx+b.vy*b.vy)<.012){b.vx=0;b.vy=0;} else moving=true;
      if(pocketCenters.any((p)=>(Offset(b.x,b.y)-p).distance<.035)) {
        b.pocketed=true;
        if(b.kind==2 && mode==CompetitiveMode.eightBallPool) {
          done=true; score[turn] += balls.where((q)=>q.pocketed && q.kind==1).length>=7?3:-3;
          notice=score[turn]>0?'8 BALL — WIN':'8 BALL — FOUL';
        } else if(b.kind==0) { b.pocketed=false; b.x=.25; b.y=.5; b.vx=0;b.vy=0; score[turn]=max(0,score[turn]-1); notice='CUE FOUL'; }
        else { score[turn]++; notice='POCKETED +1'; }
      }
    }
    // Small deterministic ball collisions.
    for(var i=0;i<balls.length;i++) for(var j=i+1;j<balls.length;j++) {
      final a=balls[i],b=balls[j]; if(a.pocketed||b.pocketed) continue;
      final dx=b.x-a.x,dy=b.y-a.y,d=hypot(dx,dy);
      if(d>0&&d<.034) {
        final nx=dx/d,ny=dy/d;
        final av=a.vx*nx+a.vy*ny,bv=b.vx*nx+b.vy*ny;
        a.vx += (bv-av)*nx*.9; a.vy += (bv-av)*ny*.9;
        b.vx += (av-bv)*nx*.9; b.vy += (av-bv)*ny*.9;
        final push=(.034-d)/2; a.x-=nx*push;a.y-=ny*push;b.x+=nx*push;b.y+=ny*push;
        moving=true;
      }
    }
    if(!moving && _shotStarted) { _shotStarted=false; if(!done) turn=(turn+1)%players; }
    if(!moving && balls.every((b)=>b.vx==0&&b.vy==0) && balls.any((b)=>b.pocketed)) {
      if(balls.where((b)=>!b.pocketed&&b.kind!=0).length==0) { done=true; }
    }
  }

  void shoot(int player, double angle, double power) {
    if(forward('shoot',[player,angle,power])) return;
    if(finished||player!=turn||balls.any((b)=>!b.pocketed&&(b.vx!=0||b.vy!=0))) return;
    final cue=balls.firstWhere((b)=>b.kind==0);
    _shotStarted=true;
    cue.vx=cos(angle)*power.clamp(.1,1.0)*1.8;
    cue.vy=sin(angle)*power.clamp(.1,1.0)*1.8;
    round++;
    notifyListeners();
  }

  void throwDart(int player, double x, double y) {
    if(forward('dart',[player,x,y])) return;
    if(finished||player!=turn||mode!=CompetitiveMode.darts) return;
    final d=sqrt((x-.5)*(x-.5)+(y-.5)*(y-.5));
    final points=d<.07?10:d<.16?7:d<.27?5:d<.39?3:1;
    score[player]+=points; darts[player]++;
    if(score[player]>=50){done=true;notice='BULLSEYE — WIN';}
    else if(darts[player]>=3){darts[player]=0;turn=(turn+1)%players;round++;notice='NEXT PLAYER';}
    notifyListeners();
  }

  void pass(int player) {
    if(forward('pass',[player])) return;
    if(mode!=CompetitiveMode.hotPotato||finished||player!=potatoHolder||eliminated.contains(player)) return;
    final alive=[for(var i=0;i<players;i++) if(!eliminated.contains(i)&&i!=player) i];
    if(alive.isEmpty) return;
    potatoHolder=alive[rng.nextInt(alive.length)];
    potatoUntil=now+6500+rng.nextInt(5500);
    notice='PASSED!'; score[player]++; notifyListeners();
  }

  void chomp(int player) {
    if(forward('chomp',[player])) return;
    if(mode!=CompetitiveMode.hungryHippos||finished||player<0||player>=players||marbles<=0) return;
    marbles--; score[player]++; notifyListeners();
  }

  Map<String,dynamic> save() => {
    'score':score,'balls':[for(final b in balls)b.toJson()],'darts':darts,'eliminated':eliminated,
    'turn':turn,'round':round,'now':now,'potatoHolder':potatoHolder,'potatoUntil':potatoUntil,
    'nextMarble':nextMarble,'marbles':marbles,'done':done,'notice':notice,
  };
  void loadState(Map<String,dynamic> s) {
    score.setAll(0,(s['score'] as List).map((x)=>(x as num).toInt()));
    balls=(s['balls'] as List).map(TableBall.fromJson).toList();
    darts=(s['darts'] as List).map((x)=>(x as num).toInt()).toList();
    eliminated=(s['eliminated'] as List).map((x)=>(x as num).toInt()).toList();
    turn=(s['turn'] as num).toInt(); round=(s['round'] as num).toInt(); now=(s['now'] as num).toInt();
    potatoHolder=(s['potatoHolder'] as num).toInt(); potatoUntil=(s['potatoUntil'] as num).toInt();
    nextMarble=(s['nextMarble'] as num).toInt(); marbles=(s['marbles'] as num).toInt();
    done=s['done']==true; notice=s['notice'] as String? ?? '';
  }

  void applyAction(int from,String name,List<Object?> args) {
    if(name=='shoot' && (args[0] as num).toInt()==from) shoot(from,(args[1] as num).toDouble(),(args[2] as num).toDouble());
    if(name=='dart' && (args[0] as num).toInt()==from) throwDart(from,(args[1] as num).toDouble(),(args[2] as num).toDouble());
    if(name=='pass' && (args[0] as num).toInt()==from) pass(from);
    if(name=='chomp' && (args[0] as num).toInt()==from) chomp(from);
  }
}

LocalGameInfo competitiveInfo(CompetitiveMode mode) => LocalGameInfo(
  id: switch(mode) {
    CompetitiveMode.carrom=>'carrom',
    CompetitiveMode.eightBallPool=>'eight_ball_pool',
    CompetitiveMode.darts=>'darts',
    CompetitiveMode.hotPotato=>'hot_potato',
    CompetitiveMode.hungryHippos=>'hungry_hippos',
  },
  title:_titles[mode]!, emoji:_emojis[mode]!, color:const Color(0xFFB77746),
  tagline:_taglines[mode]!, rules:[
    _taglines[mode]!,
    switch(mode) {
      CompetitiveMode.carrom=>'Drag from the striker to aim; release to shoot. Pocketed coins score one point.',
      CompetitiveMode.eightBallPool=>'Drag from the cue ball to aim; release to shoot. Pocket balls to score; pocket the 8-ball to finish.',
      CompetitiveMode.darts=>'Tap the target to throw. Bullseye is 10; first to 50 points wins.',
      CompetitiveMode.hotPotato=>'The current holder taps PASS to send the potato to another player before it explodes.',
      CompetitiveMode.hungryHippos=>'Tap CHOMP to collect a marble. Most marbles in 30 seconds wins.',
    },
    'Online rooms sync game actions and state through the room host.',
  ],
  scoreUnit:'points', splitScreen:false,
  minPlayers:2, maxPlayers: mode==CompetitiveMode.hungryHippos||mode==CompetitiveMode.hotPotato?4:2,
  play:(players,onFinished)=>TickingPlay<CompetitiveLogic>(
    create:()=>CompetitiveLogic(mode,players:players.length),
    onFinished:onFinished,
    builder:(context,g)=>_CompetitiveBoard(mode:mode,g:g,players:players,me:0,online:false),
  ),
  online:RelaySpec<CompetitiveLogic>(
    create:(n)=>CompetitiveLogic(mode,players:n),
    save:(g)=>g.save(),
    load:(g,s,me)=>g.loadState(s),
    apply:(g,from,name,args)=>g.applyAction(from,name,args),
    view:(context,g,players,me)=>_CompetitiveBoard(mode:mode,g:g,players:players,me:me,online:true),
    continuous: const {},
  ),
);

final carromInfo=competitiveInfo(CompetitiveMode.carrom);
final eightBallPoolInfo=competitiveInfo(CompetitiveMode.eightBallPool);
final dartsOnlineInfo=competitiveInfo(CompetitiveMode.darts);
final hotPotatoInfo=competitiveInfo(CompetitiveMode.hotPotato);
final hungryHipposInfo=competitiveInfo(CompetitiveMode.hungryHippos);

class _CompetitiveBoard extends StatelessWidget {
  final CompetitiveMode mode; final CompetitiveLogic g; final List<GpPlayer> players; final int me; final bool online;
  const _CompetitiveBoard({required this.mode,required this.g,required this.players,required this.me,required this.online});
  @override
  Widget build(BuildContext context) {
    final active=mode==CompetitiveMode.hotPotato?g.potatoHolder:g.turn;
    return Column(children:[
      Padding(padding:const EdgeInsets.all(10),child:Row(children:[
        Expanded(child:Text(_titles[mode]!.toUpperCase(),style:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.1))),
        Text('ROUND ${g.round}',style:const TextStyle(fontWeight:FontWeight.w800)),
      ])),
      Wrap(spacing:6,runSpacing:6,alignment:WrapAlignment.center,children:[
        for(var i=0;i<players.length;i++) Chip(
          avatar:CircleAvatar(backgroundColor:players[i].color,child:Text('${i+1}',style:const TextStyle(color:Colors.white))),
          label:Text('${players[i].name}: ${g.score[i]}'),
          backgroundColor:i==active?const Color(0xFFF2D8A7):null,
        )
      ]),
      Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:Padding(
        padding:const EdgeInsets.all(12),
        child: mode==CompetitiveMode.carrom||mode==CompetitiveMode.eightBallPool
          ? _TableBoard(mode:mode,g:g,onShot:(a,p)=>g.shoot(online?me:g.turn,a,p))
          : mode==CompetitiveMode.darts
            ? _DartBoard(onThrow:(x,y)=>g.throwDart(online?me:g.turn,x,y),score:g.score[me])
            : mode==CompetitiveMode.hotPotato
              ? _PotatoBoard(g:g,me:me,players:players)
              : _HippoBoard(g:g,me:me,players:players,online:online),
      )))),
      Padding(padding:const EdgeInsets.all(12),child:Text(g.notice,style:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.1))),
    ]);
  }
}

class _TableBoard extends StatelessWidget {
  final CompetitiveMode mode; final CompetitiveLogic g; final void Function(double,double) onShot;
  const _TableBoard({required this.mode,required this.g,required this.onShot});
  @override
  Widget build(BuildContext context)=>GestureDetector(
    onPanEnd:(d){
      final v=d.velocity.pixelsPerSecond;
      if(v.distance<80)return;
      onShot(atan2(-v.dy,-v.dx), (v.distance/1600).clamp(.12,1.0));
    },
    child:CustomPaint(painter:_TablePainter(mode,g.balls),child:const SizedBox.expand()),
  );
}
class _TablePainter extends CustomPainter {
  final CompetitiveMode mode; final List<TableBall> balls;
  _TablePainter(this.mode,this.balls);
  @override
  void paint(Canvas canvas,Size size){
    final r=Offset.zero&size;
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(2),const Radius.circular(18)),Paint()..color=mode==CompetitiveMode.carrom?const Color(0xFFB9824B):const Color(0xFF176447));
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(size.width*.07),const Radius.circular(14)),Paint()..color=mode==CompetitiveMode.carrom?const Color(0xFFF0D7A8):const Color(0xFF1E805A));
    final pocket=Paint()..color=const Color(0xFF15191B);
    final pockets=mode==CompetitiveMode.carrom?[Offset(.07,.07),Offset(.93,.07),Offset(.07,.93),Offset(.93,.93)]:[Offset(.05,.05),Offset(.5,.05),Offset(.95,.05),Offset(.05,.95),Offset(.5,.95),Offset(.95,.95)];
    for(final p in pockets)canvas.drawCircle(Offset(p.dx*size.width,p.dy*size.height),size.width*.035,pocket);
    for(final b in balls){
      if(b.pocketed)continue;
      final p=Offset(b.x*size.width,b.y*size.height);
      final color=b.kind==0?const Color(0xFF24282B):b.kind==2?const Color(0xFFD8A92D):const Color(0xFFF7F1E6);
      canvas.drawCircle(p,size.width*(mode==CompetitiveMode.carrom?.018:.022),Paint()..color=color);
      canvas.drawCircle(p,size.width*(mode==CompetitiveMode.carrom?.018:.022),Paint()..color=const Color(0xFF222222)..style=PaintingStyle.stroke..strokeWidth=1);
    }
    if(balls.isNotEmpty&&!balls.first.pocketed&&balls.first.vx==0&&balls.first.vy==0){
      final cue=Offset(balls.first.x*size.width,balls.first.y*size.height);
      canvas.drawCircle(cue,size.width*.12,Paint()..color=const Color(0x44FFFFFF)..style=PaintingStyle.stroke..strokeWidth=1);
    }
  }
  @override bool shouldRepaint(covariant _TablePainter old)=>true;
}
class _DartBoard extends StatelessWidget {
  final void Function(double,double) onThrow; final int score;
  const _DartBoard({required this.onThrow,required this.score});
  @override Widget build(BuildContext context)=>GestureDetector(
    onTapDown:(d){final box=context.findRenderObject() as RenderBox;final p=box.globalToLocal(d.globalPosition);onThrow(p.dx/box.size.width,p.dy/box.size.height);},
    child:CustomPaint(painter:_DartPainter(),child:const SizedBox.expand()));
}
class _DartPainter extends CustomPainter {
  @override void paint(Canvas c,Size s){final center=Offset(s.width/2,s.height/2);for(var i=6;i>=1;i--){c.drawCircle(center,s.width*.48*i/6,Paint()..color=i.isEven?const Color(0xFF2E3C42):const Color(0xFFC65C43));}c.drawCircle(center,s.width*.07,Paint()..color=const Color(0xFFE7BC59));}
  @override bool shouldRepaint(covariant _DartPainter old)=>false;
}
class _PotatoBoard extends StatelessWidget {
  final CompetitiveLogic g; final int me; final List<GpPlayer> players;
  const _PotatoBoard({required this.g,required this.me,required this.players});
  @override Widget build(BuildContext context){final holder=g.potatoHolder==me;return Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    Text(holder?'🥔':'⏳',style:const TextStyle(fontSize:100)),
    Text(holder?'IT\'S IN YOUR HAND':'WAIT FOR THE POTATO',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
    const SizedBox(height:20),
    FilledButton(onPressed:holder?()=>g.pass(g.potatoHolder):null,child:const Text('PASS POTATO')),
    Text('${max(0,(g.potatoUntil-g.now)~/1000)} seconds left'),
  ]);}
}
class _HippoBoard extends StatelessWidget {
  final CompetitiveLogic g; final int me; final List<GpPlayer> players; final bool online;
  const _HippoBoard({required this.g,required this.me,required this.players,required this.online});
  @override Widget build(BuildContext context)=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    Text('🦛',style:TextStyle(fontSize:60+g.score[me].clamp(0,10)*2)),
    Text('${g.marbles} marbles in the pond',style:const TextStyle(fontWeight:FontWeight.w700)),
    const SizedBox(height:12),
    if(!g.finished) Wrap(spacing:6,children:[for(var i=0;i<players.length;i++) if(!online || i==me) FilledButton(onPressed:g.marbles>0?()=>g.chomp(i):null,child:Text('CHOMP ${players[i].name}'))]),
    const SizedBox(height:8),
    Text('Mash CHOMP to collect marbles before time runs out.'),
  ]);
}
