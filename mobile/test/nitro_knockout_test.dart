import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multiplayer_game/features/local_games/local_games_hub_screen.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_knockout_game.dart';
import 'package:multiplayer_game/features/local_games/nitro_knockout/nitro_online_screen.dart';
import 'package:multiplayer_game/games/game_catalog.dart';
import 'package:multiplayer_game/games/game_module.dart';

void main() {
  test('Nitro Knockout replaced Smash Karts in the catalog', () {
    expect(gameCatalog.any((g) => g.id == 'nitro_knockout'), isTrue);
    expect(gameCatalog.any((g) => g.id == 'smash_karts'), isFalse,
        reason: 'Smash Karts was replaced by Nitro Knockout');
    final nitro = gameCatalog.firstWhere((g) => g.id == 'nitro_knockout');
    expect(nitro.name, 'Nitro Knockout');
    expect(nitro.playable, isTrue);
    expect(nitro.minPlayers, 2, reason: 'online rooms need at least 2 humans');
    expect(nitro.maxPlayers, 10, reason: 'rooms seat up to 10 humans');
  });

  test('the local hub ships Nitro Knockout as a solo game (you vs 7 bots)', () {
    final nitro = allLocalGames.firstWhere((g) => g.id == 'nitro_knockout');
    expect(nitro.title, 'Nitro Knockout');
    expect(nitro.solo, isTrue, reason: 'offline play is 1 human + 7 AI karts');
    expect(nitro.maxPlayers, 1);
    expect(nitro.scoreUnit, 'KOs');
    expect(nitro.online, isNull, reason: 'online play uses the dedicated NitroOnlineScreen, not RelayPlay');
  });

  test('routing: rooms open the Nitro online screen; unknown games stay null', () {
    expect(gameScreenFor('nitro_knockout'), isA<NitroOnlineScreen>());
  });

  test('boot options serialise to the contract the WASM game reads', () {
    expect(const NitroBoot(mode: 'offline').asJson(), '{"mode":"offline","seat":0,"seats":8,"names":[]}');
    final host = const NitroBoot(mode: 'host', seat: 2, seats: 5, names: ['A', 'B', 'ME', 'D', 'E']);
    final decoded = host.asJson();
    expect(decoded, contains('"mode":"host"'));
    expect(decoded, contains('"seat":2'));
    expect(decoded, contains('"seats":5'));
    expect(decoded, contains('"names":["A","B","ME","D","E"]'));
  });

  test('the offline play builder hands out a WebView view', () {
    final view = nitroKartsInfo.play(const [], (_) {});
    expect(view, isA<NitroOfflineView>());
  });

  test('the bundled game talks to Flutter through the channel webview_flutter provides', () {
    // webview_flutter's JavaScriptChannel only has postMessage; `.post` silently drops
    // every message. Offline needs the channel too, or its result never arrives.
    final js = Directory('assets/nitro/assets').listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.js')).readAsStringSync();
    expect(js, contains('{post:a=>window.NitroBridge?.postMessage(a)}'));
    expect(js, isNot(contains('NitroBridge?.post(')));
    expect(js, isNot(contains('t==="offline"?void 0:')));
  });
}
