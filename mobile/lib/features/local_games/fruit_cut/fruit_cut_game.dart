import 'dart:math';
import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import '../shell/local_game_info.dart';
import '../shell/local_game_logic.dart';
import '../shell/ticking_play.dart';
import '../shell/split_screen.dart';

class FruitCutLogic extends TimedDuel {
  static const fruitEmojis = ['🍉', '🍎', '🍊', '🍍', '🍇', '🍌', '🍓', '🥝'];
  final Random _random;
  final List<int> score;
  final List<int> cuts;
  final List<int> lastCutAt;
  int fruitIndex = 0;
  int fruitSerial = 0;
  int _lastSpawnMs = 0;
  FruitCutLogic({int players = 2, int durationMs = 30000, Random? random})
      : _random = random ?? Random(),
        score = List.filled(players, 0),
        cuts = List.filled(players, 0),
        lastCutAt = List.filled(players, -1),
        super(durationMs) {
    fruitIndex = _random.nextInt(fruitEmojis.length);
  }

  @override
  List<int> get scores => score;

  String get fruit => fruitEmojis[fruitIndex];

  @override
  void onUpdate() {
    final interval = max(450, 1050 - elapsedMs ~/ 45);
    if (elapsedMs - _lastSpawnMs >= interval) {
      _lastSpawnMs = elapsedMs;
      fruitIndex = _random.nextInt(fruitEmojis.length);
      fruitSerial++;
    }
  }

  bool cut(int player) {
    if (finished || player < 0 || player >= score.length || lastCutAt[player] == fruitSerial) return false;
    lastCutAt[player] = fruitSerial;
    score[player] += 1;
    cuts[player] += 1;
    notifyListeners();
    return true;
  }
}

final LocalGameInfo fruitCutInfo = LocalGameInfo(
  id: 'fruit_cut',
  title: 'Fruit Cut',
  emoji: '🍉',
  color: const Color(0xFF26A269),
  tagline: 'Swipe to slice fruit. Beat the timer.',
  rules: const [
    'Swipe across the fruit to score a cut.',
    'Each player can score once per fruit. New fruit appears faster as the timer runs down.',
    'Play for 30 seconds. Highest score wins.',
  ],
  scoreUnit: 'cuts',
  splitScreen: true,
  minPlayers: 2,
  maxPlayers: 2,
  play: (players, onFinished) => TickingPlay<FruitCutLogic>(
    create: () => FruitCutLogic(players: players.length),
    onFinished: onFinished,
    builder: (context, g) => PlayerZones(
      count: players.length,
      middle: DuelMiddleBar(players: players, scores: g.scores, secondsLeft: g.secondsLeft, progress: g.progress),
      center: ZoneCenterChip('${g.secondsLeft}s'),
      zone: (i) => _FruitCutZone(player: players[i], index: i, g: g),
    ),
  ),
);

class _FruitCutZone extends StatefulWidget {
  final GpPlayer player;
  final int index;
  final FruitCutLogic g;
  const _FruitCutZone({required this.player, required this.index, required this.g});
  @override
  State<_FruitCutZone> createState() => _FruitCutZoneState();
}

class _FruitCutZoneState extends State<_FruitCutZone> {
  bool _flash = false;
  void _slice() {
    if (widget.g.cut(widget.index)) {
      setState(() => _flash = true);
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _flash = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _slice(),
      onPanUpdate: (_) => _slice(),
      onTap: _slice,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _flash ? const Color(0xFFB8F2C8) : const Color(0xFFF7F3E9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFDED7C8), width: 2),
        ),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: Text(widget.player.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF243047)))),
              Text('${g.score[widget.index]}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF243047))),
            ]),
            const Spacer(),
            const Text('SWIPE TO CUT', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w900, color: Color(0xFF687386))),
            const SizedBox(height: 12),
            Expanded(child: Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 130),
              child: Text(g.fruit, key: ValueKey(g.fruitSerial), style: const TextStyle(fontSize: 78)),
            ))),
            Text('${g.cuts[widget.index]} cuts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF687386))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
