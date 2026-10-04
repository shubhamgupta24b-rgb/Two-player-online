import 'dart:math';
import '../shell/local_game_logic.dart';

enum Weapon { none, rocket, mine, boost }

const weaponEmoji = {Weapon.none: '', Weapon.rocket: '🚀', Weapon.mine: '💣', Weapon.boost: '⚡'};

class Kart {
  double x, y, angle; // angle in radians, 0 = facing right
  double speed = 0;
  double stickAngle = 0, stickPower = 0; // what the driver is asking for
  Weapon weapon = Weapon.none;
  int stunnedUntil = 0, shieldUntil = 0, boostUntil = 0;
  Kart(this.x, this.y, this.angle);
}

class Rocket {
  double x, y;
  final double angle;
  final int owner, bornMs;
  Rocket(this.x, this.y, this.angle, this.owner, this.bornMs);
}

class Mine {
  final double x, y;
  final int owner, bornMs;
  Mine(this.x, this.y, this.owner, this.bornMs);
}

/// A spot where mystery boxes appear; [readyAt] is when its box is back after being taken.
class BoxSpot {
  final double x, y;
  int readyAt = 0;
  BoxSpot(this.x, this.y);
}

/// Smash Karts: a top-down battle arena, 1 wide and [height] tall. Drive with a stick, pick
/// up mystery boxes (rocket, mine or boost) and hit other karts: every hit is a point. A hit
/// kart spins out for a moment and is then shielded. Most hits when the time runs out wins.
class SmashKartsLogic extends TimedDuel {
  static const height = 1.5;
  static const kartR = 0.035;
  static const maxSpeed = 0.42;
  static const boostFactor = 1.75;
  static const turnRate = 4.2; // radians a second
  static const rocketSpeed = 1.15, rocketLife = 1600;
  static const mineArmMs = 600, mineLife = 25000;
  static const stunMs = 1300, shieldMs = 2800, boostMs = 1800, boxRespawnMs = 5000;
  static const _dt = 1 / 60;

  /// Crates in the arena (left, top, right, bottom).
  static const obstacles = [
    (0.42, 0.68, 0.58, 0.82), // centre
    (0.14, 0.32, 0.30, 0.40),
    (0.70, 0.32, 0.86, 0.40),
    (0.14, 1.10, 0.30, 1.18),
    (0.70, 1.10, 0.86, 1.18),
  ];

  final Random rng;
  final List<Kart> karts;
  final List<int> hits;
  final List<Rocket> rockets = [];
  final List<Mine> mines = [];
  final List<BoxSpot> boxes = [BoxSpot(0.5, 0.2), BoxSpot(0.5, 1.3), BoxSpot(0.1, 0.75), BoxSpot(0.9, 0.75), BoxSpot(0.5, 0.52), BoxSpot(0.5, 0.98)];
  final List<(double x, double y, int ms)> blasts = []; // explosions, for effects
  final List<String?> lastEvent; // per player: what just happened to them ("+1!", "HIT!")
  double _acc = 0;
  int _last = 0;

  SmashKartsLogic({int players = 2, int durationMs = 120000, Random? random})
      : rng = random ?? Random(),
        karts = [for (var i = 0; i < players; i++) _start(i, players)],
        hits = List.filled(players, 0),
        lastEvent = List.filled(players, null),
        super(durationMs);

  /// Start positions round the edge, facing the middle.
  static Kart _start(int i, int n) {
    const spots = [(0.5, 1.38), (0.5, 0.12), (0.12, 0.75), (0.88, 0.75), (0.15, 1.38), (0.85, 0.12)];
    final (x, y) = spots[i % spots.length];
    return Kart(x, y, atan2(0.75 - y, 0.5 - x));
  }

  @override
  List<int> get scores => hits;

  bool stunned(int p) => elapsedMs < karts[p].stunnedUntil;
  bool shielded(int p) => elapsedMs < karts[p].shieldUntil;
  bool boosted(int p) => elapsedMs < karts[p].boostUntil;
  bool boxReady(BoxSpot b) => elapsedMs >= b.readyAt;

  // ---- player actions ----

  /// Driving stick: [angle] to head towards, [power] 0..1 how hard to drive.
  void steer(int p, double angle, double power) {
    if (forward('steer', [p, angle, power])) return;
    if (p < 0 || p >= karts.length) return;
    karts[p]
      ..stickAngle = angle
      ..stickPower = power.clamp(0.0, 1.0);
  }

