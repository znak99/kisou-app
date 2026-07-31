import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/ad_config.dart';

void main() {
  const liveAndroid = AdUnitIds(
    appId: 'ca-app-pub-1234567890123456~1234567890',
    bannerId: 'ca-app-pub-1234567890123456/1234567890',
    rewardedId: 'ca-app-pub-1234567890123456/0987654321',
  );
  const liveIos = AdUnitIds(
    appId: 'ca-app-pub-6543210987654321~1234567890',
    bannerId: 'ca-app-pub-6543210987654321/1234567890',
    rewardedId: 'ca-app-pub-6543210987654321/0987654321',
  );

  test('ads are disabled unless ADS_ENABLED is explicitly supplied', () {
    expect(AdConfig.enabled, isFalse);
  });

  test('development uses the current official Google sample IDs', () {
    expect(
      AdConfig.androidSamples.bannerId,
      'ca-app-pub-3940256099942544/9214589741',
    );
    expect(
      AdConfig.iosSamples.bannerId,
      'ca-app-pub-3940256099942544/2435281174',
    );
    expect(
      AdConfig.androidSamples.rewardedId,
      'ca-app-pub-3940256099942544/5224354917',
    );
    expect(
      AdConfig.iosSamples.rewardedId,
      'ca-app-pub-3940256099942544/1712485313',
    );
  });

  test('production accepts complete live identifiers', () {
    expect(
      () => validateAdConfiguration(
        enabled: true,
        supportedPlatform: true,
        isDevelopment: false,
        androidIds: liveAndroid,
        iosIds: liveIos,
      ),
      returnsNormally,
    );
  });

  test('production rejects missing, malformed, and sample identifiers', () {
    for (final invalid in [
      const AdUnitIds(appId: '', bannerId: '', rewardedId: ''),
      const AdUnitIds(
        appId: 'ca-app-pub-invalid',
        bannerId: 'ca-app-pub-invalid',
        rewardedId: 'ca-app-pub-invalid',
      ),
      AdConfig.androidSamples,
    ]) {
      expect(
        () => validateAdConfiguration(
          enabled: true,
          supportedPlatform: true,
          isDevelopment: false,
          androidIds: invalid,
          iosIds: liveIos,
        ),
        throwsStateError,
      );
    }
  });

  test(
    'disabled builds ignore IDs and enabled non-mobile builds fail closed',
    () {
      const empty = AdUnitIds(appId: '', bannerId: '', rewardedId: '');
      expect(
        () => validateAdConfiguration(
          enabled: false,
          supportedPlatform: false,
          isDevelopment: false,
          androidIds: empty,
          iosIds: empty,
        ),
        returnsNormally,
      );
      expect(
        () => validateAdConfiguration(
          enabled: true,
          supportedPlatform: false,
          isDevelopment: true,
          androidIds: empty,
          iosIds: empty,
        ),
        throwsStateError,
      );
    },
  );
}
