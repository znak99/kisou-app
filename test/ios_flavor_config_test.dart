import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final podfile = File('ios/Podfile').readAsStringSync();
  final devScheme = File(
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme',
  ).readAsStringSync();
  final prodScheme = File(
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/prod.xcscheme',
  ).readAsStringSync();
  final devInfo = File('ios/Runner/Info-Dev.plist').readAsStringSync();
  final prodInfo = File('ios/Runner/Info.plist').readAsStringSync();

  test('Xcode project keeps base and complete dev/prod configurations', () {
    expect(
      RegExp(r'isa = XCBuildConfiguration;').allMatches(project),
      hasLength(36),
    );

    for (final flavor in ['dev', 'prod']) {
      for (final mode in ['Debug', 'Profile', 'Release']) {
        final configuration = '$mode-$flavor';
        expect(
          RegExp('name = "$configuration";').allMatches(project),
          hasLength(4),
          reason:
              '$configuration must exist for project, app, tests, and widget',
        );
        expect(podfile, contains("'$configuration' =>"));
      }
    }

    for (final base in ['Debug', 'Profile', 'Release']) {
      expect(podfile, contains("'$base' =>"));
    }
  });

  test('all four Xcode configuration lists contain nine unique configs', () {
    const expectedNames = {
      'Debug',
      'Debug-dev',
      'Debug-prod',
      'Profile',
      'Profile-dev',
      'Profile-prod',
      'Release',
      'Release-dev',
      'Release-prod',
    };
    for (final listId in [
      '331C8087294A63A400263BE5',
      '97C146E91CF9000F007C117D',
      '97C147051CF9000F007C117D',
      'AA1800000000000000000001',
    ]) {
      final configurations = _configurationList(project, listId);
      expect(
        configurations.map((entry) => entry.id).toSet(),
        hasLength(9),
        reason: '$listId contains a duplicate build configuration ID',
      );
      expect(
        configurations.map((entry) => entry.name).toSet(),
        expectedNames,
        reason: '$listId must expose the complete configuration matrix',
      );
    }
  });

  test('iOS schemes select only their matching configurations', () {
    for (final configuration in ['Debug-dev', 'Profile-dev', 'Release-dev']) {
      expect(devScheme, contains('buildConfiguration = "$configuration"'));
      expect(prodScheme, isNot(contains(configuration)));
    }
    for (final configuration in [
      'Debug-prod',
      'Profile-prod',
      'Release-prod',
    ]) {
      expect(prodScheme, contains('buildConfiguration = "$configuration"'));
      expect(devScheme, isNot(contains(configuration)));
    }

    expect(devScheme, contains('buildForArchiving = "NO"'));
    expect(prodScheme, contains('buildForArchiving = "YES"'));
    expect(
      File(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
      ).existsSync(),
      isFalse,
    );
  });

  test('dev and prod identifiers, plists, and entitlements are isolated', () {
    for (final mode in ['Debug', 'Profile', 'Release']) {
      expect(
        project,
        contains('D0020000000000000000000${_modeIndex(mode)} /* $mode-dev */'),
      );
    }

    expect(
      RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = cloud\.znak99\.kisou\.dev;',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(r'INFOPLIST_FILE = "Runner/Info-Dev\.plist";').allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(
        r'CODE_SIGN_ENTITLEMENTS = "Runner/Runner-Dev\.entitlements";',
      ).allMatches(project),
      hasLength(3),
    );
    expect(
      RegExp(r'KISOU_DISPLAY_NAME = "KISOU Dev";').allMatches(project),
      hasLength(3),
    );

    expect(devInfo, contains('<key>NSAllowsLocalNetworking</key>'));
    expect(devInfo, contains('<key>NSLocalNetworkUsageDescription</key>'));
    expect(prodInfo, isNot(contains('NSAllowsLocalNetworking')));
    expect(prodInfo, isNot(contains('NSLocalNetworkUsageDescription')));

    for (final path in [
      'ios/Runner/Runner-Dev.entitlements',
      'ios/Runner/Runner.entitlements',
    ]) {
      final entitlements = File(path).readAsStringSync();
      expect(entitlements, contains('<key>keychain-access-groups</key>'));
      expect(
        RegExp(
          r'<key>keychain-access-groups</key>\s*<array\s*/>',
        ).hasMatch(entitlements),
        isTrue,
      );
    }
    expect(
      File('ios/Runner/Runner-Dev.entitlements').readAsStringSync(),
      contains('<string>development</string>'),
    );
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('<string>production</string>'),
    );
  });
}

List<({String id, String name})> _configurationList(
  String project,
  String listId,
) {
  final body = RegExp(
    '$listId[^=]*= \\{.*?buildConfigurations = \\((.*?)\\);',
    dotAll: true,
  ).firstMatch(project)?.group(1);
  expect(body, isNotNull, reason: 'missing configuration list $listId');
  return RegExp(r'([A-F0-9]{24}) /\* ([^*]+) \*/')
      .allMatches(body!)
      .map((match) {
        return (id: match.group(1)!, name: match.group(2)!);
      })
      .toList(growable: false);
}

int _modeIndex(String mode) {
  return switch (mode) {
    'Debug' => 1,
    'Profile' => 3,
    'Release' => 5,
    _ => throw ArgumentError.value(mode),
  };
}
