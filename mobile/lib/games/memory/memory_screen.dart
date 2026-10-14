import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/session/game_session_manager.dart';

const _ink = Color(0xFF101827);
const _panel = Color(0xFF1B2638);
const _blue = Color(0xFF4DA3FF);
const _coral = Color(0xFFFF647C);
const _gold = Color(0xFFFFC857);

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
    // Preserve the existing server-synchronised mismatch countdown.
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
    final current = players.where((p) => p['userId'] == turn);
    final turnName =
        current.isEmpty ? 'Opponent' : current.first['username'].toString();

    int mismatchSeconds() {
      final end = st['mismatchEndsAt'];
      if (end is! num) return 0;
      final ms = end.toInt() - session.serverNowMs;
      return ms <= 0 ? 0 : (ms / 1000).ceil();
    }

    final status = phase == 'mismatch'
        ? 'NEXT TURN ${mismatchSeconds()}s'
        : canPlay
            ? 'YOUR TURN'
            : "${turnName.toUpperCase()}'S TURN";
    final statusColor =
        phase == 'mismatch' ? _gold : canPlay ? _blue : _coral;

    return ColoredBox(
      color: _ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: _gold, size: 21),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MEMORY',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.3)),
                        SizedBox(height: 2),
                        Text('MATCH THE PAIRS',
                            style: TextStyle(
                                color: Color(0xFF9AA8BC),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4)),
                      ],
                    ),
                  ),
                  _StatusPill(label: status, color: statusColor),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (var i = 0; i < players.length; i++) ...[
                    Expanded(
                      child: _PlayerScore(
                        name: players[i]['username'].toString(),
                        score: scores[players[i]['userId']] ?? 0,
                        isMe: players[i]['userId'] == myId,
                        isActive: players[i]['userId'] == turn,
                        accent: i == 0 ? _blue : _coral,
                      ),
                    ),
                    if (i < players.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('VS',
                            style: TextStyle(
                                color: Colors.white.withOpacity(.35),
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(.06)),
                ),
                child: Row(
                  children: [
                    Icon(
                      phase == 'mismatch'
                          ? Icons.hourglass_bottom_rounded
                          : canPlay
                              ? Icons.touch_app_rounded
                              : Icons.hourglass_empty_rounded,
                      color: statusColor,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        phase == 'mismatch'
                            ? 'Remember the cards — your turn is next'
                            : canPlay
                                ? 'Find a matching pair to score a point'
                                : 'Waiting for ${turnName} to play',
                        style: const TextStyle(
                            color: Color(0xFFE1E8F2),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .84,
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
                          onTap: canPlay && !visible && !matched
                              ? () => context
                                  .read<GameSessionManager>()
                                  .action('memory:flip', {'id': card['id']})
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('LIVE MULTIPLAYER MATCH',
                  style: TextStyle(
                      color: Colors.white.withOpacity(.38),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerScore extends StatelessWidget {
  const _PlayerScore({
    required this.name,
    required this.score,
    required this.isMe,
    required this.isActive,
    required this.accent,
  });

  final String name;
  final dynamic score;
  final bool isMe;
  final bool isActive;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(isActive ? .16 : .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: accent.withOpacity(isActive ? .8 : .2),
            width: isActive ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 34,
            decoration: BoxDecoration(
                color: accent, borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? 'YOU' : name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(.65),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7)),
                const SizedBox(height: 3),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Text('${score}',
              style: TextStyle(
                  color: accent, fontSize: 23, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 142),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(.38)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .5)),
      );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.value,
    required this.visible,
    required this.matched,
    required this.onTap,
  });

  final dynamic value;
  final bool visible;
  final bool matched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final revealed = visible || matched;
    return Semantics(
      button: onTap != null,
      label: matched
          ? 'Matched card'
          : visible
              ? 'Revealed card: ${value}'
              : 'Hidden memory card',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: revealed
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: matched
                          ? const [Color(0xFF183A42), Color(0xFF214B4D)]
                          : const [Color(0xFFF7F3EB), Color(0xFFE5DED2)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF34445F), Color(0xFF202B40)],
                    ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: matched
                    ? const Color(0xFF66D6B1)
                    : revealed
                        ? Colors.white.withOpacity(.65)
                        : Colors.white.withOpacity(.12),
                width: matched ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.18),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: revealed
                    ? FittedBox(
                        key: ValueKey('value-${value}-${matched}'),
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            value?.toString() ?? '✓',
                            style: TextStyle(
                              color: matched
                                  ? const Color(0xFFBFF8E4)
                                  : _ink,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    : Icon(Icons.workspace_premium_rounded,
                        key: const ValueKey('hidden'),
                        size: 27,
                        color: Colors.white.withOpacity(.24)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
