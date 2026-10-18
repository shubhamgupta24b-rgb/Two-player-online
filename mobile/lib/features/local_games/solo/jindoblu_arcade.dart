import 'dart:math';
import 'package:flutter/material.dart';
import '../shell/local_game_info.dart';
import '../shell/ticking_play.dart';
import 'solo_common.dart';

/// Nine original, self-contained arcade mini-games inspired by candidate titles
/// found in the reference APK. These do not reuse the reference game's assets.
enum ArcadeMode { fishing, fireworks, knifeHit, flappyDunk, hungryHippos, hotPotato, findIt, soccerStars, ringToss }

class ArcadeLogic extends SoloLogic {
  final ArcadeMode mode;
  final Random rng;
  static const durationMs = 30000;
  int target = 0;
  int cursor = 0;
  int misses = 0;
  int taps = 0;
  int level = 1;
  int _lastTick = -1;
  int _nextTarget = 0;
  double meter = 0;
  bool rising = true;
  final Set<int> occupied = {};
  ArcadeLogic(this.mode, {Random? random}) : rng = random ?? Random() {
    target = rng.nextInt(9);
  }
  int get left => max(0, durationMs - now);
  bool get precise => meter >= .40 && meter <= .60;

  @override
  void step(int elapsed) {
    if (elapsed >= durationMs) {
      gameOver();
      return;
    }
    final tick = elapsed ~/ 80;
    if (tick == _lastTick) return;
    _lastTick = tick;
    if (rising) {
      meter += .035 + level * .001;
      if (meter >= 1) { meter = 1; rising = false; }
    } else {
      meter -= .035 + level * .001;
      if (meter <= 0) { meter = 0; rising = true; }
    }
    if (elapsed >= _nextTarget) {
      if (mode == ArcadeMode.fishing || mode == ArcadeMode.hungryHippos ||
          mode == ArcadeMode.findIt || mode == ArcadeMode.soccerStars) {
        target = rng.nextInt(9);
      }
      _nextTarget = elapsed + max(450, 1500 - level * 90);
    }
    notifyListeners();
  }

  void hit(int cell) {
    if (over || cell < 0 || cell >= 9) return;
    taps++;
    switch (mode) {
      case ArcadeMode.fishing:
        if (cell == target) { score += 2; level++; target = rng.nextInt(9); }
        else { misses++; score = max(0, score - 1); }
      case ArcadeMode.fireworks:
        if (!occupied.add(cell)) { misses++; score = max(0, score - 1); }
        else { score++; if (occupied.length == 9) { score += 5; occupied.clear(); level++; } }
      case ArcadeMode.knifeHit:
        if (!occupied.add(cell)) { misses++; score = max(0, score - 2); }
        else { score += 2; if (occupied.length == 9) { score += 10; occupied.clear(); level++; } }
      case ArcadeMode.flappyDunk:
        final lane = (meter * 3).floor().clamp(0, 2);
        if (cell % 3 == lane) { score += 3; level++; }
        else { misses++; }
      case ArcadeMode.hungryHippos:
        if (cell == target) { score += 2; level++; target = rng.nextInt(9); }
        else { misses++; }
      case ArcadeMode.hotPotato:
        if (cell == cursor) { score += 2; cursor = (cursor + 1 + rng.nextInt(3)) % 9; level++; }
        else { misses++; score = max(0, score - 1); }
      case ArcadeMode.findIt:
        if (cell == target) { score += 3; level++; target = rng.nextInt(9); }
        else { misses++; score = max(0, score - 1); }
      case ArcadeMode.soccerStars:
        if (cell == target) { score += 2; level++; target = rng.nextInt(9); }
        else { misses++; }
      case ArcadeMode.ringToss:
        if (cell == (meter * 9).floor().clamp(0, 8)) { score += 3; level++; }
        else { misses++; }
    }
    notifyListeners();
  }

  void action() {
    if (over) return;
    final cell = switch (mode) {
      ArcadeMode.flappyDunk => 4,
      ArcadeMode.ringToss => (meter * 9).floor().clamp(0, 8),
      _ => (meter * 9).floor().clamp(0, 8),
    };
    hit(cell);
  }
}

