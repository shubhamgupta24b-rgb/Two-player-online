import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authentication_manager.dart';
import '../../core/records/records.dart';
import '../../core/ui/app_ui.dart';
import '../../games/game_catalog.dart';
import '../local_games/local_games_hub_screen.dart';
import '../privacy/privacy_screen.dart';

/// My Records: best score, wins and games played per game, kept on this phone only.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Map<String, GameRecord>? records;

  @override
  void initState() {
    super.initState();
    Records.all().then((r) {
      if (mounted) setState(() => records = r);
    });
  }

  /// Name and emoji for a game id, from the one-device list or the online catalog.
  (String, String) _game(String id) {
    for (final g in allLocalGames) {
      if (g.id == id) return (g.title, g.emoji);
    }
    for (final g in gameCatalog) {
      if (g.id == id) return (g.name, g.emoji);
    }
    return (id, '🎮');
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthenticationManager>().displayName;
    final r = records;
    final entries = r == null ? const <MapEntry<String, GameRecord>>[] : (r.entries.where((e) => e.value.played > 0 || e.value.best > 0).toList()..sort((a, b) => b.value.played - a.value.played));
    final played = entries.fold(0, (s, e) => s + e.value.played);
    final wins = entries.fold(0, (s, e) => s + e.value.wins);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 6),
              child: Row(children: [
                IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🏆 MY RECORDS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text('Saved on this phone only', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(children: [
                _Stat('🎮', '$played', 'GAMES'),
                const SizedBox(width: 10),
                _Stat('🥇', '$wins', 'WINS'),
                const SizedBox(width: 10),
                _Stat('🎯', '${entries.length}', 'DIFFERENT'),
              ]),
            ),
            Expanded(
              child: r == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : entries.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('No games yet${name.isEmpty ? '' : ', $name'}!\nPlay any game and your best scores show up here.',
                                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 15, height: 1.4)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final e = entries[i];
                            final (title, emoji) = _game(e.key);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.stroke)),
                              child: Row(children: [
                                Text(emoji, style: const TextStyle(fontSize: 30)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                    Text('${e.value.played} played${e.value.wins > 0 ? ' · ${e.value.wins} won' : ''}',
                                        style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  const Text('BEST', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 1.2)),
                                  Text('${e.value.best}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                                ]),
                              ]),
                            );
                          },
                        ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              icon: const Icon(Icons.shield_outlined, size: 18, color: AppColors.muted),
              label: const Text('Privacy & your data', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji, value, label;
  const _Stat(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.stroke)),
          child: Column(children: [
            Text('$emoji $value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 1.2)),
          ]),
        ),
      );
}
