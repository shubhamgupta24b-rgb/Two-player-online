import 'dart:math';
import '../shell/local_game_logic.dart';

enum Weapon { none, rocket, gun, mine, boost, shield, triple }

const weaponEmoji = {Weapon.none: '', Weapon.rocket: '🚀', Weapon.gun: '🔫', Weapon.mine: '💣', Weapon.boost: '⚡', Weapon.shield: '🛡️', Weapon.triple: '🎆'};
const weaponName = {Weapon.none: '', Weapon.rocket: 'ROCKET', Weapon.gun: 'MACHINE GUN', Weapon.mine: 'MINE', Weapon.boost: 'BOOST', Weapon.shield: 'SHIELD', Weapon.triple: 'TRIPLE ROCKET'};

class Kart {
  double x, y, angle; // angle in radians, 0 = facing right (+x), y grows downwards
  double speed = 0;
  double stickAngle = 0, stickPower = 0; // what the driver asks for
  Weapon weapon = Weapon.none;
  int hp = SmashKartsLogic.maxHp;
  int wreckedUntil = 0, shieldUntil = 0, boostUntil = 0;
  int gunShots = 0, nextGunAt = 0; // a machine-gun burst in progress
  Kart(this.x, this.y, this.angle);
}

/// A rocket or a machine-gun bullet.
class Shot {
  double x, y;
  final double angle;
  final int owner, bornMs;
  final bool bullet;
  Shot(this.x, this.y, this.angle, this.owner, this.bornMs, {this.bullet = false});
}

class Mine {
  final double x, y;
  final int owner, bornMs;
  Mine(this.x, this.y, this.owner, this.bornMs);
}

class BoxSpot {
  final double x, y;
  int readyAt = 0;
  BoxSpot(this.x, this.y);
}

/// Who wrecked whom, with what, and when (the kill feed).
class Kill {
  final int killer, victim, ms;
  final Weapon weapon;
  const Kill(this.killer, this.victim, this.weapon, this.ms);
}

/// The playground: "Sunset Park", a square arena ringed by kerbs, with crates, walls,
/// trees, boost pads and mystery boxes. Units: the arena is [size] wide and tall.
class KartMap {
  static const size = 2.4;
  /// Crates and walls (left, top, right, bottom).
  static const blocks = [
    (1.05, 1.05, 1.35, 1.35), // the centre stack
    (0.45, 0.42, 0.75, 0.52), // four walls round the middle
    (1.65, 0.42, 1.95, 0.52),
    (0.45, 1.88, 0.75, 1.98),
    (1.65, 1.88, 1.95, 1.98),
    (0.22, 0.86, 0.32, 0.98), // side crates, off the spawn lanes
    (2.08, 1.42, 2.18, 1.54),
    (1.40, 0.22, 1.52, 0.32),
    (0.88, 2.08, 1.00, 2.18),
  ];

  /// Trees (x, y, radius): solid, you drive round them.
  static const trees = [(0.68, 0.98, 0.07), (1.72, 0.98, 0.07), (0.68, 1.42, 0.07), (1.72, 1.42, 0.07)];

  /// Boost pads (x, y, angle they push you).
  static const pads = [(1.2, 0.72, 0.0), (1.2, 1.68, pi), (0.72, 1.2, -pi / 2), (1.68, 1.2, pi / 2)];
  static const padHalf = 0.07;

  static const boxSpots = [(0.3, 0.3), (2.1, 0.3), (0.3, 2.1), (2.1, 2.1), (1.2, 0.5), (1.2, 1.9), (0.5, 1.2), (1.9, 1.2)];
  static const spawns = [(1.2, 2.25), (1.2, 0.15), (0.15, 1.2), (2.25, 1.2), (0.25, 2.25), (2.15, 0.15)];
}

/// Smash Karts: drive, grab mystery boxes, and wreck the other karts. Karts have 3 HP: a rocket
/// or mine wrecks you, a bullet costs 1 HP. A wrecked kart respawns with a shield. Most
/// wrecks when the time runs out wins.
class SmashKartsLogic extends TimedDuel {
  static const size = KartMap.size;
  static const kartR = 0.045;
  static const maxHp = 3;
  static const maxSpeed = 0.62;
  static const boostFactor = 1.7;
  static const turnRate = 4.4;
  static const rocketSpeed = 1.5, rocketLife = 1800;
  static const bulletSpeed = 2.0, bulletLife = 650, burst = 6, burstGapMs = 90;
  static const mineArmMs = 600, mineLife = 30000;
  static const wreckMs = 1600, spawnShieldMs = 2200, shieldMs = 3500, boostMs = 1800, padBoostMs = 1100, boxRespawnMs = 5000;
  static const _dt = 1 / 60;

