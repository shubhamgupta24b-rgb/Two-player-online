import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/room/room_manager.dart';
import '../../../games/game_catalog.dart';
import '../widgets/mp_ui.dart';
import 'mp_lobby_screen.dart';

class MpCreateRoomScreen extends StatefulWidget {
  const MpCreateRoomScreen({super.key});
  @override
  State<MpCreateRoomScreen> createState() => _MpCreateRoomScreenState();
}

class _MpCreateRoomScreenState extends State<MpCreateRoomScreen> {
  final _games = gameCatalog.where((g) => g.playable).toList();
  late String _gameId = _games.first.id;
  int _players = 2;
  bool _busy = false;

  int get _maxPlayers => _games.firstWhere((g) => g.id == _gameId).maxPlayers;

  void _pickGame(String id) => setState(() {
        _gameId = id;
        if (_players > _maxPlayers) _players = _maxPlayers;
      });

  Future<void> _create() async {
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final err = await rm.create(_gameId, _players);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const MpLobbyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildMpTheme(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Room', style: TextStyle(fontWeight: FontWeight.w800))),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                const SectionLabel('Choose a game'),
                for (final g in _games) ...[
                  _GameTile(game: g, selected: g.id == _gameId, onTap: () => _pickGame(g.id)),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                const SectionLabel('Number of players'),
                Row(children: [
                  for (final n in [2, 3, 4]) ...[
                    Expanded(
                      child: _CountChip(
                        n: n,
                        selected: n == _players,
                        enabled: n <= _maxPlayers,
                        onTap: () => setState(() => _players = n),
                      ),
                    ),
                    if (n != 4) const SizedBox(width: 10),
                  ],
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: BusyButton(label: 'CREATE ROOM', busy: _busy, onPressed: _create),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final GameInfo game;
  final bool selected;
  final VoidCallback onTap;
  const _GameTile({required this.game, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.22) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(Icons.sports_esports_rounded, color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 14),
            Expanded(child: Text(game.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            Text('up to ${game.maxPlayers}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(width: 8),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.surfaceHigh),
          ]),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int n;
  final bool selected, enabled;
  final VoidCallback onTap;
  const _CountChip({required this.n, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 64,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('players', style: TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
