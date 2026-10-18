import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ui/tokens.dart';
import 'game_icon_assets.dart';
import 'game_preview.dart';
import 'home_chrome.dart';

/// Image-led game card: flat surface, thin border, one soft shadow.
class HomeGameCard extends StatefulWidget {
  final String id;
  final String title;
  final VoidCallback onTap;
  final bool selected;
  const HomeGameCard({super.key, required this.id, required this.title, required this.onTap, this.selected = false});

  @override
  State<HomeGameCard> createState() => _HomeGameCardState();
}

class _HomeGameCardState extends State<HomeGameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = HomeColors.of(context);
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.title,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HomeMetrics.cardRadius),
          boxShadow: _pressed ? const [] : [colors.cardShadow],
        ),
        child: Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HomeMetrics.cardRadius),
            side: BorderSide(color: selected ? colors.blue : colors.border, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) {
              if (_pressed != v) setState(() => _pressed = v);
            },
            child: AnimatedOpacity(
              duration: Motion.of(context, Motion.fast),
              opacity: _pressed ? 0.82 : 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _GameArt(id: widget.id)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: Fonts.body, fontSize: HomeMetrics.titleSize, height: 1.15, fontWeight: FontWeight.w800, color: colors.text),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Supplied SVG when the manifest has this game. Painted preview otherwise.
class _GameArt extends StatelessWidget {
  final String id;
  const _GameArt({required this.id});

  @override
  Widget build(BuildContext context) {
    final asset = gameIconAsset(id);
    if (asset == null) return GamePreview(id: id);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }
}
