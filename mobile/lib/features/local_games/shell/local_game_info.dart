import 'package:flutter/material.dart';
import '../../guess_person/models/gp_player.dart';
import 'bots.dart';
import 'local_game_logic.dart';

export 'bots.dart' show BotSeat, BotTurn, botFor, BotScope;

typedef PlayBuilder = Widget Function(List<GpPlayer> players, void Function(List<int> scores) onFinished);

/// How a game is played online: the host's phone runs [create]d logic; everyone else
/// mirrors the host's [save]d state with [load]. Every player's actions (including the
/// host's own) go through [apply], which must ignore actions that aren't theirs to make.
abstract class RelayGame {
  LocalGameLogic create(int players);
  Map<String, dynamic> save(LocalGameLogic g);
  void load(LocalGameLogic g, Map<String, dynamic> state, int me);
  void apply(LocalGameLogic g, int from, String name, List<Object?> args);
  Widget view(BuildContext context, LocalGameLogic g, List<GpPlayer> players, int me);

  /// Actions sent many times a second (paddle moves); only the latest is sent, ~20 a second.
  Set<String> get continuous;

  /// Host-side housekeeping after each change, e.g. skipping pass-the-phone screens.
  void hostAuto(LocalGameLogic g);
}

class RelaySpec<T extends LocalGameLogic> implements RelayGame {
  final T Function(int players) _create;
  final Map<String, dynamic> Function(T g) _save;
  final void Function(T g, Map<String, dynamic> s, int me) _load;
  final void Function(T g, int from, String name, List<Object?> args) _apply;
  final Widget Function(BuildContext context, T g, List<GpPlayer> players, int me) _view;
  final void Function(T g)? _hostAuto;
  @override
  final Set<String> continuous;

  RelaySpec({
    required T Function(int players) create,
    required Map<String, dynamic> Function(T g) save,
    required void Function(T g, Map<String, dynamic> s, int me) load,
    required void Function(T g, int from, String name, List<Object?> args) apply,
    required Widget Function(BuildContext context, T g, List<GpPlayer> players, int me) view,
    void Function(T g)? hostAuto,
    this.continuous = const {},
  })  : _create = create,
        _save = save,
        _load = load,
        _apply = apply,
        _view = view,
        _hostAuto = hostAuto;

  @override
  LocalGameLogic create(int players) => _create(players);
  @override
  Map<String, dynamic> save(LocalGameLogic g) => _save(g as T);
  @override
  void load(LocalGameLogic g, Map<String, dynamic> state, int me) => _load(g as T, state, me);
  @override
  void apply(LocalGameLogic g, int from, String name, List<Object?> args) => _apply(g as T, from, name, args);
  @override
  Widget view(BuildContext context, LocalGameLogic g, List<GpPlayer> players, int me) => _view(context, g as T, players, me);
  @override
  void hostAuto(LocalGameLogic g) => _hostAuto?.call(g as T);
}

/// JSON helpers for [RelaySpec.save]/[RelaySpec.load].
List<int> ints(Object? v) => [for (final x in v as List) (x as num).toInt()];
List<int?> nInts(Object? v) => [for (final x in v as List) (x as num?)?.toInt()];
List<double> doubles(Object? v) => [for (final x in v as List) (x as num).toDouble()];
int? nInt(Object? v) => (v as num?)?.toInt();
int asInt(Object? v) => (v as num).toInt();
double asDouble(Object? v) => (v as num).toDouble();

/// Everything the shared shell needs to present one game.
class LocalGameInfo {
  final String id;
  final String title;
  final String emoji;
  final Color color;
  final String tagline;
  final List<String> rules;
  final String scoreUnit; // "taps", "points", "pairs", "cells"
  final bool splitScreen; // players sit at opposite ends of the phone
  final int minPlayers; // fewest players the game works with (1 for solo games)
  bool get solo => maxPlayers == 1;
  final int maxPlayers; // 2-6; the intro screen lets players pick how many
  final PlayBuilder play;
  final RelayGame? online; // how to play it over the internet, if it can be
  final BotTurn? bot; // how the computer plays a seat, if it can
  const LocalGameInfo({
    this.bot,
    this.minPlayers = 2,
    this.maxPlayers = 2,
    this.online,
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
    required this.tagline,
    required this.rules,
    required this.scoreUnit,
    required this.splitScreen,
    required this.play,
  });
}
