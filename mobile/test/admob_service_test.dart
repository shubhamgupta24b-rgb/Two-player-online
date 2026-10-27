import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/ads/admob_service.dart';
import 'package:multiplayer_game/features/guess_person/models/gp_player.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/shell/result_screen.dart';

void main() {
  test('debug and test builds use Google test ad units, never the production ones', () {
    expect(AdMobService.usesTestAds, isTrue);
    expect(AdMobService.interstitialUnit, AdMobService.testInterstitial);
    expect(AdMobService.rewardedInterstitialUnit, AdMobService.testRewardedInterstitial);
    expect(AdMobService.productionInterstitial, 'ca-app-pub-2273708482671832/3168825409');
    expect(AdMobService.productionRewardedInterstitial, 'ca-app-pub-2273708482671832/4842753743');
  });

  test('without a loaded ad, a transition runs straight away and no reward is granted', () {
    var ran = 0;
    for (var i = 0; i < 3; i++) {
      AdMobService.instance.showInterstitialThen(() => ran++);
    }
    expect(ran, 3);
    var rewarded = false;
    final shown = AdMobService.instance.showRewardedInterstitial(onRewardEarned: (_, __) => rewarded = true);
    expect(shown, isFalse);
    expect(rewarded, isFalse);
  });

  testWidgets('result screen buttons still work when no ad is available', (tester) async {
    final game = localGames.firstWhere((g) => g.id == 'archery');
    final players = [GpPlayer(name: 'Aarav', color: gpPlayerColors[0], score: 40), GpPlayer(name: 'Meera', color: gpPlayerColors[1], score: 46)];
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResultScreen(
          game: game,
          players: players,
          onRematch: () => taps.add('rematch'),
          onChangePlayers: () => taps.add('players'),
          onExit: () => taps.add('exit'),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Rematch'));
    await tester.tap(find.text('Change players'));
    await tester.tap(find.text('All games'));
    expect(taps, ['rematch', 'players', 'exit']);
  });
}
