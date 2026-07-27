import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/widgets/clothing_icon.dart';

void main() {
  testWidgets('unknown clothing codes never leak raw API values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ClothingIcon(code: 'UNKNOWN_TOP', type: ClothingIconType.top),
              ClothingIcon(
                code: 'UNKNOWN_BOTTOM',
                type: ClothingIconType.bottom,
              ),
              ClothingIcon(code: 'UNKNOWN_OUTER', type: ClothingIconType.outer),
            ],
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.unknownClothing), findsNWidgets(6));
    expect(find.textContaining('UNKNOWN_'), findsNothing);
    expect(find.text(AppStrings.noOuter), findsNothing);
  });

  testWidgets('a genuinely absent outer is still shown as none', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClothingIcon(code: null, type: ClothingIconType.outer),
        ),
      ),
    );

    expect(find.text(AppStrings.noOuter), findsOneWidget);
    expect(find.text(AppStrings.unknownClothing), findsNothing);
  });
}
