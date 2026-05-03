import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kisou_app/app.dart';

void main() {
  testWidgets('shows temporary app title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KisouApp()));

    expect(find.text('キソウ'), findsOneWidget);
  });
}
