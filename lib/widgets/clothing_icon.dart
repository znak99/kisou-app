import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../constants/clothing_tags.dart';

enum ClothingIconType { top, bottom, outer }

String? clothingIconAssetPath({
  required String? code,
  required ClothingIconType type,
}) {
  return switch (type) {
    ClothingIconType.top => ClothingTop.fromCode(code)?.iconAssetPath,
    ClothingIconType.bottom => ClothingBottom.fromCode(code)?.iconAssetPath,
    ClothingIconType.outer =>
      code == null
          ? outerNoneIconAssetPath
          : ClothingOuter.fromCode(code)?.iconAssetPath,
  };
}

ImageProvider<Object>? clothingIconImageProvider({
  required BuildContext context,
  required String? code,
  required ClothingIconType type,
  required double size,
}) {
  final path = clothingIconAssetPath(code: code, type: type);
  if (path == null) {
    return null;
  }
  final physicalEdge = (size * MediaQuery.devicePixelRatioOf(context))
      .ceil()
      .clamp(1, 384);
  return ResizeImage.resizeIfNeeded(
    physicalEdge,
    physicalEdge,
    AssetImage(path),
  );
}

Future<void> precacheClothingIcon({
  required BuildContext context,
  required String? code,
  required ClothingIconType type,
  required double size,
}) async {
  final provider = clothingIconImageProvider(
    context: context,
    code: code,
    type: type,
    size: size,
  );
  if (provider != null) {
    await precacheImage(provider, context);
  }
}

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

  /// Picker style (feedback sheet): neutral tile, no shadow. The parent picker
  /// tile communicates selection without clipping the image.
  final bool plain;

  Color get _tileColor => switch (type) {
    ClothingIconType.top => KisouTheme.topBlue,
    ClothingIconType.bottom => KisouTheme.bottomSand,
    ClothingIconType.outer => KisouTheme.outerOrange,
  };

  @override
  Widget build(BuildContext context) {
    final label = _displayName;
    final imageProvider = clothingIconImageProvider(
      context: context,
      code: code,
      type: type,
      size: size,
    );
    final radius = size * 0.30;
    final largeText = usesLargeText(context);
    final effectiveWidth = largeText && showLabel
        ? math.max(size, 132).toDouble()
        : size;
    return SizedBox(
      width: effectiveWidth,
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
                  ? null
                  : (selected
                        ? Border.all(color: context.kisou.accent, width: 3)
                        : null),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageProvider != null
                ? Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
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
              maxLines: largeText ? null : 2,
              overflow: largeText
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: size >= 72 ? 13 : 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? context.kisou.accent : context.kisou.softInk,
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
        ClothingTop.fromCode(code)?.displayName ?? AppStrings.unknownClothing,
      ClothingIconType.bottom =>
        ClothingBottom.fromCode(code)?.displayName ??
            AppStrings.unknownClothing,
      ClothingIconType.outer =>
        code == null
            ? AppStrings.noOuter
            : ClothingOuter.fromCode(code)?.displayName ??
                  AppStrings.unknownClothing,
    };
  }
}
