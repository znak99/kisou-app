enum ClothingTop {
  sleeveless(
    apiCode: 'SLEEVELESS',
    displayName: 'タンクトップ',
    iconAssetPath: 'assets/icons/top_sleeveless.svg',
  ),
  shortSleeve(
    apiCode: 'SHORT_SLEEVE',
    displayName: '半袖',
    iconAssetPath: 'assets/icons/top_short_sleeve.svg',
  ),
  thinLong(
    apiCode: 'THIN_LONG',
    displayName: '薄手の長袖',
    iconAssetPath: 'assets/icons/top_thin_long.svg',
  ),
  longSleeve(
    apiCode: 'LONG_SLEEVE',
    displayName: '長袖',
    iconAssetPath: 'assets/icons/top_long_sleeve.svg',
  ),
  thickLong(
    apiCode: 'THICK_LONG',
    displayName: '厚手の長袖',
    iconAssetPath: 'assets/icons/top_thick_long.svg',
  ),
  knitSweat(
    apiCode: 'KNIT_SWEAT',
    displayName: 'ニット・スウェット',
    iconAssetPath: 'assets/icons/top_knit_sweat.svg',
  );

  const ClothingTop({
    required this.apiCode,
    required this.displayName,
    required this.iconAssetPath,
  });

  final String apiCode;
  final String displayName;
  final String iconAssetPath;

  static ClothingTop? fromCode(String? code) {
    for (final tag in values) {
      if (tag.apiCode == code) {
        return tag;
      }
    }
    return null;
  }
}

enum ClothingBottom {
  longPants(
    apiCode: 'LONG_PANTS',
    displayName: '長ズボン',
    iconAssetPath: 'assets/icons/bottom_long_pants.svg',
  ),
  halfPants(
    apiCode: 'HALF_PANTS',
    displayName: 'ハーフパンツ',
    iconAssetPath: 'assets/icons/bottom_half_pants.svg',
  ),
  shortPants(
    apiCode: 'SHORT_PANTS',
    displayName: 'ショートパンツ',
    iconAssetPath: 'assets/icons/bottom_short_pants.svg',
  ),
  skirt(
    apiCode: 'SKIRT',
    displayName: 'スカート',
    iconAssetPath: 'assets/icons/bottom_skirt.svg',
  );

  const ClothingBottom({
    required this.apiCode,
    required this.displayName,
    required this.iconAssetPath,
  });

  final String apiCode;
  final String displayName;
  final String iconAssetPath;

  static ClothingBottom? fromCode(String? code) {
    for (final tag in values) {
      if (tag.apiCode == code) {
        return tag;
      }
    }
    return null;
  }
}

enum ClothingOuter {
  lightOuter(
    apiCode: 'LIGHT_OUTER',
    displayName: '薄手の羽織り',
    iconAssetPath: 'assets/icons/outer_light_outer.svg',
  ),
  cardigan(
    apiCode: 'CARDIGAN',
    displayName: 'カーディガン',
    iconAssetPath: 'assets/icons/outer_cardigan.svg',
  ),
  jacket(
    apiCode: 'JACKET',
    displayName: 'ジャケット',
    iconAssetPath: 'assets/icons/outer_jacket.svg',
  ),
  coat(
    apiCode: 'COAT',
    displayName: 'コート',
    iconAssetPath: 'assets/icons/outer_coat.svg',
  ),
  padding(
    apiCode: 'PADDING',
    displayName: 'ダウン',
    iconAssetPath: 'assets/icons/outer_padding.svg',
  );

  const ClothingOuter({
    required this.apiCode,
    required this.displayName,
    required this.iconAssetPath,
  });

  final String apiCode;
  final String displayName;
  final String iconAssetPath;

  static ClothingOuter? fromCode(String? code) {
    for (final tag in values) {
      if (tag.apiCode == code) {
        return tag;
      }
    }
    return null;
  }
}

extension NullableClothingOuterLabel on ClothingOuter? {
  String get displayName => this?.displayName ?? 'なし';
  String? get iconAssetPath => this?.iconAssetPath;
  String? get apiCode => this?.apiCode;
}
