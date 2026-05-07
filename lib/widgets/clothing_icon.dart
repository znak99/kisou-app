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
  });

  final String? code;
  final ClothingIconType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = _displayName;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              border: Border.all(color: KisouTheme.mistGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: size >= 72 ? 14 : 12,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: size >= 72 ? 13 : 12,
              height: 1.25,
            ),
          ),
        ],
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
}