const _names = <ArcadeMode, String>{
  ArcadeMode.fishing: 'Fishing Frenzy',
  ArcadeMode.fireworks: 'Fireworks',
  ArcadeMode.knifeHit: 'Knife Hit',
  ArcadeMode.flappyDunk: 'Flappy Dunk',
  ArcadeMode.hungryHippos: 'Hungry Hippos',
  ArcadeMode.hotPotato: 'Hot Potato',
  ArcadeMode.findIt: 'Find It',
  ArcadeMode.soccerStars: 'Soccer Stars',
  ArcadeMode.ringToss: 'Ring Toss',
};
const _symbols = <ArcadeMode, String>{
  ArcadeMode.fishing: '🐟',
  ArcadeMode.fireworks: '🎆',
  ArcadeMode.knifeHit: '🎯',
  ArcadeMode.flappyDunk: '🏀',
  ArcadeMode.hungryHippos: '🦛',
  ArcadeMode.hotPotato: '🥔',
  ArcadeMode.findIt: '🔍',
  ArcadeMode.soccerStars: '⚽',
  ArcadeMode.ringToss: '⭕',
};
const _hints = <ArcadeMode, String>{
  ArcadeMode.fishing: 'Tap the fish before it swims away',
  ArcadeMode.fireworks: 'Light all nine launch pads without repeats',
  ArcadeMode.knifeHit: 'Hit each target once; duplicates cost points',
  ArcadeMode.flappyDunk: 'Tap a cell in the highlighted moving lane',
  ArcadeMode.hungryHippos: 'Feed the hungry hippo at its new location',
  ArcadeMode.hotPotato: 'Pass the potato to the glowing player',
  ArcadeMode.findIt: 'Find the hidden star as quickly as possible',
  ArcadeMode.soccerStars: 'Kick the ball into the highlighted goal',
  ArcadeMode.ringToss: 'Time the moving indicator to hit its peg',
};

LocalGameInfo arcadeInfo(ArcadeMode mode) => LocalGameInfo(
  id: 'j_${mode.name}',
  title: _names[mode]!,
  emoji: _symbols[mode]!,
  color: const Color(0xFFB56E3D),
  tagline: _hints[mode]!,
  rules: [_hints[mode]!, 'Score as many points as possible in 30 seconds.', 'Wrong or repeated taps may cost points.'],
  scoreUnit: 'points',
  splitScreen: false,
  minPlayers: 1,
  maxPlayers: 1,
  play: (players, onFinished) => TickingPlay<ArcadeLogic>(
    create: () => ArcadeLogic(mode),
    onFinished: onFinished,
    builder: (context, g) => SoloFrame(
      title: _names[mode]!.toUpperCase(),
      score: g.score,
      extra: '${(g.left / 1000).ceil()}s  ·  ROUND ${g.level}  ·  MISSES ${g.misses}',
      child: Column(children: [
        const SizedBox(height: 12),
        Text(_hints[mode]!, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Expanded(child: Center(child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 9, crossAxisSpacing: 9),
              itemBuilder: (context, i) {
                final active = switch (mode) {
                  ArcadeMode.fishing || ArcadeMode.hungryHippos ||
                  ArcadeMode.findIt || ArcadeMode.soccerStars => i == g.target,
                  ArcadeMode.hotPotato => i == g.cursor,
                  ArcadeMode.flappyDunk => i % 3 == (g.meter * 3).floor().clamp(0, 2),
                  ArcadeMode.ringToss => i == (g.meter * 9).floor().clamp(0, 8),
                  _ => !g.occupied.contains(i),
                };
                final icon = switch (mode) {
                  ArcadeMode.fishing => active ? '🐟' : '🌊',
                  ArcadeMode.fireworks => g.occupied.contains(i) ? '✨' : '🚀',
                  ArcadeMode.knifeHit => g.occupied.contains(i) ? '🔪' : '🎯',
                  ArcadeMode.flappyDunk => active ? '🏀' : '🏁',
                  ArcadeMode.hungryHippos => active ? '🦛' : '🌿',
                  ArcadeMode.hotPotato => active ? '🥔' : '🙌',
                  ArcadeMode.findIt => active ? '⭐' : '❔',
                  ArcadeMode.soccerStars => active ? '🥅' : '⚽',
                  ArcadeMode.ringToss => active ? '⭕' : '📍',
                };
                return Material(
                  color: active ? const Color(0xFFF5D9A6) : const Color(0xFF48564C),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => g.hit(i),
                    child: Center(child: Text(icon, style: const TextStyle(fontSize: 36))),
                  ),
                );
              },
            ),
          ),
        ))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LinearProgressIndicator(
            value: g.meter, minHeight: 9,
            backgroundColor: const Color(0xFF6B6B6B),
            color: const Color(0xFFE5B56C),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    ),
  ),
);

final fishingArcadeInfo = arcadeInfo(ArcadeMode.fishing);
final fireworksArcadeInfo = arcadeInfo(ArcadeMode.fireworks);
final knifeHitArcadeInfo = arcadeInfo(ArcadeMode.knifeHit);
final flappyDunkArcadeInfo = arcadeInfo(ArcadeMode.flappyDunk);
final hungryHipposArcadeInfo = arcadeInfo(ArcadeMode.hungryHippos);
final hotPotatoArcadeInfo = arcadeInfo(ArcadeMode.hotPotato);
final findItArcadeInfo = arcadeInfo(ArcadeMode.findIt);
final soccerStarsArcadeInfo = arcadeInfo(ArcadeMode.soccerStars);
final ringTossArcadeInfo = arcadeInfo(ArcadeMode.ringToss);