  /// Uses the weapon you carry.
  void fire(int p) {
    if (forward('fire', [p])) return;
    if (finished || p < 0 || p >= karts.length || stunned(p)) return;
    final k = karts[p];
    switch (k.weapon) {
      case Weapon.rocket:
        rockets.add(Rocket(k.x + cos(k.angle) * kartR * 1.6, k.y + sin(k.angle) * kartR * 1.6, k.angle, p, elapsedMs));
      case Weapon.mine:
        mines.add(Mine(k.x - cos(k.angle) * kartR * 1.8, k.y - sin(k.angle) * kartR * 1.8, p, elapsedMs));
      case Weapon.boost:
        k.boostUntil = elapsedMs + boostMs;
      case Weapon.none:
        return;
    }
    k.weapon = Weapon.none;
    notifyListeners();
  }

  // ---- world ----

  @override
  void onUpdate() {
    _acc += ((elapsedMs - _last) / 1000).clamp(0.0, 0.1);
    _last = elapsedMs;
    var steps = 0;
    while (_acc >= _dt && steps < 8) {
      _step();
      _acc -= _dt;
      steps++;
    }
    blasts.removeWhere((b) => elapsedMs - b.$3 > 700);
  }

  void _step() {
    for (var i = 0; i < karts.length; i++) {
      _drive(i);
    }
    _bumpKarts();
    _moveRockets();
    _checkMines();
    _pickUps();
  }

  void _drive(int i) {
    final k = karts[i];
    if (stunned(i)) {
      k.angle += 12 * _dt; // spinning out
      k.speed *= 0.9;
    } else if (k.stickPower > 0.05) {
      // Turn towards the stick, the shortest way round.
      var d = (k.stickAngle - k.angle) % (2 * pi);
      if (d > pi) d -= 2 * pi;
      k.angle += d.clamp(-turnRate * _dt, turnRate * _dt);
      final top = maxSpeed * k.stickPower * (boosted(i) ? boostFactor : 1);
      k.speed += (top - k.speed) * 0.08;
    } else {
      k.speed *= 0.92;
    }
    k.x += cos(k.angle) * k.speed * _dt;
    k.y += sin(k.angle) * k.speed * _dt;
    // Walls.
    if (k.x < kartR || k.x > 1 - kartR || k.y < kartR || k.y > height - kartR) {
      k.x = k.x.clamp(kartR, 1 - kartR);
      k.y = k.y.clamp(kartR, height - kartR);
      k.speed *= 0.4;
    }
    // Crates: push the kart out of the nearest side.
    for (final (l, t, r, b) in obstacles) {
      final cx = k.x.clamp(l, r), cy = k.y.clamp(t, b);
      final dx = k.x - cx, dy = k.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 >= kartR * kartR) continue;
      if (d2 > 1e-12) {
        final d = sqrt(d2);
        k.x = cx + dx / d * kartR;
        k.y = cy + dy / d * kartR;
      } else {
        // Inside the crate: out through the closest edge.
        final out = [k.x - l, r - k.x, k.y - t, b - k.y];
        final m = out.indexOf(out.reduce(min));
        if (m == 0) k.x = l - kartR;
        if (m == 1) k.x = r + kartR;
        if (m == 2) k.y = t - kartR;
        if (m == 3) k.y = b + kartR;
      }
      k.speed *= 0.5;
    }
  }

  void _bumpKarts() {
    for (var i = 0; i < karts.length; i++) {
      for (var j = i + 1; j < karts.length; j++) {
        final a = karts[i], b = karts[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final d = sqrt(dx * dx + dy * dy);
        if (d >= kartR * 2 || d < 1e-9) continue;
        final push = (kartR * 2 - d) / 2;
        a.x -= dx / d * push;
        a.y -= dy / d * push;
        b.x += dx / d * push;
        b.y += dy / d * push;
      }
    }
  }

  bool _inCrate(double x, double y) => obstacles.any((o) => x >= o.$1 && x <= o.$3 && y >= o.$2 && y <= o.$4);

  void _moveRockets() {
    final gone = <Rocket>[];
    for (final r in rockets) {
      r.x += cos(r.angle) * rocketSpeed * _dt;
      r.y += sin(r.angle) * rocketSpeed * _dt;
      if (elapsedMs - r.bornMs > rocketLife || r.x < 0 || r.x > 1 || r.y < 0 || r.y > height || _inCrate(r.x, r.y)) {
        gone.add(r);
        blasts.add((r.x.clamp(0.0, 1.0), r.y.clamp(0.0, height), elapsedMs));
        continue;
      }
      for (var i = 0; i < karts.length; i++) {
        if (i == r.owner) continue;
        final k = karts[i];
        if ((k.x - r.x) * (k.x - r.x) + (k.y - r.y) * (k.y - r.y) < kartR * kartR * 1.5) {
          gone.add(r);
          _hit(i, by: r.owner);
          break;
        }
      }
    }
    rockets.removeWhere(gone.contains);
  }

  void _checkMines() {
    final gone = <Mine>[];
    for (final m in mines) {
      if (elapsedMs - m.bornMs > mineLife) {
        gone.add(m);
        continue;
      }
      if (elapsedMs - m.bornMs < mineArmMs) continue;
      for (var i = 0; i < karts.length; i++) {
        final k = karts[i];
        if ((k.x - m.x) * (k.x - m.x) + (k.y - m.y) * (k.y - m.y) < kartR * kartR * 2) {
          gone.add(m);
          _hit(i, by: m.owner);
          break;
        }
      }
    }
    mines.removeWhere(gone.contains);
  }

  void _pickUps() {
    for (final b in boxes) {
      if (!boxReady(b)) continue;
      for (var i = 0; i < karts.length; i++) {
        final k = karts[i];
        if (k.weapon != Weapon.none || stunned(i)) continue;
        if ((k.x - b.x) * (k.x - b.x) + (k.y - b.y) * (k.y - b.y) < (kartR * 1.8) * (kartR * 1.8)) {
          k.weapon = const [Weapon.rocket, Weapon.rocket, Weapon.mine, Weapon.boost][rng.nextInt(4)];
          b.readyAt = elapsedMs + boxRespawnMs;
          break;
        }
      }
    }
  }

  /// [victim] is hit by [by]'s rocket or mine: a point to [by] (not for hitting yourself).
  void _hit(int victim, {required int by}) {
    final k = karts[victim];
    blasts.add((k.x, k.y, elapsedMs));
    if (shielded(victim) || stunned(victim)) return;
    k.stunnedUntil = elapsedMs + stunMs;
    k.shieldUntil = elapsedMs + stunMs + shieldMs;
    k.weapon = Weapon.none;
    lastEvent[victim] = 'HIT!';
    if (by != victim) {
      hits[by]++;
      lastEvent[by] = '+1 SMASH!';
    }
  }
}

