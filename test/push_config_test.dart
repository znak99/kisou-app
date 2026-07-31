import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/push_config.dart';

void main() {
  const apiKey = 'AIzaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  const senderId = '123456789012';
  const projectId = 'kisou-push-prod';
  const androidAppId = '1:123456789012:android:0123456789abcdef';
  const iosAppId = '1:123456789012:ios:0123456789abcdef';

  test('push feature flag accepts only exact booleans', () {
    expect(parsePushEnabled('true'), isTrue);
    expect(parsePushEnabled('false'), isFalse);
    expect(() => parsePushEnabled('TRUE'), throwsStateError);
    expect(() => parsePushEnabled('1'), throwsStateError);
    expect(() => parsePushEnabled(''), throwsStateError);
  });

  test(
    'disabled runtime cannot resolve Firebase unless cleaning old state',
    () {
      FirebaseOptions Function() optionsFactory({
        bool allowDisabledCleanup = false,
      }) {
        return () => resolvePushFirebaseOptions(
          enabled: false,
          allowDisabledCleanup: allowDisabledCleanup,
          platform: KisouPushPlatform.android,
          apiKey: apiKey,
          appId: androidAppId,
          messagingSenderId: senderId,
          projectId: projectId,
          iosBundleId: null,
          environment: 'production',
        );
      }

      expect(optionsFactory(), throwsStateError);
      final cleanupOptions = optionsFactory(allowDisabledCleanup: true)();
      expect(cleanupOptions.appId, androidAppId);
      expect(cleanupOptions.messagingSenderId, senderId);
    },
  );

  test('Firebase identifiers must match platform and environment', () {
    expect(
      () => resolvePushFirebaseOptions(
        enabled: true,
        platform: KisouPushPlatform.android,
        apiKey: apiKey,
        appId: iosAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: null,
        environment: 'production',
      ),
      throwsStateError,
    );
    expect(
      () => resolvePushFirebaseOptions(
        enabled: true,
        platform: KisouPushPlatform.ios,
        apiKey: apiKey,
        appId: iosAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: 'cloud.znak99.kisou',
        environment: 'development',
      ),
      throwsStateError,
    );
    final options = resolvePushFirebaseOptions(
      enabled: true,
      platform: KisouPushPlatform.ios,
      apiKey: apiKey,
      appId: iosAppId,
      messagingSenderId: senderId,
      projectId: projectId,
      iosBundleId: 'cloud.znak99.kisou.dev',
      environment: 'development',
    );
    expect(options.iosBundleId, 'cloud.znak99.kisou.dev');
  });

  test('malformed Firebase identifiers fail closed', () {
    expect(
      () => resolvePushFirebaseOptions(
        enabled: true,
        platform: KisouPushPlatform.android,
        apiKey: 'secret',
        appId: androidAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: null,
        environment: 'production',
      ),
      throwsStateError,
    );
    expect(
      () => resolvePushFirebaseOptions(
        enabled: true,
        platform: KisouPushPlatform.android,
        apiKey: apiKey,
        appId: androidAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: null,
        environment: 'staging',
      ),
      throwsStateError,
    );
  });
}
