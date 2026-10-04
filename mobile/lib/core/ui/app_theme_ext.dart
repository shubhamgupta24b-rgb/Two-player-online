import 'package:flutter/material.dart';
import 'tokens.dart';

export 'tokens.dart';

/// One typography scale. Scores use tabular figures so they don't jiggle as they change.
@immutable
class GameType {
  final TextStyle display, headline, title, body, bodyStrong, label, caption, button, score, scoreLarge;
  const GameType({
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.button,
    required this.score,
    required this.scoreLarge,
  });

  static const _tabular = [FontFeature.tabularFigures()];

  /// The scale in a given text colour.
  factory GameType.of(Color text, Color muted) => GameType(
        display: TextStyle(color: text, fontSize: 34, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: 0.5),
        headline: TextStyle(color: text, fontSize: 26, fontWeight: FontWeight.w900, height: 1.15),
        title: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: 0.3),
        body: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
        bodyStrong: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800, height: 1.3),
        label: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.4),
        caption: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3),
        button: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        score: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w900, fontFeatures: _tabular),
        scoreLarge: TextStyle(color: text, fontSize: 64, fontWeight: FontWeight.w900, height: 1, fontFeatures: _tabular),
      );

  static GameType lerp(GameType a, GameType b, double t) => GameType(
        display: TextStyle.lerp(a.display, b.display, t)!,
        headline: TextStyle.lerp(a.headline, b.headline, t)!,
        title: TextStyle.lerp(a.title, b.title, t)!,
        body: TextStyle.lerp(a.body, b.body, t)!,
        bodyStrong: TextStyle.lerp(a.bodyStrong, b.bodyStrong, t)!,
        label: TextStyle.lerp(a.label, b.label, t)!,
        caption: TextStyle.lerp(a.caption, b.caption, t)!,
        button: TextStyle.lerp(a.button, b.button, t)!,
        score: TextStyle.lerp(a.score, b.score, t)!,
        scoreLarge: TextStyle.lerp(a.scoreLarge, b.scoreLarge, t)!,
      );
}

/// The flavour-aware design tokens. Two sets: [neon] (the default night look) and [flat]
/// (the flat app's board-game look). Read them with `context.tk`.
///
/// Text pairs: [onBg]/[onBgMuted] go straight on the background or on [glass];
/// [text]/[textMuted] go on [card] surfaces.
@immutable
class GameTokens extends ThemeExtension<GameTokens> {
  final bool flat;
  final Color bgTop, bg, bgBottom;
  final Color glass, glassStrong, card, cardRaised, sunken, stroke, strokeStrong, scrim;
  final Color onBg, onBgMuted, text, textMuted;
  final Color accent, onAccent, success, warn, danger, info;
  final List<BoxShadow> shadowSm, shadowMd, shadowLg;
  /// Text styles in [onBg]. (Not called 	ype: ThemeExtension uses that name as its key.)
  final GameType styles;
  /// Text styles in [text], for card surfaces.
  final GameType cardStyles;

  const GameTokens({
    required this.flat,
    required this.bgTop,
    required this.bg,
    required this.bgBottom,
    required this.glass,
    required this.glassStrong,
    required this.card,
    required this.cardRaised,
    required this.sunken,
    required this.stroke,
    required this.strokeStrong,
    required this.scrim,
    required this.onBg,
    required this.onBgMuted,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warn,
    required this.danger,
    required this.info,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.styles,
    required this.cardStyles,
  });

