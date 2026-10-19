import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';

enum ChessSide { white, black }
class ChessPiece {
  final ChessSide side;
  final String type;
  const ChessPiece(this.side, this.type);
  String get glyph => const {
    'K': ['♔','♚'], 'Q': ['♕','♛'], 'R': ['♖','♜'],
    'B': ['♗','♝'], 'N': ['♘','♞'], 'P': ['♙','♟'],
  }[type]![side.index];
}

final LocalGameInfo chessInfo = LocalGameInfo(
  id: 'chess',
  title: 'Chess',
  emoji: '♟️',
  color: const Color(0xFF596B55),
  tagline: 'Classic strategy on an 8×8 board.',
  rules: const [
    'White moves first. Select one of your pieces, then a highlighted legal destination.',
    'Standard piece movement, captures, check, checkmate and stalemate are enforced.',
    'Pawns move forward and capture diagonally; promotion is currently to a queen.',
    'Castling and en passant are not implemented in this version.'
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  play: (players, onFinished) => ChessBoard(players: players, onFinished: onFinished),
);

class ChessBoard extends StatefulWidget {
  final List<GpPlayer> players;
  final void Function(List<int>) onFinished;
  const ChessBoard({super.key, required this.players, required this.onFinished});
  @override State<ChessBoard> createState() => _ChessBoardState();
}
class _ChessBoardState extends State<ChessBoard> {
  late List<ChessPiece?> board;
  ChessSide turn = ChessSide.white;
  int? selected;
  Set<int> moves = {};
  bool done = false;
  String status = 'White to move';
  @override void initState() { super.initState(); _reset(); }
  void _reset() {
    turn = ChessSide.white;
    selected = null;
    moves = {};
    done = false;
    status = 'White to move';
    board = List.generate(64, (_) => null);
    const back = ['R','N','B','Q','K','B','N','R'];
    for (var x=0;x<8;x++) {
      board[x] = ChessPiece(ChessSide.black, back[x]);
      board[8+x] = const ChessPiece(ChessSide.black,'P');
      board[48+x] = const ChessPiece(ChessSide.white,'P');
      board[56+x] = ChessPiece(ChessSide.white, back[x]);
    }
  }
  bool _inside(int r,int c)=>r>=0&&r<8&&c>=0&&c<8;
  Set<int> _legal(int at) {
    final p=board[at]; if(p==null)return {};
    final r=at~/8,c=at%8; final out=<int>{};
    void add(int rr,int cc) {
      if(!_inside(rr,cc))return;
      final q=board[rr*8+cc];
      if(q==null || q.side!=p.side) out.add(rr*8+cc);
    }
    if(p.type=='P') {
      final d=p.side==ChessSide.white?-1:1;
      final nr=r+d;
      if(_inside(nr,c)&&board[nr*8+c]==null) {
        out.add(nr*8+c);
        final start=p.side==ChessSide.white?6:1;
        if(r==start&&board[(r+2*d)*8+c]==null)out.add((r+2*d)*8+c);
      }
      for(final dc in [-1,1]) if(_inside(nr,c+dc)&&board[nr*8+c+dc]?.side!=p.side&&board[nr*8+c+dc]!=null)out.add(nr*8+c+dc);
    } else if(p.type=='N') {
      for(final d in [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]])add(r+d[0],c+d[1]);
    } else {
      final dirs=<List<int>>[];
      if(['R','Q','K'].contains(p.type))dirs.addAll([[1,0],[-1,0],[0,1],[0,-1]]);
      if(['B','Q','K'].contains(p.type))dirs.addAll([[1,1],[1,-1],[-1,1],[-1,-1]]);
      if(p.type=='K') {
        for(final d in dirs) add(r+d[0],c+d[1]);
      } else {
        for(final d in dirs) {
          var rr=r+d[0],cc=c+d[1];
          while(_inside(rr,cc)) {
            final q=board[rr*8+cc];
            if(q==null){out.add(rr*8+cc);} else {if(q.side!=p.side)out.add(rr*8+cc);break;}
            rr+=d[0];cc+=d[1];
          }
        }
      }
    }
    // A king is never captured in chess. Filter pseudo-legal moves that leave
    // this side's king attacked by simulating each candidate on the board.
    final safe = <int>{};
    for (final to in out) {
      if (board[to]?.type == 'K') continue;
      final fromPiece = board[at];
      final toPiece = board[to];
      board[to] = fromPiece;
      board[at] = null;
      final remainsSafe = !_isInCheck(p.side);
      board[at] = fromPiece;
      board[to] = toPiece;
      if (remainsSafe) safe.add(to);
    }
    return safe;
  }

  bool _isInCheck(ChessSide side) {
    final king = board.indexWhere((p) => p?.side == side && p?.type == 'K');
    if (king < 0) return true;
    return _isSquareAttacked(king, side == ChessSide.white ? ChessSide.black : ChessSide.white);
  }

  bool _isSquareAttacked(int target, ChessSide bySide) {
    for (var from = 0; from < board.length; from++) {
      final p = board[from];
      if (p != null && p.side == bySide && _attacksSquare(from, target, p)) return true;
    }
    return false;
  }

  bool _attacksSquare(int from, int target, ChessPiece p) {
    final r = from ~/ 8, c = from % 8;
    final tr = target ~/ 8, tc = target % 8;
    final dr = tr - r, dc = tc - c;
    if (dr == 0 && dc == 0) return false;
    switch (p.type) {
      case 'P':
        final forward = p.side == ChessSide.white ? -1 : 1;
        return dr == forward && dc.abs() == 1;
      case 'N':
        return (dr.abs() == 2 && dc.abs() == 1) || (dr.abs() == 1 && dc.abs() == 2);
      case 'K':
        return dr.abs() <= 1 && dc.abs() <= 1;
      case 'R':
        if (dr != 0 && dc != 0) return false;
        break;
      case 'B':
        if (dr.abs() != dc.abs()) return false;
        break;
      case 'Q':
        if (!(dr == 0 || dc == 0 || dr.abs() == dc.abs())) return false;
        break;
    }
    final sr = dr == 0 ? 0 : dr.sign;
    final sc = dc == 0 ? 0 : dc.sign;
    var rr = r + sr, cc = c + sc;
    while (rr != tr || cc != tc) {
      if (board[rr * 8 + cc] != null) return false;
      rr += sr;
      cc += sc;
    }
    return true;
  }

  bool _hasLegalMove(ChessSide side) {
    for (var i = 0; i < board.length; i++) {
      if (board[i]?.side == side && _legal(i).isNotEmpty) return true;
    }
    return false;
  }

  void _tap(int i) {
    if(done)return;
    if(selected==null) {
      if(board[i]?.side==turn)setState((){selected=i;moves=_legal(i);});
      return;
    }
    if(i==selected){setState(()=>selected=null);return;}
    if(moves.contains(i)) {
      final piece=board[selected!]; final captured=board[i];
      setState((){
        board[i]=piece;board[selected!]=null;
        if(piece?.type=='P' && (i~/8==0||i~/8==7)) board[i]=ChessPiece(piece!.side,'Q');
        selected=null;moves={};
        turn = turn == ChessSide.white ? ChessSide.black : ChessSide.white;
        final checked = _isInCheck(turn);
        if (!_hasLegalMove(turn)) {
          done = true;
          if (checked) {
            final winner = turn == ChessSide.white ? ChessSide.black : ChessSide.white;
            status = 'Checkmate — ${winner == ChessSide.white ? 'White' : 'Black'} wins!';
            widget.onFinished(winner == ChessSide.white ? [1, 0] : [0, 1]);
          } else {
            status = 'Stalemate — draw.';
            widget.onFinished([0, 0]);
          }
        } else {
          status = checked
              ? '${turn == ChessSide.white ? 'White' : 'Black'} is in check'
              : '${turn == ChessSide.white ? 'White' : 'Black'} to move';
        }
      });
    } else if(board[i]?.side==turn) setState((){selected=i;moves=_legal(i);});
  }
  @override Widget build(BuildContext context) => Container(color:const Color(0xFFF2EFE7),child:SafeArea(child:Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:Text(status,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18,color:Color(0xFF243047)))),Text('White  •  Black',style:const TextStyle(fontWeight:FontWeight.w700))])),
    Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:GridView.builder(physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),itemCount:64,itemBuilder:(ctx,i){
      final p=board[i]; final light=((i~/8)+(i%8)).isEven;
      return GestureDetector(onTap:()=>_tap(i),child:Container(color:selected==i?const Color(0xFFB6D7A8):moves.contains(i)?const Color(0xFF91B9D7):light?const Color(0xFFEADFC9):const Color(0xFF72856A),child:Center(child:Text(p?.glyph??(moves.contains(i)?'•':''),style:TextStyle(fontSize:32,color:p?.side==ChessSide.white?Colors.white:const Color(0xFF1D2430),shadows:p?.side==ChessSide.white?[const Shadow(color:Colors.black54,blurRadius:2)]:null)))));
    })))),
    Padding(padding:const EdgeInsets.all(12),child:OutlinedButton(onPressed:()=>setState(_reset),child:const Text('Reset board'))),
  ])));
}
