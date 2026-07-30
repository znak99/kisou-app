import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/widgets/clothing_icon.dart';

void main() {
  test('bundled clothing variants stay complete and under 5 MiB', () {
    final files = Directory('assets/icons')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .toList(growable: false);
    final bytes = files.fold<int>(0, (sum, file) => sum + file.lengthSync());

    expect(files, hasLength(64));
    expect(bytes, lessThan(5 * 1024 * 1024));
    expect(
      Directory(
        'design_assets/clothing_icons_master',
      ).listSync().whereType<File>(),
      hasLength(16),
    );
  });

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

  testWidgets(
    'decodes the resolution-aware asset at its displayed pixel size',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      ImageProvider<Object>? provider;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              provider = clothingIconImageProvider(
                context: context,
                code: 'SHORT_SLEEVE',
                type: ClothingIconType.top,
                size: 84,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(provider, isA<ResizeImage>());
      final resized = provider! as ResizeImage;
      expect(resized.width, 252);
      expect(resized.imageProvider, isA<AssetImage>());
    },
  );
}
