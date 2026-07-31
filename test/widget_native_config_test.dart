import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  final mainActivity = _read(
    'android/app/src/main/kotlin/com/example/kisou_app/MainActivity.kt',
  );
  final androidCodec = _read(
    'android/app/src/main/kotlin/com/example/kisou_app/'
    'KisouWidgetSnapshot.kt',
  );
  final androidProvider = _read(
    'android/app/src/main/kotlin/com/example/kisou_app/'
    'KisouWidgetProvider.kt',
  );
  final smallLayout = _read(
    'android/app/src/main/res/layout/kisou_widget_small.xml',
  );
  final mediumLayout = _read(
    'android/app/src/main/res/layout/kisou_widget_medium.xml',
  );
  final widgetInfo = _read(
    'android/app/src/main/res/xml/kisou_widget_info.xml',
  );
  final swiftCodec = _read('ios/WidgetShared/KisouWidgetSnapshotCodec.swift');
  final swiftBridge = _read('ios/Runner/WidgetSnapshotBridge.swift');
  final swiftWidget = _read('ios/KisouWidget/KisouWidget.swift');
  final xcodeProject = _read('ios/Runner.xcodeproj/project.pbxproj');
  final dartModel = _read('lib/models/widget_recommendation.dart');

  test('all three parsers enforce one exact fail-closed snapshot contract', () {
    expect(dartModel, contains('schemaVersion is! int'));
    expect(androidCodec, contains('as? Int != KISOU_WIDGET_SCHEMA_VERSION'));
    expect(swiftCodec, contains('CFGetTypeID(schema) == CFNumberGetTypeID()'));
    expect(swiftCodec, contains('!CFNumberIsFloatType(schema as CFNumber)'));

    for (final source in [dartModel, androidCodec, swiftCodec]) {
      expect(source, contains('schema_version'));
      expect(source, contains('valid_until'));
      expect(source, contains('recommendation'));
      expect(source, isNot(contains('withFractionalSeconds')));
      expect(source, isNot(contains(r'\d{1,6}')));
      expect(source, contains('[0-5]'));
    }
    expect(dartModel, contains('_formatCanonicalUtc(parsed) != value'));
    expect(androidCodec, contains('validUntil.toString() != rawExpiry'));
    expect(swiftCodec, contains('formatter.string(from: parsed) == value'));
    expect(dartModel, contains('subtract(const Duration(hours: 9))'));
    expect(
      androidCodec,
      contains('date.plusDays(1).atStartOfDay(tokyo).toInstant()'),
    );
    expect(swiftCodec, contains('nextTokyoMidnight('));
  });

  test('native parsers require the one canonical envelope byte sequence', () {
    expect(androidCodec, contains('if (raw != canonicalReadyEnvelope('));
    expect(
      androidCodec,
      contains(r'"{\"schema_version\":1,\"state\":\"ready\","'),
    );
    expect(swiftCodec, contains('guard canonicalReadyEnvelope('));
    expect(swiftCodec, contains(') == data else {'));
    expect(swiftCodec, contains('return Data(raw.utf8)'));

    const canonical =
        '{"schema_version":1,"state":"ready","date":"2026-07-31",'
        '"valid_until":"2026-07-31T15:00:00Z","feeling":"PERFECT",'
        '"recommendation":{"top":"SHORT_SLEEVE","bottom":"LONG_PANTS",'
        '"outer":null}}';
    final noncanonical = [
      ' $canonical',
      '$canonical\n',
      '$canonical trailing',
      canonical.replaceFirst('{', '{/*comment*/'),
      canonical.replaceAll('"', "'"),
      canonical.replaceFirst(
        '"schema_version":1,',
        '"schema_version":0,"schema_version":1,',
      ),
      canonical.replaceFirst(
        '"state":"ready","date":"2026-07-31"',
        '"date":"2026-07-31","state":"ready"',
      ),
      canonical.replaceFirst('"state":"ready"', '"state":"\\u0072eady"'),
    ];
    for (final raw in noncanonical) {
      expect(raw, isNot(canonical));
    }
  });

  test('native clothing and feeling labels stay exactly in parity', () {
    const feelings = {
      'VERY_HOT': 'とても暑く感じそうです',
      'HOT': '暑く感じそうです',
      'WARM': '暖かく感じそうです',
      'PERFECT': 'ちょうど良く感じそうです',
      'COOL': '涼しく感じそうです',
      'COLD': '寒く感じそうです',
      'VERY_COLD': 'とても寒く感じそうです',
    };
    const clothing = {
      'SLEEVELESS': 'タンクトップ',
      'SHORT_SLEEVE': '半袖',
      'THIN_LONG': '薄手の長袖',
      'LONG_SLEEVE': '長袖',
      'THICK_LONG': '厚手の長袖',
      'KNIT_SWEAT': 'ニット・スウェット',
      'LONG_PANTS': '長ズボン',
      'HALF_PANTS': '半ズボン',
      'SHORT_PANTS': 'ショートパンツ',
      'SKIRT': 'スカート',
      'LIGHT_OUTER': '薄手の羽織り',
      'CARDIGAN': 'カーディガン',
      'JACKET': 'ジャケット',
      'COAT': 'コート',
      'PADDING': 'ダウン',
    };

    for (final entry in feelings.entries) {
      expect(androidCodec, contains('"${entry.key}" to "${entry.value}"'));
      expect(swiftCodec, contains('"${entry.key}": "${entry.value}"'));
    }
    for (final entry in clothing.entries) {
      expect(androidCodec, contains('"${entry.key}" to "${entry.value}"'));
      expect(swiftCodec, contains('"${entry.key}": "${entry.value}"'));
      expect(
        dartModel + _read('lib/constants/clothing_tags.dart'),
        contains(entry.key),
      );
      expect(_read('lib/constants/clothing_tags.dart'), contains(entry.value));
    }
    expect(androidCodec, contains('"アウターなし"'));
    expect(swiftCodec, contains('"アウターなし"'));
  });

  test('Android storage, periodic update, and tap intent stay app-private', () {
    expect(androidCodec, contains('context.noBackupFilesDir'));
    expect(androidCodec, contains('AtomicFile(target)'));
    expect(androidCodec, contains('File(target.path + ".new")'));
    expect(androidCodec, contains('File(target.path + ".bak")'));
    expect(androidCodec, contains('!legacyBackupTarget.exists()'));
    expect(androidCodec, contains('!pendingTarget.exists()'));
    expect(
      androidCodec,
      contains('(!target.isFile || target.length() > MAX_SNAPSHOT_BYTES)'),
    );
    expect(androidCodec, contains('target.length() > MAX_SNAPSHOT_BYTES'));
    expect(androidCodec, contains('throw IllegalStateException'));
    expect(androidCodec, contains('output.fd.sync()'));
    expect(androidCodec, contains('atomicFile.finishWrite(output)'));
    expect(androidCodec, contains('atomicFile.failWrite(output)'));
    expect(androidCodec, contains('val expectedBytes = json.toByteArray'));
    expect(androidCodec, contains('val persistedBytes = try {'));
    expect(androidCodec, contains('atomicFile.readFully()'));
    expect(
      androidCodec,
      contains('!persistedBytes.contentEquals(expectedBytes)'),
    );
    final writeStart = androidCodec.indexOf('fun writeDurably(json: String)');
    final writeEnd = androidCodec.indexOf('\n    fun read()', writeStart);
    final writeBlock = androidCodec.substring(writeStart, writeEnd);
    expect(
      writeBlock.indexOf('atomicFile.failWrite(output)'),
      lessThan(writeBlock.indexOf('atomicFile.finishWrite(output)')),
    );
    expect(
      writeBlock.substring(
        writeBlock.indexOf('atomicFile.finishWrite(output)'),
      ),
      isNot(contains('atomicFile.failWrite(output)')),
    );
    final finishIndex = writeBlock.indexOf('atomicFile.finishWrite(output)');
    final firstResidueCheck = writeBlock.indexOf(
      'requireNoAtomicResidue()',
      finishIndex,
    );
    final readBackIndex = writeBlock.indexOf(
      'atomicFile.readFully()',
      firstResidueCheck,
    );
    final secondResidueCheck = writeBlock.indexOf(
      'requireNoAtomicResidue()',
      readBackIndex,
    );
    expect(finishIndex, lessThan(firstResidueCheck));
    expect(firstResidueCheck, lessThan(readBackIndex));
    expect(readBackIndex, lessThan(secondResidueCheck));

    expect(widgetInfo, contains('android:updatePeriodMillis="1800000"'));
    expect(
      androidProvider,
      contains('KisouWidgetSnapshotStore(context).read()'),
    );
    expect(androidProvider, isNot(contains('HttpURLConnection')));
    expect(androidProvider, isNot(contains('OkHttp')));
    expect(androidProvider, isNot(contains('Authorization')));
    expect(
      androidProvider,
      contains('Intent(context, MainActivity::class.java)'),
    );
    expect(androidProvider, contains('`package` = context.packageName'));
    expect(androidProvider, contains('HOME_REQUEST_CODE'));
    expect(androidProvider, contains('PendingIntent.FLAG_UPDATE_CURRENT'));
    expect(androidProvider, contains('PendingIntent.FLAG_IMMUTABLE'));
    expect(androidProvider, isNot(contains('FLAG_ONE_SHOT')));
  });

  test('Android custom route is the sole exact deep-link owner', () {
    final activity = RegExp(
      r'<activity[\s\S]*?</activity>',
    ).firstMatch(manifest)!.group(0)!;
    expect(activity, contains('flutter_deeplinking_enabled'));
    expect(
      activity,
      matches(RegExp(r'flutter_deeplinking_enabled"\s+android:value="false"')),
    );
    expect(
      manifest.substring(manifest.indexOf('</activity>') + 11),
      isNot(contains('flutter_deeplinking_enabled')),
    );
    expect(activity, contains('android:scheme="\${widgetDeepLinkScheme}"'));
    expect(activity, contains('android:host="widget"'));
    expect(activity, contains('android:path="/home"'));
    expect(mainActivity, contains('uri.userInfo == null'));
    expect(mainActivity, contains('uri.port == -1'));
    expect(mainActivity, contains('uri.query == null'));
    expect(mainActivity, contains('uri.fragment == null'));

    final onNewIntent = RegExp(
      r'override fun onNewIntent[\s\S]*?\n    }',
    ).firstMatch(mainActivity)!.group(0)!;
    expect(
      onNewIntent.indexOf('isWidgetHomeIntent && widgetRoutesDisabled'),
      lessThan(onNewIntent.indexOf('super.onNewIntent(intent)')),
    );
  });

  test(
    'Android restores the durable route gate before delivering cold taps',
    () {
      final onCreate = RegExp(
        r'override fun onCreate[\s\S]*?\n    }',
      ).firstMatch(mainActivity)!.group(0)!;
      expect(onCreate, contains('widgetRoutesDisabled = true'));
      expect(onCreate, contains('widgetRouteLeaseResolved = false'));
      expect(onCreate, contains('initialWidgetHomeIntent'));
      expect(
        onCreate,
        contains('pendingWidgetHomeRoute = initialWidgetHomeIntent'),
      );
      expect(onCreate, contains('intent?.data = null'));
      expect(
        onCreate.indexOf('intent?.data = null'),
        lessThan(onCreate.indexOf('super.onCreate(savedInstanceState)')),
      );
      expect(mainActivity, contains('hydrateWidgetRouteLease('));
      expect(mainActivity, contains('widgetIoExecutor.execute'));
      expect(mainActivity, contains('shouldDisableRoutes('));
      expect(mainActivity, contains('operationEpoch == widgetRouteEpoch'));
      expect(androidCodec, contains('if (raw == null) return false'));
      expect(
        androidCodec,
        contains('if (raw == SIGNED_OUT_ENVELOPE) return true'),
      );
      expect(androidCodec, contains('return parseReadyEnvelope(raw) == null'));
    },
  );

  test('native ready writes preserve pending taps while close clears them', () {
    final androidReady = mainActivity.substring(
      mainActivity.indexOf('"writeSnapshot" -> {'),
      mainActivity.indexOf('"closeAccount" -> {'),
    );
    expect(androidReady, contains('val operationEpoch = widgetRouteEpoch'));
    expect(androidReady, isNot(contains('++widgetRouteEpoch')));
    expect(androidReady, contains('widgetRouteLeaseResolved = true'));
    expect(androidReady, contains('widgetRoutesDisabled = false'));
    expect(androidReady, contains('notifyPendingWidgetHomeRoute()'));
    expect(androidReady, isNot(contains('pendingWidgetHomeRoute = false')));
    expect(androidReady, isNot(contains('intent?.data = null')));

    final androidClose = mainActivity.substring(
      mainActivity.indexOf('"closeAccount" -> {'),
      mainActivity.indexOf('"consumeInitialWidgetRoute" -> {'),
    );
    expect(androidClose, contains('++widgetRouteEpoch'));
    expect(androidClose, contains('pendingWidgetHomeRoute = false'));
    expect(androidClose, contains('intent?.data = null'));

    final androidConsume = mainActivity.substring(
      mainActivity.indexOf('"consumeInitialWidgetRoute" -> {'),
      mainActivity.indexOf('else -> result.notImplemented()'),
    );
    expect(androidConsume, contains('if (!widgetRouteLeaseResolved)'));
    expect(
      androidConsume.indexOf('if (!widgetRouteLeaseResolved)'),
      lessThan(androidConsume.indexOf('pendingWidgetHomeRoute = false')),
    );

    final androidHydration = mainActivity.substring(
      mainActivity.indexOf('private fun hydrateWidgetRouteLease()'),
      mainActivity.indexOf('private fun notifyPendingWidgetHomeRoute()'),
    );
    expect(androidHydration, contains('widgetRouteLeaseResolved = true'));
    expect(androidHydration, contains('if (routesDisabled)'));
    expect(androidHydration, contains('pendingWidgetHomeRoute = false'));
    expect(androidHydration, contains('notifyPendingWidgetHomeRoute()'));

    final swiftReadySuccess = RegExp(
      r'} else if !closeAccount && operationEpoch == self\.routeEpoch \{'
      r'[\s\S]*?\n          }',
    ).firstMatch(swiftBridge)!.group(0)!;
    expect(swiftReadySuccess, contains('self.routesDisabled = false'));
    expect(swiftReadySuccess, isNot(contains('self.pendingHomeRoute = false')));

    final swiftCloseSuccess = RegExp(
      r'if closeAccount && operationEpoch == self\.routeEpoch \{'
      r'[\s\S]*?} else if !closeAccount',
    ).firstMatch(swiftBridge)!.group(0)!;
    expect(swiftCloseSuccess, contains('self.pendingHomeRoute = false'));
  });

  test('Android compact layouts preserve date and relevant information', () {
    expect(androidProvider, contains('configuration.fontScale >= 1.5f'));
    expect(androidProvider, contains('R.id.widget_title'));
    expect(androidProvider, contains('usesCompactTextLayout) View.GONE'));
    expect(androidProvider, contains('is KisouWidgetRenderState.Ready'));
    expect(androidProvider, contains('is KisouWidgetRenderState.Placeholder'));
    expect(androidProvider, contains('setGarmentPresentation('));
    for (final layout in [smallLayout, mediumLayout]) {
      expect(layout, contains('android:id="@+id/widget_title"'));
      expect(layout, contains('android:id="@+id/widget_date"'));
      expect(layout, contains('android:id="@+id/widget_outer"'));
      expect(layout, contains('android:id="@+id/widget_top"'));
      expect(layout, contains('android:id="@+id/widget_bottom"'));
      expect(layout, isNot(contains('layout_marginHorizontal')));
    }
  });

  test(
    'iOS uses isolated App Groups and a synchronized atomic replacement',
    () {
      expect(
        _read('ios/Runner/Runner.entitlements'),
        contains('group.cloud.znak99.kisou.widget'),
      );
      expect(
        _read('ios/KisouWidget/KisouWidget.entitlements'),
        contains('group.cloud.znak99.kisou.widget'),
      );
      expect(
        _read('ios/Runner/Runner-Dev.entitlements'),
        contains('group.cloud.znak99.kisou.dev.widget'),
      );
      expect(
        _read('ios/KisouWidget/KisouWidget-Dev.entitlements'),
        contains('group.cloud.znak99.kisou.dev.widget'),
      );
      expect(swiftBridge, contains('Data.write'));
      expect(swiftBridge, contains('.atomic'));
      expect(swiftBridge, contains('fileHandle.synchronize()'));
      expect(swiftBridge, contains('isExcludedFromBackup = true'));
      expect(
        swiftBridge,
        contains('completeFileProtectionUntilFirstUserAuthentication'),
      );
      expect(swiftBridge, contains('WidgetCenter.shared.reloadTimelines'));
    },
  );

  test('iOS restores route state and rejects stale native completions', () {
    expect(
      swiftBridge,
      contains('routesDisabled = Self.restoreDurableRouteLease()'),
    );
    expect(
      swiftBridge,
      contains('private static func restoreDurableRouteLease()'),
    );
    expect(
      swiftBridge,
      contains('data == KisouWidgetShared.signedOutEnvelope'),
    );
    expect(swiftBridge, contains('isValidReadyEnvelope(data)'));
    expect(swiftBridge, contains('size.intValue <= 8 * 1024'));
    expect(swiftBridge, contains('data.count <= 8 * 1024'));
    expect(swiftBridge, contains('operationEpoch == self.routeEpoch'));
    expect(swiftBridge, contains('self.routesDisabled = true'));
    expect(swiftCodec, contains('static func isValidReadyEnvelope'));
  });

  test(
    'iOS timeline expires closed and supports system rendering contexts',
    () {
      expect(swiftWidget, isNot(contains('URLSession')));
      expect(swiftWidget, isNot(contains('Authorization')));
      expect(swiftWidget, contains('KisouWidgetEntry(date: now'));
      expect(
        swiftWidget,
        contains('KisouWidgetEntry(\n        date: boundary'),
      );
      expect(swiftWidget, contains('policy: .atEnd'));
      expect(swiftWidget, contains('containerBackground(for: .widget)'));
      expect(swiftWidget, contains('if #available(iOS 17.0, *)'));
      expect(swiftWidget, contains('.privacySensitive()'));
      expect(swiftWidget, contains('usesCompactAccessibilityLayout'));
      expect(swiftWidget, contains('sizeCategory.isAccessibilityCategory'));
      expect(swiftWidget, contains('colorScheme == .dark'));
      expect(swiftWidget, contains('dateLabel'));
    },
  );

  test('iOS build configs embed, sign, version, and isolate the extension', () {
    expect(
      RegExp(
        r'AA17[0-9A-F]{20} /\* [^*]+ \*/ = '
        r'\{\s*isa = XCBuildConfiguration;\s*'
        r'baseConfigurationReference = '
        r'9740EEB31CF90195004384FC /\* Generated\.xcconfig \*/;',
      ).allMatches(xcodeProject),
      hasLength(9),
    );
    expect(
      xcodeProject,
      contains('ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, );'),
    );
    expect(xcodeProject, contains('Embed App Extensions'));
    expect(xcodeProject, contains('KisouWidget.appex'));
    expect(xcodeProject, contains('SKIP_INSTALL = YES'));
    expect(
      _read('ios/KisouWidget/Info.plist'),
      contains(r'$(CURRENT_PROJECT_VERSION)'),
    );
    expect(
      _read('ios/KisouWidget/Info.plist'),
      contains(r'$(MARKETING_VERSION)'),
    );

    for (var index = 1; index <= 9; index += 1) {
      final id = 'AA170000000000000000000$index';
      final block = _widgetConfigurationBlock(xcodeProject, id);
      expect(
        block,
        contains('CURRENT_PROJECT_VERSION = "\$(FLUTTER_BUILD_NUMBER)"'),
      );
      expect(block, contains('MARKETING_VERSION = "\$(FLUTTER_BUILD_NAME)"'));
      if ({4, 6, 8}.contains(index)) {
        expect(block, contains('cloud.znak99.kisou.dev.widget'));
        expect(block, contains('group.cloud.znak99.kisou.dev.widget'));
        expect(block, contains('KisouWidget-Dev.entitlements'));
        expect(block, contains('KISOU_WIDGET_URL_SCHEME = "kisou-dev"'));
      } else {
        expect(block, contains('cloud.znak99.kisou.widget'));
        expect(block, contains('group.cloud.znak99.kisou.widget'));
        expect(block, contains('KisouWidget/KisouWidget.entitlements'));
        expect(block, contains('KISOU_WIDGET_URL_SCHEME = kisou'));
        expect(block, isNot(contains('.dev.widget')));
      }
    }
  });

  test('iOS disables automatic Flutter routing in both flavors', () {
    for (final path in ['ios/Runner/Info.plist', 'ios/Runner/Info-Dev.plist']) {
      final plist = _read(path);
      expect(
        plist,
        matches(RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')),
      );
    }
    expect(swiftBridge, contains('components.host == "widget"'));
    expect(swiftBridge, contains('components.path == "/home"'));
    expect(swiftBridge, contains('components.user == nil'));
    expect(swiftBridge, contains('components.password == nil'));
    expect(swiftBridge, contains('components.port == nil'));
    expect(swiftBridge, contains('components.query == nil'));
    expect(swiftBridge, contains('components.fragment == nil'));
  });

  test('widget route refreshes home and widget exactly once', () {
    final rootShell = _read('lib/screens/root_shell.dart');
    final route = RegExp(
      r'void _openWidgetHomeRoute\(\) \{[\s\S]*?\n  }',
    ).firstMatch(rootShell)!.group(0)!;
    expect(route, contains('.refresh(syncWidget: false)'));
    expect(
      RegExp(r'\.refreshIfDue\(force: true\)').allMatches(route),
      hasLength(1),
    );
  });
}

String _read(String path) => File(path).readAsStringSync();

String _widgetConfigurationBlock(String project, String id) {
  final match = RegExp(
    '$id'
    r'[\s\S]*?name = (?:"[^"]+"|Debug|Profile|Release);\n\s*};',
  ).firstMatch(project);
  expect(match, isNotNull, reason: 'missing widget configuration $id');
  return match!.group(0)!;
}
