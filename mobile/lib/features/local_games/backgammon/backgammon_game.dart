import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';

final LocalGameInfo backgammonInfo = LocalGameInfo(
  id: 'backgammon',
  title: 'Backgammon',
  emoji: '🎲',
  color: const Color(0xFF9A593D),
  tagline: 'Roll dice, move checkers, race home.',
  rules: const [
    'Roll two dice and move your checkers forward by the rolled values.',
    'Each side has 15 checkers. This starter board supports dice rolls, selecting a checker stack and moving it by a die value.',
    'The full tournament rules for hitting blots, entering from the bar, doubles, blocked points and bearing off are not implemented in this version.',
  ],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  play: (players, onFinished) => BackgammonBoard(players: players, onFinished: onFinished),
);

class BackgammonBoard extends StatefulWidget {
  final List<GpPlayer> players;
  final void Function(List<int>) onFinished;
  const BackgammonBoard({super.key, required this.players, required this.onFinished});
  @override State<BackgammonBoard> createState()=>_BackgammonBoardState();
}
class _BackgammonBoardState extends State<BackgammonBoard> {
  final Random _rng=Random();
  final List<int> _points=List.filled(24,0);
  int _turn=0,_die1=0,_die2=0,_selected=-1,_borne0=0,_borne1=0;
  bool _rolled=false,_finished=false;
  String _status='White rolls first.';
  @override void initState(){super.initState();_points[0]=2;_points[11]=5;_points[16]=3;_points[18]=5;_points[23]=-2;_points[12]=-5;_points[7]=-3;_points[5]=-5;}
  void _roll(){if(_rolled||_finished)return;setState((){_die1=_rng.nextInt(6)+1;_die2=_rng.nextInt(6)+1;_rolled=true;_selected=-1;_status='Dice: $_die1 and $_die2. Select a stack, then a destination.';});}
  bool _own(int v)=>_turn==0?v>0:v<0;
  void _tapPoint(int i){
    if(!_rolled||_finished)return;
    if(_selected<0){
      if(_own(_points[i]))setState(()=>_selected=i);
      return;
    }
    final dir=_turn==0?1:-1;
    final dist=(i-_selected)*dir;
    if(dist!=_die1&&dist!=_die2){setState(()=>_status='Move by one of your dice values.');return;}
    final source=_points[_selected],target=_points[i];
    if(!_own(source)||(_own(target)==false&&target.abs()>1)){setState(()=>_status='That point is blocked.');return;}
    setState((){
      _points[_selected]-=dir;
      if(target!=0&&!_own(target))_points[i]=0; // simplified blot handling
      _points[i]+=dir;
      _selected=-1;
      if(_die1==dist)_die1=0;else if(_die2==dist)_die2=0;
      if(_die1==0&&_die2==0){_rolled=false;_turn=1-_turn;_status='${_turn==0?'White':'Black'} to roll.';}
      else {_status='Make your next move, or end turn.';}
      if(_borne0>=15||_borne1>=15){_finished=true;widget.onFinished(_borne0>=15?[1,0]:[0,1]);}
    });
  }
  @override Widget build(BuildContext context)=>Container(color:const Color(0xFFF2EFE7),child:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text(_status,style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF243047)))),Text('${widget.players[_turn].name}',style:const TextStyle(fontWeight:FontWeight.w900))])),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      _die(_die1),const SizedBox(width:12),_die(_die2),const SizedBox(width:12),
      FilledButton(onPressed:_rolled?null:_roll,child:const Text('Roll dice')),
      const SizedBox(width:6),OutlinedButton(onPressed:_rolled?()=>setState((){_rolled=false;_turn=1-_turn;_selected=-1;_status='${_turn==0?'White':'Black'} to roll.';}):null,child:const Text('End turn')),
    ]),
    const SizedBox(height:10),
    Expanded(child:Padding(padding:const EdgeInsets.all(10),child:GridView.builder(itemCount:24,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:6,childAspectRatio:.72,crossAxisSpacing:5,mainAxisSpacing:5),itemBuilder:(ctx,i){
      final n=_points[i]; final own=n>0; final count=n.abs();
      return GestureDetector(onTap:()=>_tapPoint(i),child:Container(decoration:BoxDecoration(color:_selected==i?const Color(0xFFB8D6A3):i.isEven?const Color(0xFFE7D8BE):const Color(0xFFCFB18D),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF9E8B70),width:2)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Text('${i+1}',style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:Color(0xFF6A5C4A))),
        const SizedBox(height:3),
        if(count==0)const Text('—',style:TextStyle(color:Color(0xFF9E8B70))),
        for(var j=0;j<min(count,5);j++)Container(width:23,height:23,margin:const EdgeInsets.symmetric(vertical:1),decoration:BoxDecoration(color:own?const Color(0xFFF8F4E9):const Color(0xFF283143),shape:BoxShape.circle,border:Border.all(color:own?const Color(0xFFB8A98F):const Color(0xFF111827),width:2))),
        if(count>5)Text('+${count-5}',style:const TextStyle(fontWeight:FontWeight.w900)),
      ])));
    }))),
    const Padding(padding:EdgeInsets.all(10),child:Text('Simplified playable prototype — not full official Backgammon rules.',style:TextStyle(fontSize:11,color:Color(0xFF687386)))),
  ])));
  Widget _die(int v)=>Container(width:44,height:44,alignment:Alignment.center,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFFD1C9B9),width:2)),child:Text(v==0?'–':'$v',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:Color(0xFF243047))));
}
