import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/session/game_session_manager.dart';

const _memoryInk = Color(0xFF101827);
const _memoryPanel = Color(0xFF1B2638);
const _memoryBlue = Color(0xFF4DA3FF);
const _memoryCoral = Color(0xFFFF647C);
const _memoryGold = Color(0xFFFFC857);

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSessionManager>();
    final st = session.state!;
    final myId = context.read<AuthenticationManager>().token.split(':')[1];
    final cards = (st['cards'] as List).cast<Map>();
    final players = (st['players'] as List).cast<Map>();
    final scores = Map<String, dynamic>.from(st['scores'] as Map);
    final turn = st['turn'] as String;
    final phase = st['phase'] as String;
    final canPlay = phase == 'turn' && turn == myId;
    final cardCount = (st['cardCount'] as num?)?.toInt() ?? cards.length;
    final current = players.where((p) => p['userId'] == turn);
    final turnName = current.isEmpty ? 'Opponent' : current.first['username'].toString();

    int mismatchSeconds() {
      final end = st['mismatchEndsAt'];
      if (end is! num) return 0;
      final ms = end.toInt() - session.serverNowMs;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }

    final status = phase == 'mismatch'
        ? 'NEXT TURN ${mismatchSeconds()}s'
        : canPlay ? 'YOUR TURN' : "${turnName.toUpperCase()}'S TURN";
    final statusColor = phase == 'mismatch' ? _memoryGold : canPlay ? _memoryBlue : _memoryCoral;

    return ColoredBox(
      color: _memoryInk,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.07),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: _memoryGold, size: 21),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RivalRooms',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.3)),
                        SizedBox(height: 2),
                        Text('MEMORY MATCH',
                          style: TextStyle(color: Color(0xFF9AA8BC), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                  _StatusPill(label: status, color: statusColor),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < players.length; i++) ...[
                    Expanded(
                      child: _PlayerScore(
                        name: players[i]['username'].toString(),
                        score: scores[players[i]['userId']] ?? 0,
                        isMe: players[i]['userId'] == myId,
                        isActive: players[i]['userId'] == turn,
                        accent: i == 0 ? _memoryBlue : _memoryCoral,
                      ),
                    ),
                    if (i < players.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Text('VS', style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _memoryPanel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.06)),
                ),
                child: Row(
                  children: [
                    Icon(phase == 'mismatch' ? Icons.hourglass_bottom_rounded : canPlay ? Icons.touch_app_rounded : Icons.hourglass_empty_rounded,
                      color: statusColor, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        phase == 'mismatch' ? 'Remember the cards — turn changes shortly'
                          : canPlay ? 'Find a matching pair to score a point'
                          : 'Waiting for $turnName to play',
                        style: const TextStyle(color: Color(0xFFE1E8F2), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(9)),
                      child: Text('$cardCount CARDS',
                        style: const TextStyle(color: Color(0xFFBBC8D9), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cardCount >= 28 ? 4 : 4,
                        crossAxisSpacing: cardCount >= 28 ? 6 : 8,
                        mainAxisSpacing: cardCount >= 28 ? 6 : 8,
                        childAspectRatio: cardCount >= 28 ? .92 : .84,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, index) {
                        final card = cards[index];
                        final value = card['value'];
                        final visible = value != null;
                        final matched = card['matched'] == true;
                        return _MemoryCard(
                          value: value,
                          visible: visible,
                          matched: matched,
                          dense: cardCount >= 28,
                          onTap: canPlay && !visible && !matched
                              ? () => context.read<GameSessionManager>().action('memory:flip', {'id': card['id']})
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text('LIVE MULTIPLAYER MATCH',
                style: TextStyle(color: Colors.white.withOpacity(.36), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerScore extends StatelessWidget {
  const _PlayerScore({required this.name, required this.score, required this.isMe, required this.isActive, required this.accent});
  final String name;
  final dynamic score;
  final bool isMe, isActive;
  final Color accent;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: accent.withOpacity(isActive ? .16 : .07),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: accent.withOpacity(isActive ? .8 : .2), width: isActive ? 1.5 : 1),
    ),
    child: Row(children: [
      Container(width: 5, height: 31, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(5))),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isMe ? 'YOU' : name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .7)),
        const SizedBox(height: 3),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ])),
      Text('$score', style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w900)),
    ]),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 130),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(.38))),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .45)),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.value, required this.visible, required this.matched, required this.dense, required this.onTap});
  final dynamic value;
  final bool visible, matched, dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final revealed = visible || matched;
    return Semantics(
      button: onTap != null,
      label: matched ? 'Matched card' : visible ? 'Revealed card: $value' : 'Hidden memory card',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(dense ? 12 : 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: revealed
                ? LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: matched ? const [Color(0xFF183A42), Color(0xFF214B4D)] : const [Color(0xFFF7F3EB), Color(0xFFE5DED2)])
                : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF34445F), Color(0xFF202B40)]),
              borderRadius: BorderRadius.circular(dense ? 12 : 16),
              border: Border.all(color: matched ? const Color(0xFF66D6B1) : revealed ? Colors.white.withOpacity(.65) : Colors.white.withOpacity(.12), width: matched ? 2 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: dense ? 5 : 9, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: revealed
                  ? FittedBox(
                      key: ValueKey('value-$value-$matched'),
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.all(dense ? 3 : 7),
                        child: Text(value?.toString() ?? '✓',
                          style: TextStyle(color: matched ? const Color(0xFFBFF8E4) : _memoryInk, fontSize: dense ? 24 : 31, fontWeight: FontWeight.w800)),
                      ),
                    )
                  : Icon(Icons.workspace_premium_rounded, key: const ValueKey('hidden'), size: dense ? 18 : 25, color: Colors.white.withOpacity(.24)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
