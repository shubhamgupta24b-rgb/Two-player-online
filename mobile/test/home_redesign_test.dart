import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/core/settings/app_settings.dart';
import 'package:multiplayer_game/features/home/game_preview.dart';
import 'package:multiplayer_game/features/home/home_layout.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/games/game_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('all games uses three columns and six cards per batch on a phone', () {
    expect(allGamesColumns(320), 2);
    expect(allGamesColumns(339), 2);
    expect(allGamesColumns(340), 3);
    expect(allGamesColumns(390), 3);
    expect(allGamesColumns(411), 3);
    expect(allGamesBatchSize(390), 6);
    expect(allGamesColumns(900), 6);
    expect(allGamesBatchSize(900), 12);
    expect(completeGameBatches(67, 390), 11);
    expect(completeGameBatches(67, 390) * 6, lessThan(67));
  });

  test('trending uses live counts and ignores unknown or empty games', () {
    const known = {'memory', 'ludo', 'smash_karts'};
    expect(
      trendingIdsFromCounts({
        'ok': true,
        'games': [
          {'id': 'ludo', 'playing': 2},
          {'id': 'memory', 'playing': 5},
          {'id': 'missing', 'playing': 9},
          {'id': 'smash_karts', 'playing': 0},
        ],
      }, known),
      ['memory', 'ludo'],
    );
    expect(trendingIdsFromCounts({'ok': false}, known), isEmpty);
    expect(trendingIdsFromCounts(null, known), isEmpty);
  });

  test('every listed game and catalog game has its own preview', () {
    expect(gamePreviewManifest.keys.toSet(), previewSceneIds);
    final ids = <String>{
      ...listedGames().map((g) => g.id),
      ...gameCatalog.map((g) => g.id),
      'ludo_teams',
    };
    final missing = ids.where((id) => !hasUniquePreview(id)).toList();
    expect(missing, isEmpty, reason: 'games without a preview');
    expect(ids.length, greaterThanOrEqualTo(67));
  });

  test('home lamp theme is saved and restored', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init();
    expect(AppSettings.homeLight.value, isFalse);
    await AppSettings.setHomeLight(true);
    AppSettings.homeLight.value = false;
    await AppSettings.init();
    expect(AppSettings.homeLight.value, isTrue);
    await AppSettings.setHomeLight(false);
  });

  test('previews paint and a missing id does not throw', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final id in gamePreviewManifest.keys) {
      GamePreviewPainter(id).paint(canvas, const Size(120, 96));
    }
    GamePreviewPainter('not_a_game').paint(canvas, const Size(80, 80));
    recorder.endRecording();
  });
}
