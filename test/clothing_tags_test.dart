import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/clothing_tags.dart';

void main() {
  test('converts top clothing codes', () {
    expect(ClothingTop.fromCode('SHORT_SLEEVE'), ClothingTop.shortSleeve);
    expect(ClothingTop.shortSleeve.displayName, '半袖');
    expect(ClothingTop.fromCode('SHIRT'), isNull);
  });

  test('converts outer clothing codes', () {
    expect(ClothingOuter.fromCode('LIGHT_OUTER'), ClothingOuter.lightOuter);
    expect(ClothingOuter.lightOuter.displayName, '薄手の羽織り');
    expect(ClothingOuter.fromCode(null), isNull);
  });
}
