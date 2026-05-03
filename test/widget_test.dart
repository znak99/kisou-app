import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kisou_app/app.dart';
import 'package:kisou_app/providers/api_provider.dart';

void main() {
  testWidgets('shows temporary app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiHealthCheckEnabledProvider.overrideWithValue(false)],
        child: const KisouApp(),
      ),
    );

    expect(find.text('キソウ'), findsOneWidget);
  });
}
