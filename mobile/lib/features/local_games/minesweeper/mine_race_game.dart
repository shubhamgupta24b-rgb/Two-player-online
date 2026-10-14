import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/game_hud.dart';
import '../shell/ticking_play.dart';
import '../solo/minesweeper.dart';

/// Same minefield for both players. The host keeps the mine positions and only
/// publishes opened numbers. The first correct clear wins. A mine is a loss for
/// that player; the other can still finish.
class MineRaceLogic extends LocalGameLogic {
  final int players;
  final int tier;
  final List<MinesweeperLogic> boards;
  late List<List<int>> shown;
  final List<int> status; // 0 playing, 1 clear, 2 mine
  final List<int?> doneAt;
  int? winner;
  int now = 0;
  static const countdown = 3000;

  MineRaceLogic({this.players = 2, this.tier = 1, int? seed})
      : boards = _boards(players, tier, seed ?? Random().nextInt(1 << 30)),
        status = List.filled(players, 0),
        doneAt = List.filled(players, null) {
    final n = boards.first.side * boards.first.side;
    shown = [for (var i = 0; i < players; i++) List.filled(n, -1)];
  }

  static List<MinesweeperLogic> _boards(int players, int tier, int seed) => [
        for (var i = 0; i < players; i++)
          MinesweeperLogic(random: Random(seed))
            ..applyTier(tier)
            ..placeFromSeed(),
      ];

  int get side => boards.first.side;
  bool get live => now >= countdown && winner == null;
  @override
  bool get finished =>
      winner != null || (status.every((s) => s != 0) && now >= countdown);
  @override
  List<int> get scores =>
      [for (var i = 0; i < players; i++) winner == i ? 1 : 0];

  void open(int player, int cell) {
    if (forward('open', [player, cell])) return;
    if (isGuest) return;
    if (!live || player < 0 || player >= players || status[player] != 0) return;
    final b = boards[player];
    if (cell < 0 || cell >= side * side || b.open.contains(cell)) return;
    if (b.mines.contains(cell)) {
      status[player] = 2;
      doneAt[player] = now;
      shown[player][cell] = 9;
      notifyListeners();
      return;
    }
    final todo = [cell];
    while (todo.isNotEmpty) {
      final k = todo.removeLast();
      if (!b.open.add(k)) continue;
      shown[player][k] = b.count(k);
      if (b.count(k) == 0) {
        todo.addAll(b
            .neighbours(k)
            .where((x) => !b.open.contains(x) && !b.mines.contains(x)));
      }
    }
    if (b.open.length == side * side - b.mines.length) {
      status[player] = 1;
      doneAt[player] = now;
      if (winner == null) winner = player;
    }
    notifyListeners();
  }

  @override
  void update(int ms) {
    if (isGuest) return;
    now = ms;
    if (live && status.every((s) => s != 0) && winner == null) {
      final clear = [
        for (var i = 0; i < players; i++)
          if (status[i] == 1) i
      ];
      if (clear.isNotEmpty) {
        clear.sort((a, b) => (doneAt[a] ?? now).compareTo(doneAt[b] ?? now));
        winner = clear.first;
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> toMap() => {
        'tier': tier,
        'shown': shown,
        'status': status,
        'done': doneAt,
        'winner': winner,
        'now': now,
      };

  void fromMap(Map<String, dynamic> s, {bool hideMines = false}) {
    final raw = s['shown'] as List;
    shown = [for (final row in raw) ints(row)];
    status.setAll(0, ints(s['status']));
    final done = s['done'] as List;
    for (var i = 0; i < done.length && i < doneAt.length; i++) {
      doneAt[i] = (done[i] as num?)?.toInt();
    }
    winner = nInt(s['winner']);
    now = asInt(s['now']);
    if (hideMines || isGuest) {
      for (final b in boards) {
        b.mines.clear();
      }
    }
  }
}

final mineRaceInfo = LocalGameInfo(
  id: 'minesweeper_race',
  title: 'Minesweeper Race',
  emoji: '💣',
  color: const Color(0xFF546E7A),
  tagline: 'Same field. First clear board wins.',
  rules: const [
    'Both players get the same minefield. A countdown starts you together.',
    'Open every safe cell. The first player to clear the board wins.',
    'Hitting a mine knocks you out. Mine positions are not sent to the other phone.',
  ],
  scoreUnit: 'wins',
  splitScreen: false,
  minPlayers: 2,
  maxPlayers: 2,
  bot: botFor<MineRaceLogic>((g, b, now) {
    if (!g.live || g.status[b.seat] != 0) return;
    if (!b.thinkFirst(
        g.shown[b.seat].where((n) => n >= 0).length, now, 200, 500)) return;
    final hidden = [
      for (var i = 0; i < g.shown[b.seat].length; i++)
        if (g.shown[b.seat][i] < 0) i
    ];
    if (hidden.isEmpty) return;
    g.open(b.seat, b.pick(hidden));
  }),
  online: RelaySpec<MineRaceLogic>(
    create: (n) => MineRaceLogic(players: n),
    save: (g) => g.toMap(),
    load: (g, s, me) => g.fromMap(s, hideMines: me >= 0),
    apply: (g, from, name, a) {
      if (name == 'open' && a.length >= 2 && asInt(a[0]) == from)
        g.open(from, asInt(a[1]));
    },
    view: (context, g, players, me) =>
        _RaceView(g: g, players: players, me: me),
  ),
  play: (players, onFinished) => TickingPlay<MineRaceLogic>(
    create: () => MineRaceLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => _RaceView(g: g, players: players, me: -1),
  ),
);

class _RaceView extends StatelessWidget {
  final MineRaceLogic g;
  final List<GpPlayer> players;
  final int me;
  const _RaceView({required this.g, required this.players, required this.me});

  @override
  Widget build(BuildContext context) {
    final seats = me < 0 ? [for (var i = 0; i < g.players; i++) i] : [me];
    final go = g.now < MineRaceLogic.countdown;
    return Column(children: [
      GameHud(
        players: players,
        scores: [
          for (var i = 0; i < g.players; i++)
            g.shown[i].where((n) => n >= 0 && n < 9).length
        ],
        trailing: Text(
            go
                ? '${((MineRaceLogic.countdown - g.now) / 1000).ceil()}'
                : seats.map((s) => _label(g.status[s])).join(' · '),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      for (final seat in seats)
        Expanded(
            child: _Grid(
                g: g, player: seat, enabled: g.live && g.status[seat] == 0)),
    ]);
  }

  String _label(int s) =>
      switch (s) { 1 => 'Clear', 2 => 'Mine', _ => 'Digging' };
}

class _Grid extends StatelessWidget {
  final MineRaceLogic g;
  final int player;
  final bool enabled;
  const _Grid({required this.g, required this.player, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: g.side,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < g.shown[player].length; i++)
          GestureDetector(
            onTap: enabled ? () => g.open(player, i) : null,
            child: Container(
              margin: const EdgeInsets.all(1),
              color: g.shown[player][i] == 9
                  ? const Color(0xFFE53935)
                  : (g.shown[player][i] < 0
                      ? const Color(0xFF37474F)
                      : const Color(0xFFCFD8DC)),
              alignment: Alignment.center,
              child: Text(
                  g.shown[player][i] > 0 && g.shown[player][i] < 9
                      ? '${g.shown[player][i]}'
                      : '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFF1C1A17))),
            ),
          ),
      ],
    );
  }
}
