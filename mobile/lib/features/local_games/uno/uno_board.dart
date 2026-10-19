import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';

enum UColor { red, yellow, green, blue, wild }
enum UKind { number, skip, reverse, drawTwo, wild, wildFour }

class UCard {
  final int id;
  final UColor color;
  final UKind kind;
  final int number;
  const UCard(this.id, this.color, this.kind, [this.number = 0]);
  String get label => switch (kind) {
    UKind.number => '$number', UKind.skip => 'SKIP', UKind.reverse => 'REV',
    UKind.drawTwo => '+2', UKind.wild => 'WILD', UKind.wildFour => '+4',
  };
  Color get tint => switch (color) {
    UColor.red => const Color(0xFFE53935), UColor.yellow => const Color(0xFFFBC02D),
    UColor.green => const Color(0xFF2E9D59), UColor.blue => const Color(0xFF2477D4),
    UColor.wild => const Color(0xFF252A36),
  };
}

class UnoBoard extends StatefulWidget {
  final List<GpPlayer> players;
  final void Function(List<int>) onFinished;
  const UnoBoard({super.key, required this.players, required this.onFinished});
  @override
  State<UnoBoard> createState() => _UnoBoardState();
}

class _UnoBoardState extends State<UnoBoard> {
  final _rng = Random();
  final _hands = <List<UCard>>[[], []];
  final _draw = <UCard>[];
  final _discard = <UCard>[];
  int _id = 0, _turn = 0;
  int? _drawnCardId;
  UColor _active = UColor.red;
  bool _drew = false, _uno = false, _ended = false;
  String _status = 'Match the colour, number or symbol.';

  @override
  void initState() {
    super.initState();
    final deck = <UCard>[];
    for (final c in [UColor.red, UColor.yellow, UColor.green, UColor.blue]) {
      deck.add(UCard(_id++, c, UKind.number));
      for (var n=1; n<=9; n++) { deck.add(UCard(_id++,c,UKind.number,n)); deck.add(UCard(_id++,c,UKind.number,n)); }
      for (var i=0; i<2; i++) { for (final k in [UKind.skip,UKind.reverse,UKind.drawTwo]) { deck.add(UCard(_id++,c,k)); } }
    }
    for (var i=0; i<4; i++) { deck.add(UCard(_id++,UColor.wild,UKind.wild)); deck.add(UCard(_id++,UColor.wild,UKind.wildFour)); }
    deck.shuffle(_rng);
    for (var i=0; i<7; i++) { _hands[0].add(deck.removeLast()); _hands[1].add(deck.removeLast()); }
    _draw.addAll(deck);
    var top = _draw.removeLast();
    while (top.color == UColor.wild) { _draw.insert(0,top); top = _draw.removeLast(); }
    _discard.add(top); _active = top.color;
  }

  UCard get _top => _discard.last;
  bool _legal(UCard c) => c.color == UColor.wild || c.color == _active ||
      (c.kind == UKind.number && _top.kind == UKind.number && c.number == _top.number) ||
      (c.kind != UKind.number && c.kind == _top.kind);

  void _refill() {
    if (_draw.isNotEmpty) return;
    if (_discard.length < 2) return;
    final top = _discard.removeLast(); _draw.addAll(_discard); _discard.clear(); _discard.add(top); _draw.shuffle(_rng);
  }
  void _drawCards(int count) { for (var i=0;i<count;i++) { _refill(); if (_draw.isNotEmpty) _hands[_turn].add(_draw.removeLast()); } }

  Future<UColor?> _pickColor() => showDialog<UColor>(context: context, barrierDismissible: false, builder: (ctx) =>
    AlertDialog(title: const Text('Choose colour'), content: Wrap(spacing: 10, children: [
      for (final c in [UColor.red,UColor.yellow,UColor.green,UColor.blue])
        InkWell(onTap: () => Navigator.pop(ctx,c), child: Container(width:44,height:44,decoration:BoxDecoration(color:UCard(0,c,UKind.number).tint,borderRadius:BorderRadius.circular(12)))),
    ])));

