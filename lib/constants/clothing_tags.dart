enum ClothingTop {
  sleeveless(
    apiCode: 'SLEEVELESS',
    displayName: 'タンクトップ',
    iconAssetPath: 'assets/icons/top_sleeveless.png',
  ),
  shortSleeve(
    apiCode: 'SHORT_SLEEVE',
    displayName: '半袖',
    iconAssetPath: 'assets/icons/top_short_sleeve.png',
  ),
  thinLong(
    apiCode: 'THIN_LONG',
    displayName: '薄手の長袖',
    iconAssetPath: 'assets/icons/top_thin_long.png',
  ),
  longSleeve(
    apiCode: 'LONG_SLEEVE',
    displayName: '長袖',
    iconAssetPath: 'assets/icons/top_long_sleeve.png',
  ),
  thickLong(
    apiCode: 'THICK_LONG',
    displayName: '厚手の長袖',
    iconAssetPath: 'assets/icons/top_thick_long.png',
  ),
  knitSweat(
    apiCode: 'KNIT_SWEAT',
    displayName: 'ニット・スウェット',
    iconAssetPath: 'assets/icons/top_knit_sweat.png',
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
    iconAssetPath: 'assets/icons/bottom_long_pants.png',
  ),
  halfPants(
    apiCode: 'HALF_PANTS',
    displayName: 'ハーフパンツ',
    iconAssetPath: 'assets/icons/bottom_half_pants.png',
  ),
  shortPants(
    apiCode: 'SHORT_PANTS',
    displayName: 'ショートパンツ',
    iconAssetPath: 'assets/icons/bottom_short_pants.png',
  ),
  skirt(
    apiCode: 'SKIRT',
    displayName: 'スカート',
    iconAssetPath: 'assets/icons/bottom_skirt.png',
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
    iconAssetPath: 'assets/icons/outer_light_outer.png',
  ),
  cardigan(
    apiCode: 'CARDIGAN',
    displayName: 'カーディガン',
    iconAssetPath: 'assets/icons/outer_cardigan.png',
  ),
  jacket(
    apiCode: 'JACKET',
    displayName: 'ジャケット',
    iconAssetPath: 'assets/icons/outer_jacket.png',
  ),
  coat(
    apiCode: 'COAT',
    displayName: 'コート',
    iconAssetPath: 'assets/icons/outer_coat.png',
  ),
  padding(
    apiCode: 'PADDING',
    displayName: 'ダウン',
    iconAssetPath: 'assets/icons/outer_padding.png',
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

const String outerNoneIconAssetPath = 'assets/icons/outer_none.png';

extension NullableClothingOuterLabel on ClothingOuter? {
  String get displayName => this?.displayName ?? 'なし';
  String get iconAssetPath => this?.iconAssetPath ?? outerNoneIconAssetPath;
  String? get apiCode => this?.apiCode;
}
