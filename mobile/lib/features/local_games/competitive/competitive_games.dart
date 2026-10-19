import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_shell.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';

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
  bool done = false, _shotStarted = false, _shotPocketedObject = false;
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
    final dt = ((elapsed-_last)/1000).clamp(0.0,.04).toDouble();
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
        else { score[turn]++; _shotPocketedObject=true; notice='POCKETED +1'; }
      }
    }
    // Small deterministic ball collisions.
    for(var i=0;i<balls.length;i++) for(var j=i+1;j<balls.length;j++) {
      final a=balls[i],b=balls[j]; if(a.pocketed||b.pocketed) continue;
      final dx=b.x-a.x,dy=b.y-a.y,d=sqrt(dx*dx+dy*dy);
      if(d>0&&d<.034) {
        final nx=dx/d,ny=dy/d;
        final av=a.vx*nx+a.vy*ny,bv=b.vx*nx+b.vy*ny;
        a.vx += (bv-av)*nx*.9; a.vy += (bv-av)*ny*.9;
        b.vx += (av-bv)*nx*.9; b.vy += (av-bv)*ny*.9;
        final push=(.034-d)/2; a.x-=nx*push;a.y-=ny*push;b.x+=nx*push;b.y+=ny*push;
        moving=true;
      }
    }
    if(!moving && _shotStarted) { _shotStarted=false; if(!done && !_shotPocketedObject) turn=(turn+1)%players; _shotPocketedObject=false; }
    if(!moving && balls.every((b)=>b.vx==0&&b.vy==0) && balls.any((b)=>b.pocketed)) {
      if(balls.where((b)=>!b.pocketed&&b.kind!=0).length==0) { done=true; }
    }
  }

  void shoot(int player, double angle, double power) {
    if(forward('shoot',[player,angle,power])) return;
    if(finished||player!=turn||balls.any((b)=>!b.pocketed&&(b.vx!=0||b.vy!=0))) return;
    final cue=balls.firstWhere((b)=>b.kind==0);
    _shotStarted=true;
    cue.vx=cos(angle)*power.clamp(.1,1.0).toDouble()*1.8;
    cue.vy=sin(angle)*power.clamp(.1,1.0).toDouble()*1.8;
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
    'shotPocketedObject':_shotPocketedObject,'shotStarted':_shotStarted,
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
    done=s['done']==true; _shotPocketedObject=s['shotPocketedObject']==true; _shotStarted=s['shotStarted']==true; notice=s['notice'] as String? ?? '';
  }

  void applyAction(int from,String name,List<Object?> args) {
    if (args.isEmpty) return;
    if(name=='shoot' && args.length >= 3 && (args[0] as num).toInt()==from) shoot(from,(args[1] as num).toDouble(),(args[2] as num).toDouble());
    if(name=='dart' && args.length >= 3 && (args[0] as num).toInt()==from) throwDart(from,(args[1] as num).toDouble(),(args[2] as num).toDouble());
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
        Expanded(child:Text(_titles[mode]!.toUpperCase(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.1))),
        Text('ROUND ${g.round}',style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(width:6),
        const HelpButton(),
        const SizedBox(width:4),
        const PauseButton(),
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
            ? _DartBoard(onThrow:(x,y)=>g.throwDart(online?me:g.turn,x,y))
            : mode==CompetitiveMode.hotPotato
              ? _PotatoBoard(g:g,me:me)
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
      onShot(atan2(-v.dy,-v.dx), (v.distance/1600).clamp(.12,1.0).toDouble());
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
    // The supplied Pool banner uses a flat green cloth, dark pocket mouths,
    // and warm timber rails. Keep the same restrained, outlined treatment here.
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(18)),
      Paint()..color = const Color(0xFF9F543D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(size.width * .035), const Radius.circular(15)),
      Paint()..color = const Color(0xFF171615),
    );
    final cloth = mode == CompetitiveMode.carrom
        ? const Color(0xFFF2D8A6)
        : const Color(0xFF2DB744);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(size.width * .065), const Radius.circular(11)),
      Paint()..color = cloth,
    );

    final pocket = Paint()..color = const Color(0xFF101010);
    final pockets = mode == CompetitiveMode.carrom
        ? [const Offset(.065,.065),const Offset(.935,.065),const Offset(.065,.935),const Offset(.935,.935)]
        : [const Offset(.055,.055),const Offset(.5,.055),const Offset(.945,.055),const Offset(.055,.945),const Offset(.5,.945),const Offset(.945,.945)];
    for (final p in pockets) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), size.width * .035, pocket);
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        size.width * .039,
        Paint()..color = const Color(0xFF171615)..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }

    if (mode == CompetitiveMode.carrom) {
      final center = Offset(size.width * .5, size.height * .48);
      canvas.drawCircle(center, size.width * .15, Paint()..color = const Color(0xFFC76A48)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(center, size.width * .105, Paint()..color = const Color(0xFFB75A42)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      final linePaint = Paint()..color = const Color(0xFFB75A42)..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawLine(Offset(size.width*.18,size.height*.78),Offset(size.width*.82,size.height*.78),linePaint);
      canvas.drawLine(Offset(size.width*.18,size.height*.82),Offset(size.width*.82,size.height*.82),linePaint);
    }

    const poolColors = [
      Color(0xFFE9C33C), Color(0xFFDF4A43), Color(0xFF3C88D8),
      Color(0xFF8E58B4), Color(0xFFEC8B34), Color(0xFF2B9B73),
      Color(0xFFB74B86), Color(0xFF303030),
    ];
    for (var i = 0; i < balls.length; i++) {
      final b = balls[i];
      if (b.pocketed) continue;
      final p = Offset(b.x * size.width, b.y * size.height);
      final radius = size.width * (mode == CompetitiveMode.carrom ? .019 : .022);
      final Color color;
      if (mode == CompetitiveMode.carrom) {
        color = b.kind == 0
            ? const Color(0xFFF9F2DF)
            : b.kind == 2
                ? const Color(0xFFCE3E3B)
                : (i.isEven ? const Color(0xFF242424) : const Color(0xFFF9F2DF));
      } else {
        color = b.kind == 0
            ? const Color(0xFFF9F7EE)
            : b.kind == 2
                ? const Color(0xFF171717)
                : poolColors[i % poolColors.length];
      }
      canvas.drawCircle(p, radius, Paint()..color = color);
      canvas.drawCircle(p, radius, Paint()..color = const Color(0xFF171615)..style = PaintingStyle.stroke..strokeWidth = 1.2);
      canvas.drawCircle(
        p.translate(-radius * .28, -radius * .3),
        radius * .22,
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
    if(balls.isNotEmpty&&!balls.first.pocketed&&balls.first.vx==0&&balls.first.vy==0){
      final cue=Offset(balls.first.x*size.width,balls.first.y*size.height);
      canvas.drawCircle(cue,size.width*.12,Paint()..color=const Color(0x44FFFFFF)..style=PaintingStyle.stroke..strokeWidth=1);
    }
  }
  @override bool shouldRepaint(covariant _TablePainter old)=>true;
}
class _DartBoard extends StatelessWidget {
  final void Function(double,double) onThrow;
  const _DartBoard({required this.onThrow});
  @override Widget build(BuildContext context)=>GestureDetector(
    onTapDown:(d){final box=context.findRenderObject() as RenderBox;final p=box.globalToLocal(d.globalPosition);onThrow(p.dx/box.size.width,p.dy/box.size.height);},
    child:CustomPaint(painter:_DartPainter(),child:const SizedBox.expand()));
}
class _DartPainter extends CustomPainter {
  @override void paint(Canvas c,Size s){final center=Offset(s.width/2,s.height/2);for(var i=6;i>=1;i--){c.drawCircle(center,s.width*.48*i/6,Paint()..color=i.isEven?const Color(0xFF2E3C42):const Color(0xFFC65C43));}c.drawCircle(center,s.width*.07,Paint()..color=const Color(0xFFE7BC59));}
  @override bool shouldRepaint(covariant _DartPainter old)=>false;
}
class _PotatoBoard extends StatelessWidget {
  final CompetitiveLogic g; final int me;
  const _PotatoBoard({required this.g,required this.me});
  @override Widget build(BuildContext context) {
    final holder = g.potatoHolder == me;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 280 || constraints.maxWidth < 280;
      final iconSize = (constraints.maxHeight * .27).clamp(42.0, compact ? 64.0 : 88.0);
      return Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children:[
        Text(holder ? '🥔' : '⏳', style: TextStyle(fontSize: iconSize)),
        const SizedBox(height: 4),
        Text(holder ? "IT'S IN YOUR HAND" : 'WAIT FOR THE POTATO',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 12 : 16)),
        SizedBox(height: compact ? 6 : 12),
        FilledButton(
          onPressed: holder ? () => g.pass(g.potatoHolder) : null,
          child: const Text('PASS POTATO'),
        ),
        const SizedBox(height: 4),
        Text('${max(0,(g.potatoUntil-g.now)~/1000)} seconds left',
          textAlign: TextAlign.center, style: TextStyle(fontSize: compact ? 11 : 13)),
      ]);
    });
  }
}
class _HippoBoard extends StatelessWidget {
  final CompetitiveLogic g; final int me; final List<GpPlayer> players; final bool online;
  const _HippoBoard({required this.g,required this.me,required this.players,required this.online});
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final compact = constraints.maxHeight < 280 || constraints.maxWidth < 280;
    final iconSize = (constraints.maxHeight * .23).clamp(34.0, compact ? 52.0 : 78.0);
    final buttonWidth = (constraints.maxWidth - 8) / 2;
    return Column(mainAxisAlignment:MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children:[
      Text('🦛',style:TextStyle(fontSize:iconSize)),
      Text('${g.marbles} marbles in the pond',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700)),
      SizedBox(height: compact ? 3 : 8),
      if(!g.finished) Wrap(alignment: WrapAlignment.center, spacing:4, runSpacing:3, children:[
        for(var i=0;i<players.length;i++) if(!online || i==me)
          SizedBox(width: online ? constraints.maxWidth : buttonWidth, child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10, vertical: compact ? 2 : 6),
              minimumSize: Size(0, compact ? 28 : 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed:g.marbles>0?()=>g.chomp(i):null,
            child:Text('P${i+1} CHOMP', maxLines:1, overflow:TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 10 : 12)),
          ))
      ]),
      if (!compact) const SizedBox(height:6),
      if (!compact) const Text('Tap your player button to collect a marble.',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
    ]);
  });
}
