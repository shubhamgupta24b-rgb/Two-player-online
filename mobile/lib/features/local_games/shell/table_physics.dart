import 'dart:math';

/// A circle on a table. Positions are in the same units as the table size.
class Disk {
  double x, y, vx, vy, r;
  final int id;
  int group;
  bool sunk = false;

  Disk({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.r,
    required this.id,
    this.group = 0,
  });
}

class Pocket {
  final double x, y, r;
  const Pocket(this.x, this.y, this.r);
}

/// One deterministic step. Returns disk ids that fell into a pocket this step.
List<int> stepDisks(
  List<Disk> disks, {
  required double w,
  required double h,
  required List<Pocket> pockets,
  double friction = 1.8,
  double dt = 1 / 60,
  double restitution = 0.9,
}) {
  final pocketed = <int>[];
  void walls(Disk d) {
    if (d.x < d.r) {
      d.x = d.r;
      if (d.vx < 0) d.vx = -d.vx * restitution;
    } else if (d.x > w - d.r) {
      d.x = w - d.r;
      if (d.vx > 0) d.vx = -d.vx * restitution;
    }
    if (d.y < d.r) {
      d.y = d.r;
      if (d.vy < 0) d.vy = -d.vy * restitution;
    } else if (d.y > h - d.r) {
      d.y = h - d.r;
      if (d.vy > 0) d.vy = -d.vy * restitution;
    }
  }

  void sleep(Disk d) {
    if (d.vx.abs() < 0.02) d.vx = 0;
    if (d.vy.abs() < 0.02) d.vy = 0;
  }

  for (final d in disks) {
    if (d.sunk) continue;
    final drag = max(0.0, 1 - friction * dt);
    d.vx *= drag;
    d.vy *= drag;
    sleep(d);
    d.x += d.vx * dt;
    d.y += d.vy * dt;
    walls(d);
  }
  for (var i = 0; i < disks.length; i++) {
    final a = disks[i];
    if (a.sunk) continue;
    for (var j = i + 1; j < disks.length; j++) {
      final b = disks[j];
      if (b.sunk) continue;
      final dx = b.x - a.x, dy = b.y - a.y;
      final minD = a.r + b.r;
      final dist2 = dx * dx + dy * dy;
      if (dist2 >= minD * minD || dist2 == 0) continue;
      final dist = sqrt(dist2);
      final nx = dx / dist, ny = dy / dist;
      final overlap = minD - dist;
      a.x -= nx * overlap / 2;
      a.y -= ny * overlap / 2;
      b.x += nx * overlap / 2;
      b.y += ny * overlap / 2;
      final rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
      if (rv > 0) continue;
      final impulse = -(1 + restitution) * rv / 2;
      a.vx -= impulse * nx;
      a.vy -= impulse * ny;
      b.vx += impulse * nx;
      b.vy += impulse * ny;
    }
  }
  for (final d in disks) {
    if (d.sunk) continue;
    walls(d);
    sleep(d);
  }
  for (final d in disks) {
    if (d.sunk) continue;
    for (final p in pockets) {
      final dx = d.x - p.x, dy = d.y - p.y;
      if (dx * dx + dy * dy < p.r * p.r) {
        d.sunk = true;
        d.vx = 0;
        d.vy = 0;
        pocketed.add(d.id);
        break;
      }
    }
  }
  return pocketed;
}

bool disksSettled(Iterable<Disk> disks) =>
    disks.every((d) => d.sunk || (d.vx == 0 && d.vy == 0));
