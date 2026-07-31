import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final buildScript = File(
    'scripts/build_android_release.sh',
  ).readAsStringSync();
  final verifyScript = File(
    'scripts/verify_android_release.sh',
  ).readAsStringSync();
  final workflow = File('.github/workflows/ci.yml').readAsStringSync();
  final gitignore = File('.gitignore').readAsStringSync();
  final adConfig = File('lib/config/ad_config.dart').readAsStringSync();
  final forecastScreen = File(
    'lib/screens/forecast/forecast_screen.dart',
  ).readAsStringSync();
  final rootShell = File('lib/screens/root_shell.dart').readAsStringSync();
  final outlookScreen = File(
    'lib/screens/forecast/outlook_screen.dart',
  ).readAsStringSync();

  test('Android release never falls back to debug signing', () {
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gradle, contains('Release signing is not configured.'));
    expect(gradle, contains('KISOU_ANDROID_KEYSTORE_PATH'));
    expect(gradle, contains('KISOU_ANDROID_KEYSTORE_PASSWORD'));
    expect(gradle, contains('KISOU_ANDROID_KEY_ALIAS'));
    expect(gradle, contains('KISOU_ANDROID_KEY_PASSWORD'));
    expect(gradle, contains('KISOU_ANDROID_KEY_PROPERTIES_PATH'));
    expect(gradle, contains('must be an absolute path'));
    expect(gradle, isNot(contains('value?.trim()')));
    expect(gradle, contains('gradle.taskGraph.whenReady'));
    expect(buildScript, contains('normalized_owner_certificate_sha256'));
    expect(
      buildScript,
      contains('Owner signing and ephemeral signing cannot be requested'),
    );
  });

  test('CI explicitly opts into a non-distributable ephemeral key', () {
    expect(workflow, contains('KISOU_ALLOW_EPHEMERAL_SIGNING: "1"'));
    expect(workflow, contains('persist-credentials: false'));
    expect(workflow, contains('distribution: temurin'));
    expect(workflow, contains('java-version: "17"'));
    expect(workflow, isNot(matches(RegExp(r'uses:\s+\S+@v\d'))));
    expect(
      RegExp(r'uses:\s+\S+@[0-9a-f]{40}').allMatches(workflow),
      hasLength(3),
    );
    expect(buildScript, contains('EPHEMERAL-NOT-FOR-STORE.aab'));
    expect(buildScript, contains('CN=KISOU EPHEMERAL VERIFY ONLY'));
    expect(buildScript, contains('scripts/verify_android_release.sh'));
    expect(buildScript, contains('GITHUB_ACTIONS'));
    expect(buildScript, contains('expected_certificate_sha256'));
    expect(buildScript, contains('keep_owner_artifact'));
    expect(buildScript, contains('release_build_started'));
  });

  test('release verification rejects debug and development artifacts', () {
    expect(verifyScript, contains('CN=Android Debug'));
    expect(verifyScript, contains('cloud.znak99.kisou.dev'));
    expect(verifyScript, contains('http://127.0.0.1'));
    expect(verifyScript, contains('dev-test-user'));
    expect(verifyScript, contains('https://kisou.znak99.cloud'));
    expect(verifyScript, contains('pinned certificate'));
    expect(verifyScript, contains('unsigned entries'));
  });

  test('advertising is opt-in and uses the completed runtime surfaces', () {
    expect(adConfig, contains("'ADS_ENABLED'"));
    expect(adConfig, contains('defaultValue: false'));
    expect(adConfig, contains('!ApiConfig.outlookScreenshotFixtureEnabled'));
    expect(forecastScreen, contains('ForecastInlineBanner()'));
    expect(outlookScreen, contains('ref.watch(adRewardProvider)'));
    expect(rootShell, isNot(contains('AdSlot')));
  });

  test('owner signing material is excluded from version control', () {
    expect(gitignore, contains('/android/key.properties'));
    expect(gitignore, contains('*.jks'));
    expect(gitignore, contains('*.keystore'));
    expect(gitignore, contains('*.p12'));
    expect(gitignore, contains('*.pfx'));
    expect(gitignore, contains('*.pkcs12'));
  });
}
