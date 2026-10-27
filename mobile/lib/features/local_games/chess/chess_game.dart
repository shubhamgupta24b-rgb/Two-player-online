import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../party/party_widgets.dart' show GameTopBar;
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
    'Castling is allowed when the king and rook have not moved and the king does not cross an attacked square. En passant is available immediately after a two-square pawn move.'
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
  bool _whiteKingMoved = false, _blackKingMoved = false;
  bool _whiteRookLeftMoved = false, _whiteRookRightMoved = false;
  bool _blackRookLeftMoved = false, _blackRookRightMoved = false;
  int? _enPassantTarget;
  String status = 'White to move';
  @override void initState() { super.initState(); _reset(); }
  void _reset() {
    turn = ChessSide.white;
    selected = null;
    moves = {};
    done = false;
    _whiteKingMoved = _blackKingMoved = false;
    _whiteRookLeftMoved = _whiteRookRightMoved = false;
    _blackRookLeftMoved = _blackRookRightMoved = false;
    _enPassantTarget = null;
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
      for (final dc in [-1, 1]) {
        if (!_inside(nr, c + dc)) continue;
        final target = nr * 8 + c + dc;
        if (board[target] != null && board[target]!.side != p.side) out.add(target);
        if (target == _enPassantTarget) out.add(target);
      }
    } else if(p.type=='N') {
      for(final d in [[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]])add(r+d[0],c+d[1]);
    } else {
      final dirs=<List<int>>[];
      if(['R','Q','K'].contains(p.type))dirs.addAll([[1,0],[-1,0],[0,1],[0,-1]]);
      if(['B','Q','K'].contains(p.type))dirs.addAll([[1,1],[1,-1],[-1,1],[-1,-1]]);
      if(p.type=='K') {
        for(final d in dirs) add(r+d[0],c+d[1]);
        final home = p.side == ChessSide.white ? 60 : 4;
        final kingMoved = p.side == ChessSide.white ? _whiteKingMoved : _blackKingMoved;
        final leftRookMoved = p.side == ChessSide.white ? _whiteRookLeftMoved : _blackRookLeftMoved;
        final rightRookMoved = p.side == ChessSide.white ? _whiteRookRightMoved : _blackRookRightMoved;
        final enemy = p.side == ChessSide.white ? ChessSide.black : ChessSide.white;
        if (at == home && !kingMoved && !_isInCheck(p.side)) {
          final rightRook = board[home + 3];
          if (!rightRookMoved && rightRook?.side == p.side && rightRook?.type == 'R' && board[home + 1] == null && board[home + 2] == null && !_isSquareAttacked(home + 1, enemy) && !_isSquareAttacked(home + 2, enemy)) out.add(home + 2);
          final leftRook = board[home - 4];
          if (!leftRookMoved && leftRook?.side == p.side && leftRook?.type == 'R' && board[home - 1] == null && board[home - 2] == null && board[home - 3] == null && !_isSquareAttacked(home - 1, enemy) && !_isSquareAttacked(home - 2, enemy)) out.add(home - 2);
        }
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
      final epCapture = fromPiece?.type == 'P' && to == _enPassantTarget && toPiece == null && (at % 8 != to % 8);
      final epIndex = to + (p.side == ChessSide.white ? 8 : -8);
      final epPiece = epCapture ? board[epIndex] : null;
      final castle = fromPiece?.type == 'K' && (to - at).abs() == 2;
      final rookFrom = castle ? (to > at ? at + 3 : at - 4) : -1;
      final rookTo = castle ? (to > at ? at + 1 : at - 1) : -1;
      final rookPiece = castle ? board[rookFrom] : null;
      board[to] = fromPiece;
      board[at] = null;
      if (epCapture) board[epIndex] = null;
      if (castle) { board[rookTo] = rookPiece; board[rookFrom] = null; }
      final remainsSafe = !_isInCheck(p.side);
      board[at] = fromPiece;
      board[to] = toPiece;
      if (epCapture) board[epIndex] = epPiece;
      if (castle) { board[rookFrom] = rookPiece; board[rookTo] = null; }
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
    if (moves.contains(i)) {
      final from = selected!;
      final piece = board[from];
      final captured = board[i];
      final wasEnPassant = piece?.type == 'P' && i == _enPassantTarget && captured == null && from % 8 != i % 8;
      final enPassantCaptureSquare = i + (piece?.side == ChessSide.white ? 8 : -8);
      final wasCastle = piece?.type == 'K' && (i - from).abs() == 2;
      setState(() {
        board[i] = piece;
        board[from] = null;
        if (wasEnPassant) board[enPassantCaptureSquare] = null;
        if (wasCastle) {
          final rookFrom = i > from ? from + 3 : from - 4;
          final rookTo = i > from ? from + 1 : from - 1;
          board[rookTo] = board[rookFrom];
          board[rookFrom] = null;
        }
        if (piece?.type == 'K') {
          if (piece!.side == ChessSide.white) { _whiteKingMoved = true; } else { _blackKingMoved = true; }
        }
        if (piece?.type == 'R') {
          if (from == 56) _whiteRookLeftMoved = true;
          if (from == 63) _whiteRookRightMoved = true;
          if (from == 0) _blackRookLeftMoved = true;
          if (from == 7) _blackRookRightMoved = true;
        }
        if (captured?.type == 'R') {
          if (i == 56) _whiteRookLeftMoved = true;
          if (i == 63) _whiteRookRightMoved = true;
          if (i == 0) _blackRookLeftMoved = true;
          if (i == 7) _blackRookRightMoved = true;
        }
        _enPassantTarget = piece?.type == 'P' && (i - from).abs() == 16 ? (i + from) ~/ 2 : null;
        if (piece?.type == 'P' && (i ~/ 8 == 0 || i ~/ 8 == 7)) board[i] = ChessPiece(piece!.side, 'Q');
        selected = null;
        moves = {};
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
    Padding(padding:const EdgeInsets.all(12),child:GameTopBar(title:'Chess',subtitle:status)),
    Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:GridView.builder(physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),itemCount:64,itemBuilder:(ctx,i){
      final p=board[i]; final light=((i~/8)+(i%8)).isEven;
      return GestureDetector(onTap:()=>_tap(i),child:Container(color:selected==i?const Color(0xFFB6D7A8):moves.contains(i)?const Color(0xFF91B9D7):light?const Color(0xFFEADFC9):const Color(0xFF72856A),child:Center(child:Text(p?.glyph??(moves.contains(i)?'•':''),style:TextStyle(fontSize:32,color:p?.side==ChessSide.white?Colors.white:const Color(0xFF1D2430),shadows:p?.side==ChessSide.white?[const Shadow(color:Colors.black54,blurRadius:2)]:null)))));
    })))),
    Padding(padding:const EdgeInsets.all(12),child:OutlinedButton(onPressed:()=>setState(_reset),child:const Text('Reset board'))),
  ])));
}
