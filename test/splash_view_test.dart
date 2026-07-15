import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/screens/splash_view.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: KisouTheme.light(), home: child);

void main() {
  testWidgets('로고만 보이고 메시지는 숨겨져 있다', (tester) async {
    await tester.pumpWidget(_host(const SplashView()));
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(2)); // 이미지 로고 + 워드마크
    expect(find.text(AppStrings.splashLoading), findsNothing);
  });

  testWidgets('showMessage 면 상태 문구가 보인다', (tester) async {
    await tester.pumpWidget(_host(const SplashView(showMessage: true)));
    await tester.pump();

    expect(find.text(AppStrings.splashLoading), findsOneWidget);
  });

  testWidgets('점이 1→2→3→2 로 순환한다', (tester) async {
    await tester.pumpWidget(_host(const SplashView(showMessage: true)));
    await tester.pump();

    String dots() {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>();
      return texts.firstWhere((t) => t.isNotEmpty && RegExp(r'^\.+$').hasMatch(t));
    }

    final seen = <String>[dots()];
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      seen.add(dots());
    }
    expect(seen, ['.', '..', '...', '..']);

    // 한 바퀴 더 돌면 처음으로 되돌아온다.
    await tester.pump(const Duration(milliseconds: 400));
    expect(dots(), '.');
  });

  testWidgets('메시지가 꺼지면 타이머가 정리된다(프레임 예약 없음)', (tester) async {
    await tester.pumpWidget(_host(const SplashView(showMessage: true)));
    await tester.pump();
    await tester.pumpWidget(_host(const SplashView()));
    // 타이머가 살아있으면 pumpAndSettle 이 끝나지 않는다.
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.splashLoading), findsNothing);
  });
}