  Future<void> _play(UCard c) async {
    if (_ended) return;
    if (_drew && c.id != _drawnCardId) {
      setState(() => _status = 'After drawing, you may only play the card you just drew.');
      return;
    }
    if (!_legal(c)) return;
    final hand = _hands[_turn];
    if (c.kind == UKind.wildFour && hand.any((x) => x.color == _active)) {
      setState(() => _status = 'Wild +4 is only legal when you have no active-colour card.'); return;
    }
    setState(() { hand.removeWhere((x)=>x.id==c.id); _discard.add(c); _drew=false; _drawnCardId=null; });
    if (c.color == UColor.wild) { final selected = await _pickColor(); if (!mounted || selected == null) return; _active = selected; }
    else { _active = c.color; }
    if (hand.isEmpty) {
      setState(() { _ended=true; _status='${widget.players[_turn].name} wins!'; });
      widget.onFinished(_turn == 0 ? [1, 0] : [0, 1]); return;
    }
    if (hand.length == 1 && !_uno) { _drawCards(2); _status='UNO not called — 2-card penalty.'; }
    if (c.kind == UKind.drawTwo || c.kind == UKind.wildFour) {
      _turn=1-_turn; _drawCards(c.kind == UKind.drawTwo ? 2 : 4); _turn=1-_turn;
    } else if (c.kind != UKind.skip && c.kind != UKind.reverse) { _turn=1-_turn; }
    _uno=false;
    setState(() { _status='${widget.players[_turn].name}\'s turn.'; });
  }

  void _drawOne() {
    if (_ended || _drew) return;
    setState(() {
      final before = _hands[_turn].map((card) => card.id).toSet();
      _drawCards(1);
      _drawnCardId = _hands[_turn].firstWhere((card) => !before.contains(card.id), orElse: () => _hands[_turn].last).id;
      _drew=true;
      _status='Play the drawn card if legal, or pass.';
    });
  }
  void _pass() {
    if (!_drew || _ended) return;
    setState(() { _turn=1-_turn; _drew=false; _uno=false; _status='${widget.players[_turn].name}\'s turn.'; });
  }

  @override
  Widget build(BuildContext context) {
    final hand = _hands[_turn];
    return Container(color: const Color(0xFFF2EFE7), child: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: Text('${widget.players[_turn].name} • YOUR TURN',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:Color(0xFF243047)))),
        Text('${hand.length} cards',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFF243047))),
        const SizedBox(width:12), Text('Opponent ${_hands[1-_turn].length}',style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF687386))),
      ])),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        Container(width:64,height:94,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFF252A36),borderRadius:BorderRadius.circular(14)),child:const Text('UNO',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:20))),
        const SizedBox(width:20),
        Container(width:64,height:94,alignment:Alignment.center,decoration:BoxDecoration(color:_top.tint,borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.white,width:3)),child:Text(_top.label,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:20))),
        const SizedBox(width:10), Container(width:18,height:18,decoration:BoxDecoration(color:UCard(0,_active,UKind.number).tint,shape:BoxShape.circle)),
      ]),
      Padding(padding:const EdgeInsets.all(8),child:Text(_status,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF344054)))),
      Wrap(spacing:6,children:[
        OutlinedButton(onPressed:_drew?null:_drawOne,child:const Text('Draw')),
        OutlinedButton(onPressed:_drew?_pass:null,child:const Text('Pass')),
        FilledButton(onPressed:hand.length==2?()=>setState(()=>_uno=true):null,child:const Text('UNO!')),
      ]),
      const Padding(padding:EdgeInsets.all(8),child:Align(alignment:Alignment.centerLeft,child:Text('YOUR HAND',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1.2,color:Color(0xFF687386))))),
      Expanded(child:SingleChildScrollView(child:Wrap(alignment:WrapAlignment.center,spacing:6,runSpacing:7,children:[
        for(final card in hand)
          GestureDetector(onTap:()=>_play(card),child:Opacity(opacity:_legal(card)?1:.5,child:Container(width:62,height:94,alignment:Alignment.center,decoration:BoxDecoration(color:card.tint,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white,width:3),boxShadow:const[BoxShadow(color:Color(0x22000000),blurRadius:4,offset:Offset(0,2))]),child:Text(card.label,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:15))))),
      ]))),
      const Padding(padding:EdgeInsets.all(8),child:Text('Pass the phone after your turn and keep your cards private.',style:TextStyle(fontSize:11,color:Color(0xFF687386)))),
    ])));
  }
}
