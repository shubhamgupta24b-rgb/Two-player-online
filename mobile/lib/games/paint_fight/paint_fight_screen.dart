import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session/game_session_manager.dart';

class PaintFightScreen extends StatefulWidget {
  const PaintFightScreen({super.key});
  @override State<PaintFightScreen> createState()=>_PaintFightScreenState();
}
class _PaintFightScreenState extends State<PaintFightScreen>{
  Timer? timer;
  @override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:250),(_){if(mounted)setState((){});});}
  @override void dispose(){timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){
    final session=context.watch<GameSessionManager>();
    final state=session.state!;
    final phase=state['phase'] as String;
    final end=(state['endsAt'] as num).toInt();
    final left=((end-session.serverNowMs)<=0?0:((end-session.serverNowMs)/1000).ceil());
    final cells=(state['yourCells'] as List).map((e)=>e.toString()).toSet();
    final w=(state['width'] as num).toInt(),h=(state['height'] as num).toInt();
    final players=(state['players'] as List).cast<Map>();
    return Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Text(phase=='playing'?'PAINT FIGHT':'TIME UP',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
      Text(left.toString()+' s • Your territory: '+state['yourScore'].toString()),
      const SizedBox(height:8),
      Expanded(child:AspectRatio(aspectRatio:w/h,child:GridView.builder(
        physics:const NeverScrollableScrollPhysics(),
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:w),
        itemCount:w*h,itemBuilder:(context,index){
          final x=index%w,y=index~/w,key=x.toString()+','+y.toString(),owned=cells.contains(key);
          return GestureDetector(
            onTap:phase=='playing'?()=>session.action('paint_fight:paint',{'x':x,'y':y}):null,
            child:Container(margin:const EdgeInsets.all(1),alignment:Alignment.center,
              decoration:BoxDecoration(border:Border.all(color:Theme.of(context).dividerColor),
                color:owned?Theme.of(context).colorScheme.primaryContainer:Theme.of(context).colorScheme.surfaceContainerHighest),
              child:owned?const Icon(Icons.brush,size:16):null),
          );
        }))),
      const SizedBox(height:8),
      for(final player in players) Row(children:[Expanded(child:Text(player['username'].toString())),Text(player['score'].toString())]),
    ]));
  }
}