  final Random rng;
  final List<Kart> karts;
  final List<int> kills;
  final List<Shot> shots = [];
  final List<Mine> mines = [];
  final List<BoxSpot> boxes = [for (final (x, y) in KartMap.boxSpots) BoxSpot(x, y)];
  final List<(double x, double y, int ms, bool big)> blasts = []; // explosions, for effects
  final List<Kill> feed = [];
  final List<String?> lastEvent; // per player: what just happened ("+1 SMASH!", "WRECKED")
  final List<int> eventAt;
  double _acc = 0;
  int _last = 0;

  SmashKartsLogic({int players = 2, int durationMs = 120000, Random? random})
      : rng = random ?? Random(),
        karts = [for (var i = 0; i < players; i++) _start(i)],
        kills = List.filled(players, 0),
        lastEvent = List.filled(players, null),
        eventAt = List.filled(players, 0),
        super(durationMs);

  static Kart _start(int i) {
    final (x, y) = KartMap.spawns[i % KartMap.spawns.length];
    return Kart(x, y, atan2(size / 2 - y, size / 2 - x));
  }

  @override
  List<int> get scores => kills;

  bool wrecked(int p) => elapsedMs < karts[p].wreckedUntil;
  bool stunned(int p) => wrecked(p); // older name
  bool shielded(int p) => elapsedMs < karts[p].shieldUntil;
  bool boosted(int p) => elapsedMs < karts[p].boostUntil;
  bool boxReady(BoxSpot b) => elapsedMs >= b.readyAt;

  // ---- player actions ----

  /// Driving stick: [angle] to head towards, [power] 0..1 how hard.
  void steer(int p, double angle, double power) {
    if (forward('steer', [p, angle, power])) return;
    if (p < 0 || p >= karts.length) return;
    karts[p]
      ..stickAngle = angle
      ..stickPower = power.clamp(0.0, 1.0);
  }

  /// Uses the power-up you carry.
  void fire(int p) {
    if (forward('fire', [p])) return;
    if (finished || p < 0 || p >= karts.length || wrecked(p)) return;
    final k = karts[p];
    switch (k.weapon) {
      case Weapon.rocket:
        shots.add(Shot(k.x + cos(k.angle) * kartR * 1.6, k.y + sin(k.angle) * kartR * 1.6, k.angle, p, elapsedMs));
      case Weapon.triple:
        // Three rockets in a fan.
        for (final spread in const [-0.2, 0.0, 0.2]) {
          shots.add(Shot(k.x + cos(k.angle) * kartR * 1.6, k.y + sin(k.angle) * kartR * 1.6, k.angle + spread, p, elapsedMs));
        }
      case Weapon.gun:
        k
          ..gunShots = burst
          ..nextGunAt = elapsedMs;
      case Weapon.mine:
        mines.add(Mine(k.x - cos(k.angle) * kartR * 1.9, k.y - sin(k.angle) * kartR * 1.9, p, elapsedMs));
      case Weapon.boost:
        k.boostUntil = elapsedMs + boostMs;
      case Weapon.shield:
        k.shieldUntil = elapsedMs + shieldMs;
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
    blasts.removeWhere((b) => elapsedMs - b.$3 > 900);
    if (feed.length > 6) feed.removeRange(0, feed.length - 6);
  }

  void _step() {
    for (var i = 0; i < karts.length; i++) {
      _respawnIfDue(i);
      _drive(i);
      _shootBurst(i);
    }
    _bumpKarts();
    _moveShots();
    _checkMines();
    _pickUps();
  }

  void _respawnIfDue(int i) {
    final k = karts[i];
    if (k.wreckedUntil == 0 || elapsedMs < k.wreckedUntil) return;
    // Back in at the spawn point furthest from everyone else, shielded for a moment.
    var best = KartMap.spawns.first;
    var bestD = -1.0;
    for (final s in KartMap.spawns) {
      var d = double.infinity;
      for (var j = 0; j < karts.length; j++) {
        if (j == i) continue;
        d = min(d, (karts[j].x - s.$1) * (karts[j].x - s.$1) + (karts[j].y - s.$2) * (karts[j].y - s.$2));
      }
      if (d > bestD) {
        bestD = d;
        best = s;
      }
    }
    k
      ..x = best.$1
      ..y = best.$2
      ..angle = atan2(size / 2 - best.$2, size / 2 - best.$1)
      ..speed = 0
      ..hp = maxHp
      ..weapon = Weapon.none
      ..wreckedUntil = 0
      ..gunShots = 0
      ..shieldUntil = elapsedMs + spawnShieldMs;
  }

  void _drive(int i) {
    final k = karts[i];
    if (wrecked(i)) {
      k.speed *= 0.9;
      k.angle += 9 * _dt; // spinning wreck
    } else if (k.stickPower > 0.05) {
      var d = (k.stickAngle - k.angle) % (2 * pi);
      if (d > pi) d -= 2 * pi;
      k.angle += d.clamp(-turnRate * _dt, turnRate * _dt);
      final top = maxSpeed * k.stickPower * (boosted(i) ? boostFactor : 1);
      k.speed += (top - k.speed) * 0.07;
    } else {
      k.speed *= 0.93;
    }
    k.x += cos(k.angle) * k.speed * _dt;
    k.y += sin(k.angle) * k.speed * _dt;
    if (k.x < kartR || k.x > size - kartR || k.y < kartR || k.y > size - kartR) {
      k.x = k.x.clamp(kartR, size - kartR);
      k.y = k.y.clamp(kartR, size - kartR);
      k.speed *= 0.4;
    }
    for (final (l, t, r, b) in KartMap.blocks) {
      final cx = k.x.clamp(l, r), cy = k.y.clamp(t, b);
      final dx = k.x - cx, dy = k.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 >= kartR * kartR) continue;
      if (d2 > 1e-12) {
        final d = sqrt(d2);
        k.x = cx + dx / d * kartR;
        k.y = cy + dy / d * kartR;
      } else {
        final out = [k.x - l, r - k.x, k.y - t, b - k.y];
        final m = out.indexOf(out.reduce(min));
        if (m == 0) k.x = l - kartR;
        if (m == 1) k.x = r + kartR;
        if (m == 2) k.y = t - kartR;
        if (m == 3) k.y = b + kartR;
      }
      k.speed *= 0.5;
    }
    for (final (tx, ty, tr) in KartMap.trees) {
      final dx = k.x - tx, dy = k.y - ty, d = sqrt(dx * dx + dy * dy);
      if (d >= tr + kartR || d < 1e-9) continue;
      k.x = tx + dx / d * (tr + kartR);
      k.y = ty + dy / d * (tr + kartR);
      k.speed *= 0.5;
    }
    // Boost pads.
    if (!wrecked(i)) {
      for (final (px, py, _) in KartMap.pads) {
        if ((k.x - px).abs() < KartMap.padHalf && (k.y - py).abs() < KartMap.padHalf && !boosted(i)) {
          k.boostUntil = elapsedMs + padBoostMs;
        }
      }
    }
  }

