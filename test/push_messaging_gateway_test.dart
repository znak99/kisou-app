import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/services/push_messaging_gateway.dart';

void main() {
  test(
    'platform cleanup disables auto-init, deletes token, then deletes FID',
    () async {
      final events = <String>[];

      await performPushPlatformCleanup(
        disableAutoInit: () async => events.add('auto-init:false'),
        deleteMessagingToken: () async => events.add('token:delete'),
        deleteFirebaseInstallation: () async => events.add('fid:delete'),
      );

      expect(events, ['auto-init:false', 'token:delete', 'fid:delete']);
    },
  );

  test(
    'platform cleanup stops and remains failed at every incomplete stage',
    () async {
      for (final failingStage in [0, 1, 2]) {
        final events = <int>[];

        await expectLater(
          performPushPlatformCleanup(
            disableAutoInit: () => _stage(events, 0, failingStage),
            deleteMessagingToken: () => _stage(events, 1, failingStage),
            deleteFirebaseInstallation: () => _stage(events, 2, failingStage),
          ),
          throwsStateError,
        );

        expect(events, List<int>.generate(failingStage + 1, (index) => index));
      }
    },
  );

  test('disabled gateway refuses to claim platform identity cleanup', () {
    expect(
      () => const DisabledPushMessagingGateway().disableAndDeleteToken(),
      throwsA(isA<PushPlatformCleanupUnavailableException>()),
    );
  });
}

Future<void> _stage(List<int> events, int stage, int failingStage) async {
  events.add(stage);
  if (stage == failingStage) {
    throw StateError('stage failed');
  }
}
