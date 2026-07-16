import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/clothing_tags.dart';

enum ClothingIconType { top, bottom, outer }

class ClothingIcon extends StatelessWidget {
  const ClothingIcon({
    super.key,
    required this.code,
    required this.type,
    this.size = 72,
    this.showLabel = true,
    this.selected = false,
    this.plain = false,
  });

  final String? code;
  final ClothingIconType type;
  final double size;
  final bool showLabel;
  final bool selected;

  /// Picker style (feedback sheet): neutral tile, no shadow — selection is
  /// communicated by the accent border alone.
  final bool plain;

  Color get _tileColor => switch (type) {
    ClothingIconType.top => KisouTheme.topBlue,
    ClothingIconType.bottom => KisouTheme.bottomSand,
    ClothingIconType.outer => KisouTheme.outerOrange,
  };

  @override
  Widget build(BuildContext context) {
    final label = _displayName;
    final assetPath = _iconAssetPath;
    final radius = size * 0.30;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: plain ? context.kisou.surface : _tileColor,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: plain ? null : KisouTheme.tileShadow,
              border: plain
                  ? Border.all(
                      color: selected ? KisouTheme.accent : context.kisou.hairline,
                      width: selected ? 2 : 1,
                    )
                  : (selected
                        ? Border.all(color: KisouTheme.deepSky, width: 3)
                        : null),
            ),
            clipBehavior: Clip.antiAlias,
            child: assetPath != null
                ? Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _fallbackLabel(context, label),
                  )
                : _fallbackLabel(context, label),
          ),
          if (showLabel) ...[
            const SizedBox(height: KisouTheme.gapS),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: size >= 72 ? 13 : 12,
                fontWeight: FontWeight.w600,
                color: context.kisou.softInk,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackLabel(BuildContext context, String label) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.kisou.ink,
          fontWeight: FontWeight.w700,
          fontSize: size >= 72 ? 14 : 12,
          height: 1.25,
        ),
      ),
    );
  }

  String get _displayName {
    return switch (type) {
      ClothingIconType.top =>
        ClothingTop.fromCode(code)?.displayName ?? code ?? '',
      ClothingIconType.bottom =>
        ClothingBottom.fromCode(code)?.displayName ?? code ?? '',
      ClothingIconType.outer =>
        ClothingOuter.fromCode(code)?.displayName ?? 'なし',
    };
  }

  String? get _iconAssetPath {
    return switch (type) {
      ClothingIconType.top => ClothingTop.fromCode(code)?.iconAssetPath,
      ClothingIconType.bottom => ClothingBottom.fromCode(code)?.iconAssetPath,
      ClothingIconType.outer => ClothingOuter.fromCode(code).iconAssetPath,
    };
  }
}