  static final neon = GameTokens(
    flat: false,
    bgTop: NeonPalette.bgTop,
    bg: NeonPalette.bg,
    bgBottom: NeonPalette.bgBottom,
    glass: NeonPalette.glass,
    glassStrong: NeonPalette.glassStrong,
    card: NeonPalette.card,
    cardRaised: NeonPalette.cardRaised,
    sunken: NeonPalette.sunken,
    stroke: NeonPalette.stroke,
    strokeStrong: NeonPalette.strokeStrong,
    scrim: const Color(0xB3060820),
    onBg: NeonPalette.text,
    onBgMuted: NeonPalette.textMuted,
    text: NeonPalette.text,
    textMuted: NeonPalette.textMuted,
    accent: Brand.gold,
    onAccent: Brand.ink,
    success: StatusColors.success,
    warn: StatusColors.warn,
    danger: StatusColors.danger,
    info: StatusColors.info,
    shadowSm: const [BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2))],
    shadowMd: const [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 6))],
    shadowLg: const [BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 12))],
    styles: GameType.of(NeonPalette.text, NeonPalette.textMuted),
    cardStyles: GameType.of(NeonPalette.text, NeonPalette.textMuted),
  );

  static final flatSet = GameTokens(
    flat: true,
    bgTop: FlatPalette.skyLight,
    bg: FlatPalette.sky,
    bgBottom: FlatPalette.skyDeep,
    glass: const Color(0x24000000),
    glassStrong: const Color(0x38000000),
    card: FlatPalette.tile,
    cardRaised: FlatPalette.tile,
    sunken: FlatPalette.option,
    stroke: const Color(0x4DFFFFFF),
    strokeStrong: FlatPalette.tileShade,
    scrim: const Color(0x99173A52),
    onBg: Colors.white,
    onBgMuted: const Color(0xFFEAF4FB),
    text: FlatPalette.ink,
    textMuted: FlatPalette.inkMuted,
    accent: Brand.gold,
    onAccent: Brand.ink,
    success: const Color(0xFF1E9E57),
    warn: StatusColors.warn,
    danger: FlatPalette.close,
    info: StatusColors.info,
    shadowSm: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
    shadowMd: const [BoxShadow(color: Color(0x38000000), offset: Offset(0, 4))],
    shadowLg: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 6))],
    styles: GameType.of(Colors.white, const Color(0xFFEAF4FB)),
    cardStyles: GameType.of(FlatPalette.ink, FlatPalette.inkMuted),
  );

  @override
  GameTokens copyWith({bool? flat}) => flat == null ? this : (flat ? flatSet : neon);

  @override
  GameTokens lerp(covariant GameTokens? o, double t) {
    if (o == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) => BoxShadow.lerpList(a, b, t) ?? b;
    return GameTokens(
      flat: t < 0.5 ? flat : o.flat,
      bgTop: c(bgTop, o.bgTop),
      bg: c(bg, o.bg),
      bgBottom: c(bgBottom, o.bgBottom),
      glass: c(glass, o.glass),
      glassStrong: c(glassStrong, o.glassStrong),
      card: c(card, o.card),
      cardRaised: c(cardRaised, o.cardRaised),
      sunken: c(sunken, o.sunken),
      stroke: c(stroke, o.stroke),
      strokeStrong: c(strokeStrong, o.strokeStrong),
      scrim: c(scrim, o.scrim),
      onBg: c(onBg, o.onBg),
      onBgMuted: c(onBgMuted, o.onBgMuted),
      text: c(text, o.text),
      textMuted: c(textMuted, o.textMuted),
      accent: c(accent, o.accent),
      onAccent: c(onAccent, o.onAccent),
      success: c(success, o.success),
      warn: c(warn, o.warn),
      danger: c(danger, o.danger),
      info: c(info, o.info),
      shadowSm: s(shadowSm, o.shadowSm),
      shadowMd: s(shadowMd, o.shadowMd),
      shadowLg: s(shadowLg, o.shadowLg),
      styles: GameType.lerp(styles, o.styles, t),
      cardStyles: GameType.lerp(cardStyles, o.cardStyles, t),
    );
  }
}

extension GameTokensX on BuildContext {
  /// The design tokens in effect here (neon unless inside a flat-look subtree).
  GameTokens get tk => Theme.of(this).extension<GameTokens>() ?? GameTokens.neon;
}

/// Gives [child] the flat or neon token set (e.g. a word game's play screen in the flat app).
class TokenScope extends StatelessWidget {
  final bool flat;
  final Widget child;
  const TokenScope({super.key, required this.flat, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final want = flat ? GameTokens.flatSet : GameTokens.neon;
    if (identical(theme.extension<GameTokens>(), want)) return child;
    return Theme(data: theme.copyWith(extensions: [...theme.extensions.values.where((e) => e is! GameTokens), want]), child: child);
  }
}
