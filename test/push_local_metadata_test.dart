import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/models/push_notification.dart';
import 'package:kisou_app/services/push_local_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'foreground action reserves once and completes only after navigation',
    () async {
      final store = PushDeliveryReceiptStore();
      final intent = _intent(1);

      expect(await store.markForegroundIfNew(intent), isTrue);
      expect(await store.markForegroundIfNew(intent), isFalse);
      expect(await store.reserveNavigation(intent), isTrue);
      expect(await store.reserveNavigation(intent), isFalse);
      expect(await store.pendingNavigations(), hasLength(1));

      await store.completeNavigation(intent.deliveryId);
      expect(await store.pendingNavigations(), isEmpty);
      expect(await store.reserveNavigation(intent), isFalse);
    },
  );

  test(
    'pending navigation survives process recreation with its revision',
    () async {
      final intent = _intent(7);
      await PushDeliveryReceiptStore().reserveNavigation(intent);

      final recovered = await PushDeliveryReceiptStore().pendingNavigations();

      expect(recovered, hasLength(1));
      expect(recovered.single.deliveryId, intent.deliveryId);
      expect(recovered.single.type, intent.type);
      expect(recovered.single.clientRevision, 7);
    },
  );

  test('account boundary terminally discards unfinished deliveries', () async {
    final store = PushDeliveryReceiptStore();
    final foreground = _intent(3);
    final pending = _intent(4);
    await store.markForegroundIfNew(foreground);
    await store.reserveNavigation(pending);

    await store.discardUnfinished();

    expect(await store.pendingNavigations(), isEmpty);
    expect(await store.reserveNavigation(foreground), isFalse);
    expect(await store.reserveNavigation(pending), isFalse);
  });

  test('same delivery ID with a different revision fails closed', () async {
    final store = PushDeliveryReceiptStore();
    final original = _intent(5);
    await store.markForegroundIfNew(original);

    await expectLater(
      store.reserveNavigation(
        PushNotificationIntent(
          type: original.type,
          deliveryId: original.deliveryId,
          clientRevision: 6,
        ),
      ),
      throwsA(isA<PushDeliveryReceiptReadException>()),
    );
  });

  test('receipt history is bounded to the latest 64 deliveries', () async {
    final store = PushDeliveryReceiptStore();
    for (var index = 0; index < 65; index++) {
      final intent = _intent(index + 1);
      await store.reserveNavigation(intent);
      await store.completeNavigation(intent.deliveryId);
    }

    final preferences = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(preferences.getString(pushDeliveryReceiptStorageKey)!)
            as Map<String, dynamic>;
    expect(decoded['version'], 3);
    expect(decoded['receipts'], hasLength(64));
    expect(await store.reserveNavigation(_intent(1)), isTrue);
  });

  test('corrupt receipt state never routes', () async {
    SharedPreferences.setMockInitialValues({
      pushDeliveryReceiptStorageKey: '{corrupt',
    });

    await expectLater(
      PushDeliveryReceiptStore().pendingNavigations(),
      throwsA(isA<PushDeliveryReceiptReadException>()),
    );
  });

  test('account boundary resets corrupt receipt state', () async {
    SharedPreferences.setMockInitialValues({
      pushDeliveryReceiptStorageKey: '{corrupt',
    });
    final store = PushDeliveryReceiptStore();

    await store.discardUnfinishedAtAccountBoundary();

    expect(await store.pendingNavigations(), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(pushDeliveryReceiptStorageKey), isFalse);
  });
}

PushNotificationIntent _intent(int revision) {
  final suffix = revision.toRadixString(16).padLeft(12, '0');
  return PushNotificationIntent(
    type: revision.isEven
        ? PushNotificationType.morningRecommendation
        : PushNotificationType.eveningFeedback,
    deliveryId: '00000000-0000-4000-8000-$suffix',
    clientRevision: revision,
  );
}
