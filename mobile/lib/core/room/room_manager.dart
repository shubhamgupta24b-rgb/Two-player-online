import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/socket_manager.dart';

class RoomPlayer {
  final String userId, username;
  final bool ready, connected;
  RoomPlayer(this.userId, this.username, this.ready, this.connected);
  factory RoomPlayer.fromJson(Map j) => RoomPlayer(j['userId'], j['username'] ?? '?', j['ready'] == true, j['connected'] == true);
}

class Room {
  final String code, gameType, hostId, status;
  final int maxPlayers;
  final List<RoomPlayer> players;
  Room(this.code, this.gameType, this.hostId, this.status, this.maxPlayers, this.players);
  factory Room.fromJson(Map j) => Room(
        j['code'], j['gameType'], j['hostId'], j['status'], j['maxPlayers'],
        (j['players'] as List).map((p) => RoomPlayer.fromJson(p as Map)).toList(),
      );
  bool get allReady => players.length >= 2 && players.every((p) => p.ready && p.connected);
}

const _errorText = {
  'ROOM_FULL': 'That room is full.',
  'ROOM_NOT_FOUND': 'Room not found. Check the code.',
  'ALREADY_IN_ROOM': 'You are already in a room.',
  'GAME_IN_PROGRESS': 'That game has already started.',
  'NOT_HOST': 'Only the host can do that.',
  'NOT_ENOUGH_PLAYERS': 'Need at least 2 players.',
  'PLAYERS_NOT_READY': 'Everyone must be ready.',
  'GAME_NOT_AVAILABLE': 'This game is not implemented yet.',
  'INVALID_PAYLOAD': 'Invalid input.',
  'OFFLINE': 'You are offline.',
  'TIMEOUT': 'Server did not respond.',
  'BAD_PHASE': 'Not possible right now.',
  'RATE_LIMITED': 'Too many requests, slow down.',
};
String errorMessage(String? code) => _errorText[code] ?? 'Something went wrong ($code).';

class RoomManager extends ChangeNotifier {
  final SocketManager _socket;
  late final StreamSubscription<SocketEvent> _sub;
  Room? room;
  String? notice; // transient server notices, e.g. SESSION_REPLACED

  RoomManager(this._socket) {
    _sub = _socket.events.listen(_onEvent);
    _socket.connected.addListener(() {
      if (_socket.connected.value) resync();
    });
  }

  void _onEvent(SocketEvent e) {
    if (e.name == 'room_state') {
      room = Room.fromJson(e.data as Map);
      notifyListeners();
    } else if (e.name == 'error' && e.data is Map) {
      notice = errorMessage((e.data as Map)['code']?.toString());
      notifyListeners();
    }
  }

  /// After every (re)connect ask the server what room we're in; null means the seat expired.
  Future<void> resync() async {
    final r = await _socket.request('resume_session');
    if (r['ok'] == true) {
      room = r['room'] == null ? null : Room.fromJson(r['room'] as Map);
      notifyListeners();
    }
  }

  Future<String?> _roomCall(String event, [Map<String, dynamic>? p]) async {
    final r = await _socket.request(event, p);
    if (r['ok'] != true) return errorMessage(r['error']?.toString());
    if (r['room'] != null) {
      room = Room.fromJson(r['room'] as Map);
      notifyListeners();
    }
    return null;
  }

  Future<String?> create(String gameType, int maxPlayers) => _roomCall('create_room', {'gameType': gameType, 'maxPlayers': maxPlayers});
  Future<String?> join(String code) => _roomCall('join_room', {'code': code.trim().toUpperCase()});
  Future<String?> setReady(bool ready) => _roomCall(ready ? 'player_ready' : 'player_unready');
  Future<String?> start() => _roomCall('start_game');
  Future<String?> returnToLobby() => _roomCall('return_to_lobby');

  Future<void> leave() async {
    await _socket.request('leave_room');
    room = null;
    notifyListeners();
  }

  void clearNotice() => notice = null;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
