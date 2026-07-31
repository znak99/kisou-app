import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _androidSampleAppId = 'ca-app-pub-3940256099942544~3347511713';
const _iosSampleAppId = 'ca-app-pub-3940256099942544~1458002511';
const _liveAndroidAppId = 'ca-app-pub-1234567890123456~1234567890';
const _liveIosAppId = 'ca-app-pub-9876543210987654~0987654321';
const _liveAndroidBannerId = 'ca-app-pub-1234567890123456/1111111111';
const _liveAndroidRewardedId = 'ca-app-pub-1234567890123456/2222222222';
const _liveIosBannerId = 'ca-app-pub-9876543210987654/3333333333';
const _liveIosRewardedId = 'ca-app-pub-9876543210987654/4444444444';

const _skAdNetworkIds = [
  'cstr6suwn9.skadnetwork',
  '4fzdc2evr5.skadnetwork',
  '2fnua5tdw4.skadnetwork',
  'ydx93a7ass.skadnetwork',
  'p78axxw29g.skadnetwork',
  'v72qych5uu.skadnetwork',
  'ludvb6z3bs.skadnetwork',
  'cp8zw746q7.skadnetwork',
  '3sh42y64q3.skadnetwork',
  'c6k4g5qg8m.skadnetwork',
  's39g8k73mm.skadnetwork',
  'wg4vff78zm.skadnetwork',
  '3qy4746246.skadnetwork',
  'f38h382jlk.skadnetwork',
  'hs6bdukanm.skadnetwork',
  'mlmmfzh3r3.skadnetwork',
  'v4nxqhlyqp.skadnetwork',
  'wzmmz9fp6w.skadnetwork',
  'su67r6k2v3.skadnetwork',
  'yclnxrl5pm.skadnetwork',
  't38b2kh725.skadnetwork',
  '7ug5zh24hu.skadnetwork',
  'gta9lk7p23.skadnetwork',
  'vutu7akeur.skadnetwork',
  'y5ghdn5j9k.skadnetwork',
  'v9wttpbfk9.skadnetwork',
  'n38lu8286q.skadnetwork',
  '47vhws6wlr.skadnetwork',
  'kbd757ywx3.skadnetwork',
  '9t245vhmpl.skadnetwork',
  'a2p9lx4jpn.skadnetwork',
  '22mmun2rn5.skadnetwork',
  '44jx6755aq.skadnetwork',
  'k674qkevps.skadnetwork',
  '4468km3ulz.skadnetwork',
  '2u9pt9hc89.skadnetwork',
  '8s468mfl3y.skadnetwork',
  'klf5c3l5u5.skadnetwork',
  'ppxm28t8ap.skadnetwork',
  'kbmxgpxpgc.skadnetwork',
  'uw77j35x4d.skadnetwork',
  '578prtvx9j.skadnetwork',
  '4dzt52r2t5.skadnetwork',
  'tl55sbb4fm.skadnetwork',
  'c3frkrj4fj.skadnetwork',
  'e5fvkxwrpn.skadnetwork',
  '8c4e2ghe7u.skadnetwork',
  '3rd42ekr43.skadnetwork',
  '97r2b46745.skadnetwork',
  '3qcr597p9d.skadnetwork',
];

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final dartConfig = File('lib/config/ad_config.dart').readAsStringSync();
  final xcodeProject = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final iosScriptFile = File('ios/scripts/configure_admob.sh');
  final iosScript = iosScriptFile.readAsStringSync();

  test(
    'Dart and Android native configuration share a fail-closed contract',
    () {
      expect(dartConfig, contains("'ADS_ENABLED'"));
      expect(dartConfig, contains("'ADMOB_ANDROID_APP_ID'"));
      expect(dartConfig, contains("'ADMOB_ANDROID_BANNER_ID'"));
      expect(dartConfig, contains("'ADMOB_ANDROID_REWARDED_ID'"));
      expect(dartConfig, contains("'ADMOB_IOS_APP_ID'"));
      expect(dartConfig, contains("'ADMOB_IOS_BANNER_ID'"));
      expect(dartConfig, contains("'ADMOB_IOS_REWARDED_ID'"));
      expect(dartConfig, contains('defaultValue: false'));

      expect(gradle, contains('providers.gradleProperty("dart-defines")'));
      expect(gradle, contains('environmentVariable("DART_DEFINES")'));
      expect(gradle, contains('Base64.getDecoder().decode(encodedEntry)'));
      expect(gradle, contains('Base64.getEncoder().encodeToString(bytes)'));
      expect(gradle, contains('contains a duplicate key'));
      expect(gradle, contains('Gradle property and DART_DEFINES'));
      expect(gradle, contains('ADS_ENABLED must be exactly true or false'));
      expect(gradle, contains('ADMOB_ANDROID_APP_ID must be a live'));
      expect(gradle, contains('ADMOB_IOS_APP_ID must be a live'));
      expect(gradle, contains('ADMOB_ANDROID_BANNER_ID'));
      expect(gradle, contains('ADMOB_ANDROID_REWARDED_ID'));
      expect(gradle, contains('ADMOB_IOS_BANNER_ID'));
      expect(gradle, contains('ADMOB_IOS_REWARDED_ID'));
      expect(gradle, contains('isLiveAdMobAdUnitId'));
      expect(gradle, contains('validateDevAdMobConfig'));
      expect(gradle, contains('validateProdAdMobConfig'));
      expect(
        gradle,
        contains(r'^process(Dev|Prod)(Debug|Profile|Release)MainManifest$'),
      );
      expect(gradle, isNot(contains('name.startsWith("preDev")')));
      expect(gradle, isNot(contains('name.startsWith("preProd")')));
      expect(gradle, contains(_androidSampleAppId));
      expect(gradle, contains('selectedAndroidProductionAppId'));
      expect(
        RegExp(r'ca-app-pub-\[0-9\]\{16\}~\[0-9\]\{10\}').hasMatch(gradle),
        isTrue,
      );
    },
  );

  test('Android manifest removes AD_ID and delays measurement', () {
    expect(
      manifest,
      contains('xmlns:tools="http://schemas.android.com/tools"'),
    );
    expect(
      _occurrences(
        manifest,
        'android:name="com.google.android.gms.ads.APPLICATION_ID"',
      ),
      1,
    );
    expect(manifest, contains('android:value="@string/admob_app_id"'));
    expect(
      _occurrences(
        manifest,
        'android:name="com.google.android.gms.ads.'
        'DELAY_APP_MEASUREMENT_INIT"',
      ),
      1,
    );
    expect(
      RegExp(
        r'com\.google\.android\.gms\.permission\.AD_ID"'
        r'\s+tools:node="remove"',
      ).hasMatch(manifest),
      isTrue,
    );
    for (final permission in [
      'android.permission.ACCESS_ADSERVICES_AD_ID',
      'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
      'android.permission.ACCESS_ADSERVICES_TOPICS',
    ]) {
      expect(
        RegExp(
          '${RegExp.escape(permission)}"\\s+tools:node="remove"',
        ).hasMatch(manifest),
        isTrue,
      );
    }

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, contains('android:allowBackup="false"'));
  });

  for (final entry in {
    'development': 'ios/Runner/Info-Dev.plist',
    'production fallback': 'ios/Runner/Info.plist',
  }.entries) {
    test('${entry.key} plist has the exact current SKAdNetwork contract', () {
      final plist = File(entry.value).readAsStringSync();
      expect(_occurrences(plist, '<key>GADApplicationIdentifier</key>'), 1);
      expect(_occurrences(plist, '<string>$_iosSampleAppId</string>'), 1);
      expect(_occurrences(plist, '<key>GADDelayAppMeasurementInit</key>'), 1);
      expect(
        RegExp(
          r'<key>GADDelayAppMeasurementInit</key>\s*<true/>',
        ).hasMatch(plist),
        isTrue,
      );
      expect(_occurrences(plist, '<key>SKAdNetworkItems</key>'), 1);

      final actualIds = RegExp(
        r'<key>SKAdNetworkIdentifier</key>\s*'
        r'<string>([^<]+)</string>',
      ).allMatches(plist).map((match) => match.group(1)!).toList();
      expect(actualIds, _skAdNetworkIds);
      expect(actualIds, hasLength(50));
      expect(actualIds.toSet(), hasLength(50));
      expect(actualIds.first, 'cstr6suwn9.skadnetwork');
      expect(actualIds.last, '3qcr597p9d.skadnetwork');
      expect(plist, isNot(contains('NSUserTrackingUsageDescription')));
      expect(plist, isNot(contains('ATTrackingManager')));
    });
  }

  test('Xcode runs the non-logging App ID phase after packaging', () {
    expect(
      _occurrences(
        xcodeProject,
        'A5D400000000000000000001 /* '
        '[KISOU] Configure AdMob App ID */',
      ),
      2,
    );
    expect(
      xcodeProject.indexOf(
        'B4A5CFF4E4A49B4F111A9BC2 /* [CP] Copy Pods Resources */',
      ),
      lessThan(
        xcodeProject.indexOf(
          'A5D400000000000000000001 /* '
          '[KISOU] Configure AdMob App ID */',
        ),
      ),
    );
    expect(
      xcodeProject,
      contains(r'/bin/sh \"${PROJECT_DIR}/scripts/configure_admob.sh\"'),
    );
    expect(xcodeProject, contains('showEnvVarsInLog = 0;'));
    expect(iosScriptFile.statSync().mode & 0x49, 0x49);
  });

  test('iOS build script decodes once and never uses unsafe evaluation', () {
    expect(_occurrences(iosScript, '/usr/bin/base64 -D'), 1);
    expect(iosScript, contains('DART_DEFINES contains a duplicate key'));
    expect(iosScript, contains('ADS_ENABLED must be exactly true or false'));
    expect(iosScript, contains('ADMOB_ANDROID_APP_ID'));
    expect(iosScript, contains('ADMOB_ANDROID_BANNER_ID'));
    expect(iosScript, contains('ADMOB_ANDROID_REWARDED_ID'));
    expect(iosScript, contains('ADMOB_IOS_APP_ID'));
    expect(iosScript, contains('ADMOB_IOS_BANNER_ID'));
    expect(iosScript, contains('ADMOB_IOS_REWARDED_ID'));
    expect(iosScript, contains('canonical base64 encoding'));
    expect(iosScript, contains('entries must use valid UTF-8'));
    expect(iosScript, contains('must not contain control characters'));
    expect(iosScript, contains(r'selected_app_id=$google_sample_ios_app_id'));
    expect(iosScript, contains(r'selected_app_id=$ios_app_id'));
    expect(iosScript, contains('-replace GADApplicationIdentifier'));
    expect(iosScript, contains('-extract GADApplicationIdentifier'));
    expect(iosScript, contains('-extract GADDelayAppMeasurementInit'));
    expect(iosScript, isNot(contains('eval ')));
    expect(iosScript, isNot(contains('set -x')));
    expect(iosScript, isNot(contains('env |')));
    expect(iosScript, isNot(contains('printenv')));
  });

  group('iOS build-time validation', () {
    test('development always accepts the official sample fallback', () async {
      final result = await _validateIos(
        configuration: 'Debug-dev',
        defines: {
          'ADS_ENABLED': 'true',
          'APP_ENV': 'development',
          'ADMOB_ANDROID_APP_ID': '',
          'ADMOB_IOS_APP_ID': 'ignored-in-development',
        },
      );
      expect(result.exitCode, 0, reason: result.stderr as String);
    });

    test('disabled production accepts the official sample fallback', () async {
      final result = await _validateIos(
        configuration: 'Release-prod',
        defines: const {},
      );
      expect(result.exitCode, 0, reason: result.stderr as String);
    });

    test('documented define files accept UTF-8 metadata', () async {
      for (final entry in {
        'Debug-dev': 'config/dev.json',
        'Release-prod': 'config/prod.json',
      }.entries) {
        final defines = _readDartDefines(entry.value);
        expect(defines['_comment'], matches(RegExp(r'[가-힣]')));

        final result = await _validateIos(
          configuration: entry.key,
          defines: defines,
        );
        expect(result.exitCode, 0, reason: result.stderr as String);
      }
    });

    test('enabled production accepts all valid live ad identifiers', () async {
      final result = await _validateIos(
        configuration: 'Release-prod',
        defines: const {
          'ADS_ENABLED': 'true',
          'APP_ENV': 'production',
          'ADMOB_ANDROID_APP_ID': _liveAndroidAppId,
          'ADMOB_ANDROID_BANNER_ID': _liveAndroidBannerId,
          'ADMOB_ANDROID_REWARDED_ID': _liveAndroidRewardedId,
          'ADMOB_IOS_APP_ID': _liveIosAppId,
          'ADMOB_IOS_BANNER_ID': _liveIosBannerId,
          'ADMOB_IOS_REWARDED_ID': _liveIosRewardedId,
        },
      );
      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
    });

    test(
      'enabled production rejects missing, malformed, and sample IDs',
      () async {
        for (final defines in [
          const {'ADS_ENABLED': 'true', 'APP_ENV': 'production'},
          const {
            'ADS_ENABLED': 'true',
            'APP_ENV': 'production',
            'ADMOB_ANDROID_APP_ID': 'malformed',
            'ADMOB_IOS_APP_ID': _liveIosAppId,
          },
          const {
            'ADS_ENABLED': 'true',
            'APP_ENV': 'production',
            'ADMOB_ANDROID_APP_ID': _liveAndroidAppId,
            'ADMOB_IOS_APP_ID': _iosSampleAppId,
          },
          const {
            'ADS_ENABLED': 'true',
            'APP_ENV': 'production',
            'ADMOB_ANDROID_APP_ID': _liveAndroidAppId,
            'ADMOB_ANDROID_BANNER_ID': _liveAndroidBannerId,
            'ADMOB_ANDROID_REWARDED_ID': _liveAndroidRewardedId,
            'ADMOB_IOS_APP_ID': _liveIosAppId,
            'ADMOB_IOS_BANNER_ID': 'ca-app-pub-3940256099942544/2435281174',
            'ADMOB_IOS_REWARDED_ID': _liveIosRewardedId,
          },
        ]) {
          final result = await _validateIos(
            configuration: 'Release-prod',
            defines: defines,
          );
          expect(result.exitCode, isNot(0));
          expect(result.stderr, isNot(contains(_liveAndroidAppId)));
          expect(result.stderr, isNot(contains(_liveIosAppId)));
          expect(result.stderr, isNot(contains(_liveAndroidBannerId)));
          expect(result.stderr, isNot(contains(_liveAndroidRewardedId)));
          expect(result.stderr, isNot(contains(_liveIosBannerId)));
          expect(result.stderr, isNot(contains(_liveIosRewardedId)));
        }
      },
    );

    test(
      'malformed, duplicate, and mismatched Dart defines fail closed',
      () async {
        final malformed = await _validateIos(
          configuration: 'Release-prod',
          rawDefines: 'not-base64',
        );
        expect(malformed.exitCode, isNot(0));

        final duplicateValue = base64Encode(utf8.encode('ADS_ENABLED=false'));
        final duplicate = await _validateIos(
          configuration: 'Release-prod',
          rawDefines: '$duplicateValue,$duplicateValue',
        );
        expect(duplicate.exitCode, isNot(0));

        final mismatch = await _validateIos(
          configuration: 'Debug-dev',
          defines: const {'APP_ENV': 'production'},
        );
        expect(mismatch.exitCode, isNot(0));

        final nonCanonical = await _validateIos(
          configuration: 'Release-prod',
          rawDefines: 'QUQ9MR==',
        );
        expect(nonCanonical.exitCode, isNot(0));

        final invalidUtf8 = await _validateIos(
          configuration: 'Release-prod',
          rawDefines: base64Encode([...ascii.encode('ADS_ENABLED='), 0xff]),
        );
        expect(invalidUtf8.exitCode, isNot(0));

        final controlCharacter = await _validateIos(
          configuration: 'Release-prod',
          rawDefines: base64Encode(utf8.encode('IGNORED=value\ninjected')),
        );
        expect(controlCharacter.exitCode, isNot(0));
      },
    );
  });
}

int _occurrences(String source, String value) =>
    value.allMatches(source).length;

Map<String, String> _readDartDefines(String path) {
  final json =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return json.map((key, value) => MapEntry(key, value.toString()));
}

Future<ProcessResult> _validateIos({
  required String configuration,
  Map<String, String>? defines,
  String? rawDefines,
}) {
  final encoded =
      rawDefines ??
      (defines ?? const {}).entries
          .map(
            (entry) => base64Encode(utf8.encode('${entry.key}=${entry.value}')),
          )
          .join(',');
  return Process.run(
    '/bin/sh',
    const ['ios/scripts/configure_admob.sh', '--validate-only'],
    environment: {'CONFIGURATION': configuration, 'DART_DEFINES': encoded},
    includeParentEnvironment: false,
  );
}