  void _shootBurst(int i) {
    final k = karts[i];
    if (k.gunShots <= 0 || wrecked(i) || elapsedMs < k.nextGunAt) return;
    final spread = (rng.nextDouble() - 0.5) * 0.08;
    shots.add(Shot(k.x + cos(k.angle) * kartR * 1.5, k.y + sin(k.angle) * kartR * 1.5, k.angle + spread, i, elapsedMs, bullet: true));
    k.gunShots--;
    k.nextGunAt = elapsedMs + burstGapMs;
  }

  void _bumpKarts() {
    for (var i = 0; i < karts.length; i++) {
      for (var j = i + 1; j < karts.length; j++) {
        if (wrecked(i) || wrecked(j)) continue;
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

  bool _solid(double x, double y) =>
      KartMap.blocks.any((o) => x >= o.$1 && x <= o.$3 && y >= o.$2 && y <= o.$4) || KartMap.trees.any((t) => (x - t.$1) * (x - t.$1) + (y - t.$2) * (y - t.$2) < t.$3 * t.$3);

  void _moveShots() {
    final gone = <Shot>[];
    for (final s in shots) {
      final speed = s.bullet ? bulletSpeed : rocketSpeed, life = s.bullet ? bulletLife : rocketLife;
      s.x += cos(s.angle) * speed * _dt;
      s.y += sin(s.angle) * speed * _dt;
      if (elapsedMs - s.bornMs > life || s.x < 0 || s.x > size || s.y < 0 || s.y > size || _solid(s.x, s.y)) {
        gone.add(s);
        if (!s.bullet) blasts.add((s.x.clamp(0.0, size), s.y.clamp(0.0, size), elapsedMs, false));
        continue;
      }
      for (var i = 0; i < karts.length; i++) {
        if (i == s.owner || wrecked(i)) continue;
        final k = karts[i];
        if ((k.x - s.x) * (k.x - s.x) + (k.y - s.y) * (k.y - s.y) < kartR * kartR * 1.6) {
          gone.add(s);
          _damage(i, by: s.owner, amount: s.bullet ? 1 : maxHp, weapon: s.bullet ? Weapon.gun : Weapon.rocket);
          break;
        }
      }
    }
    shots.removeWhere(gone.contains);
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
        if (wrecked(i)) continue;
        final k = karts[i];
        if ((k.x - m.x) * (k.x - m.x) + (k.y - m.y) * (k.y - m.y) < kartR * kartR * 2) {
          gone.add(m);
          _damage(i, by: m.owner, amount: maxHp, weapon: Weapon.mine);
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
        if (k.weapon != Weapon.none || wrecked(i)) continue;
        if ((k.x - b.x) * (k.x - b.x) + (k.y - b.y) * (k.y - b.y) < (kartR * 1.9) * (kartR * 1.9)) {
          final r = rng.nextInt(100);
          k.weapon = r < 25 ? Weapon.rocket : r < 35 ? Weapon.triple : r < 57 ? Weapon.gun : r < 75 ? Weapon.mine : r < 90 ? Weapon.boost : Weapon.shield;
          b.readyAt = elapsedMs + boxRespawnMs;
          break;
        }
      }
    }
  }

  void _event(int p, String text) {
    lastEvent[p] = text;
    eventAt[p] = elapsedMs;
  }

  /// [victim] takes [amount] damage from [by]: at 0 HP they're wrecked and [by] scores.
  void _damage(int victim, {required int by, required int amount, required Weapon weapon}) {
    final k = karts[victim];
    blasts.add((k.x, k.y, elapsedMs, amount >= maxHp));
    if (shielded(victim) || wrecked(victim)) return;
    k.hp -= amount;
    if (k.hp > 0) {
      _event(victim, '-$amount HP');
      return;
    }
    k
      ..hp = 0
      ..wreckedUntil = elapsedMs + wreckMs
      ..weapon = Weapon.none
      ..gunShots = 0;
    blasts.add((k.x, k.y, elapsedMs, true));
    feed.add(Kill(by, victim, weapon, elapsedMs));
    _event(victim, 'WRECKED!');
    if (by != victim) {
      kills[by]++;
      _event(by, '+1 SMASH!');
    }
  }
}

/// The computer's driving: grab a box, hunt the nearest rival, fire when lined up,
/// shield up when hurt, and back away from walls when stuck.
void smashKartsBot(SmashKartsLogic g, int me, Random rng, {required int nowMs, required Map<String, Object?> memory}) {
  final k = g.karts[me];
  if (g.wrecked(me) || g.finished) return;
  double? tx, ty;
  var best = double.infinity;
  int? rival;
  for (var i = 0; i < g.karts.length; i++) {
    if (i == me || g.shielded(i) || g.wrecked(i)) continue;
    final o = g.karts[i];
    final d = (o.x - k.x) * (o.x - k.x) + (o.y - k.y) * (o.y - k.y);
    if (d < best) {
      best = d;
      rival = i;
    }
  }
  double aimOff(int r) {
    final o = g.karts[r];
    var d = (atan2(o.y - k.y, o.x - k.x) - k.angle) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    return d.abs();
  }

  switch (k.weapon) {
    case Weapon.none:
      var nearest = double.infinity;
      for (final b in g.boxes.where(g.boxReady)) {
        final d = (b.x - k.x) * (b.x - k.x) + (b.y - k.y) * (b.y - k.y);
        if (d < nearest) {
          nearest = d;
          tx = b.x;
          ty = b.y;
        }
      }
    case Weapon.boost:
      g.fire(me);
    case Weapon.shield:
      if (k.hp < SmashKartsLogic.maxHp || rng.nextDouble() < 0.01) g.fire(me);
    case Weapon.rocket || Weapon.gun || Weapon.triple:
      if (rival != null) {
        tx = g.karts[rival].x;
        ty = g.karts[rival].y;
        final range = k.weapon == Weapon.gun ? 0.9 : 1.3;
        if (aimOff(rival) < 0.2 && sqrt(best) < range && rng.nextDouble() < 0.1) g.fire(me);
      }
    case Weapon.mine:
      memory['mineAt'] ??= nowMs + 900 + rng.nextInt(1500);
      if (nowMs >= (memory['mineAt'] as int)) {
        memory.remove('mineAt');
        g.fire(me);
      }
  }
  if (k.speed < 0.05 && k.stickPower > 0.5) {
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
  if (tx == null) {
    if (memory['wanderUntil'] == null || nowMs > (memory['wanderUntil'] as int)) {
      memory['wander'] = rng.nextDouble() * 2 * pi;
      memory['wanderUntil'] = nowMs + 1500;
    }
    g.steer(me, memory['wander'] as double, 0.75);
    return;
  }
  g.steer(me, atan2(ty! - k.y, tx - k.x), 1);
}