/// The computer's driving: fetch a box, then hunt the nearest rival and shoot when lined up.
void smashKartsBot(SmashKartsLogic g, int me, Random rng, {required int nowMs, required Map<String, Object?> memory}) {
  final k = g.karts[me];
  if (g.stunned(me) || g.finished) return;
  double? targetX, targetY;
  // Nearest rival that isn't shielded.
  var best = double.infinity;
  int? rival;
  for (var i = 0; i < g.karts.length; i++) {
    if (i == me || g.shielded(i)) continue;
    final o = g.karts[i];
    final d = (o.x - k.x) * (o.x - k.x) + (o.y - k.y) * (o.y - k.y);
    if (d < best) {
      best = d;
      rival = i;
    }
  }
  switch (k.weapon) {
    case Weapon.none:
      var nearest = double.infinity;
      for (final b in g.boxes.where(g.boxReady)) {
        final d = (b.x - k.x) * (b.x - k.x) + (b.y - k.y) * (b.y - k.y);
        if (d < nearest) {
          nearest = d;
          targetX = b.x;
          targetY = b.y;
        }
      }
    case Weapon.boost:
      g.fire(me);
    case Weapon.rocket:
      if (rival != null) {
        final o = g.karts[rival];
        targetX = o.x;
        targetY = o.y;
        var d = (atan2(o.y - k.y, o.x - k.x) - k.angle) % (2 * pi);
        if (d > pi) d -= 2 * pi;
        // Lined up (with a shaky hand): fire.
        if (d.abs() < 0.18 && sqrt(best) < 0.7 && rng.nextDouble() < 0.08) g.fire(me);
      }
    case Weapon.mine:
      // Drop it on a busy spot after a little while.
      memory['mineAt'] ??= nowMs + 900 + rng.nextInt(1500);
      if (nowMs >= (memory['mineAt'] as int)) {
        memory.remove('mineAt');
        g.fire(me);
      }
  }
  // Stuck on a crate? Back off in some other direction for a moment.
  if (k.speed < 0.04 && k.stickPower > 0.5) {
    memory['stuckSince'] ??= nowMs;
    if (nowMs - (memory['stuckSince'] as int) > 700) {
      memory['unstickUntil'] = nowMs + 700;
      memory['wander'] = k.angle + pi + (rng.nextDouble() - 0.5) * 2;
      memory.remove('stuckSince');
    }
  } else {
    memory.remove('stuckSince');
  }
  if (memory['unstickUntil'] != null && nowMs < (memory['unstickUntil'] as int)) {
    g.steer(me, memory['wander'] as double, 1);
    return;
  }
  // Wander when there's nothing to chase; change direction now and then.
  if (targetX == null) {
    if (memory['wanderUntil'] == null || nowMs > (memory['wanderUntil'] as int)) {
      memory['wander'] = rng.nextDouble() * 2 * pi;
      memory['wanderUntil'] = nowMs + 1500;
    }
    g.steer(me, memory['wander'] as double, 0.7);
    return;
  }
  g.steer(me, atan2(targetY! - k.y, targetX - k.x), 1);
}
