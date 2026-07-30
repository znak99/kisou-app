import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/theme.dart';
import 'package:kisou_app/constants/app_strings.dart';
import 'package:kisou_app/models/account_deletion_credentials.dart';
import 'package:kisou_app/providers/account_deletion_credential_provider.dart';
import 'package:kisou_app/repositories/account_deletion_credential_repository.dart';
import 'package:kisou_app/screens/profile/account_deletion_credentials_screen.dart';
import 'package:kisou_app/services/account_deletion_credential_store.dart';
import 'package:kisou_app/services/sensitive_clipboard_service.dart';

const _supportId = 'KSO-1234-5678-9ABC-DEFG-HJKM';
const _recoveryCode = '0123-4567-89AB-CDEF-GHJK-MNPQ-RSTV-WXYZ';

void main() {
  testWidgets('masks, reveals, and copies the deletion code explicitly', (
    tester,
  ) async {
    final repository = _ScreenFakeRepository(configured: true);
    final copied = <String>[];
    final clipboard = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async => copied.add(value),
      read: () async => copied.lastOrNull,
    );
    await _pumpScreen(tester, repository: repository, clipboard: clipboard);

    expect(find.text(_recoveryCode), findsNothing);
    expect(
      find.text('•••• •••• •••• •••• •••• •••• •••• ••••'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(AppStrings.accountDeletionShowCode));
    await tester.pump();
    expect(find.text(_recoveryCode), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text(_recoveryCode), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byTooltip(AppStrings.accountDeletionShowCode));
    await tester.pump();

    await tester.tap(find.byTooltip(AppStrings.accountDeletionCopyCode));
    await tester.pump();
    expect(copied, contains(_recoveryCode));
    expect(find.text(AppStrings.accountDeletionCodeCopied), findsOneWidget);
    await clipboard.clearIfUnchanged();
  });

  testWidgets('requires confirmation before issuing a code', (tester) async {
    final repository = _ScreenFakeRepository(configured: false);
    await _pumpScreen(tester, repository: repository);

    await _scrollToBottom(tester);
    await tester.tap(find.text(AppStrings.accountDeletionIssue));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.accountDeletionIssueTitle), findsOneWidget);
    expect(repository.rotateCalls, 0);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.accountDeletionIssue),
    );
    await tester.pumpAndSettle();

    expect(repository.rotateCalls, 1);
    expect(find.text(_supportId), findsOneWidget);
    expect(find.text(_recoveryCode), findsNothing);
  });

  testWidgets('backgrounding invalidates a pending code reveal', (
    tester,
  ) async {
    final readCompleter = Completer<String?>();
    final repository = _ScreenFakeRepository(
      configured: true,
      readCompleter: readCompleter,
    );
    await _pumpScreen(tester, repository: repository);

    await tester.tap(find.byTooltip(AppStrings.accountDeletionShowCode));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    readCompleter.complete(_recoveryCode);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text(_recoveryCode), findsNothing);
  });

  testWidgets('backgrounding clears a copy completed after suspension', (
    tester,
  ) async {
    final writeCompleter = Completer<void>();
    String? clipboardValue;
    final clipboard = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async {
        clipboardValue = value;
        if (value.isNotEmpty) {
          await writeCompleter.future;
        }
      },
      read: () async => clipboardValue,
    );
    final repository = _ScreenFakeRepository(configured: true);
    await _pumpScreen(tester, repository: repository, clipboard: clipboard);

    await tester.tap(find.byTooltip(AppStrings.accountDeletionCopyCode));
    await tester.pump();
    expect(clipboardValue, _recoveryCode);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    writeCompleter.complete();
    await tester.pump();

    expect(clipboardValue, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('ambiguous failed clipboard write is immediately cleared', (
    tester,
  ) async {
    String? clipboardValue;
    var failSensitiveWrite = true;
    final clipboard = SensitiveClipboardService(
      clearAfter: const Duration(days: 1),
      write: (value) async {
        clipboardValue = value;
        if (value.isNotEmpty && failSensitiveWrite) {
          failSensitiveWrite = false;
          throw PlatformException(code: 'ambiguous-write');
        }
      },
      read: () async => clipboardValue,
    );
    final repository = _ScreenFakeRepository(configured: true);
    await _pumpScreen(tester, repository: repository, clipboard: clipboard);

    await tester.tap(find.byTooltip(AppStrings.accountDeletionCopyCode));
    await tester.pump();

    expect(clipboardValue, isEmpty);
    expect(find.text(AppStrings.accountDeletionCopyFailed), findsOneWidget);
  });

  testWidgets('replacement invalidates the old-code backup status', (
    tester,
  ) async {
    final repository = _ScreenFakeRepository(
      configured: true,
      backupConfirmed: true,
    );
    await _pumpScreen(tester, repository: repository);

    expect(find.text(AppStrings.accountDeletionBackupConfirmed), findsWidgets);
    await _scrollToBottom(tester);
    await tester.tap(find.text(AppStrings.accountDeletionReplace));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.accountDeletionReplaceBody), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.accountDeletionReplace),
    );
    await tester.pumpAndSettle();

    expect(repository.rotateCalls, 1);
    expect(
      find.text(AppStrings.accountDeletionBackupUnconfirmed),
      findsOneWidget,
    );
  });

  testWidgets('replacement invalidates a pending old-code reveal', (
    tester,
  ) async {
    final readCompleter = Completer<String?>();
    final repository = _ScreenFakeRepository(
      configured: true,
      readCompleter: readCompleter,
    );
    await _pumpScreen(tester, repository: repository);

    await tester.tap(find.byTooltip(AppStrings.accountDeletionShowCode));
    await tester.pump();
    await _scrollToBottom(tester);
    await tester.tap(find.text(AppStrings.accountDeletionReplace));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.accountDeletionReplace),
    );
    await tester.pumpAndSettle();

    expect(repository.rotateCalls, 1);
    readCompleter.complete(_recoveryCode);
    await tester.pump();
    expect(find.text(_recoveryCode), findsNothing);
  });

  testWidgets('transient secure-store error requires explicit local discard', (
    tester,
  ) async {
    final repository = _ScreenFakeRepository(
      configured: true,
      failLoadWithStoreError: true,
    );
    await _pumpScreen(tester, repository: repository);

    expect(
      find.text(AppStrings.accountDeletionLocalStoreUnavailable),
      findsOneWidget,
    );
    expect(repository.discardCalls, 0);
    await tester.tap(find.text(AppStrings.accountDeletionDiscardLocal));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.accountDeletionDiscardLocalBody),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.accountDeletionDiscardLocal),
    );
    await tester.pumpAndSettle();

    expect(repository.discardCalls, 1);
    expect(find.text(AppStrings.accountDeletionLocalCodeMissing), findsWidgets);
  });

  testWidgets('reflows at 320 logical pixels and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScreenFakeRepository(configured: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDeletionCredentialRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            theme: KisouTheme.light(),
            home: const AccountDeletionCredentialsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.accountDeletionCredentials), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await _scrollToBottom(tester);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  });
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AccountDeletionCredentialRepository repository,
  SensitiveClipboardService? clipboard,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountDeletionCredentialRepositoryProvider.overrideWithValue(
          repository,
        ),
        if (clipboard != null)
          sensitiveClipboardServiceProvider.overrideWithValue(clipboard),
      ],
      child: MaterialApp(
        theme: KisouTheme.light(),
        home: const AccountDeletionCredentialsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ScreenFakeRepository implements AccountDeletionCredentialRepository {
  _ScreenFakeRepository({
    required this.configured,
    this.backupConfirmed = false,
    this.readCompleter,
    this.failLoadWithStoreError = false,
    bool? hasLocalRecoveryCode,
  }) : hasLocalRecoveryCode = hasLocalRecoveryCode ?? configured;

  bool configured;
  bool backupConfirmed;
  final Completer<String?>? readCompleter;
  bool failLoadWithStoreError;
  bool hasLocalRecoveryCode;
  var rotateCalls = 0;
  var discardCalls = 0;

  AccountDeletionCredentialState get _state => AccountDeletionCredentialState(
    descriptor: AccountDeletionCredentialDescriptor(
      supportId: configured ? _supportId : null,
      codeVersion: configured ? rotateCalls + 1 : 0,
      configured: configured,
    ),
    hasLocalRecoveryCode: hasLocalRecoveryCode,
    backupConfirmed: configured && hasLocalRecoveryCode && backupConfirmed,
  );

  @override
  Future<AccountDeletionCredentialState> load() async {
    if (failLoadWithStoreError) {
      throw const AccountDeletionCredentialReadException();
    }
    return _state;
  }

  @override
  Future<AccountDeletionCredentialState> rotate() async {
    rotateCalls += 1;
    configured = true;
    hasLocalRecoveryCode = true;
    backupConfirmed = false;
    return _state;
  }

  @override
  Future<AccountDeletionCredentialState> discardLocalCredential() async {
    discardCalls += 1;
    failLoadWithStoreError = false;
    hasLocalRecoveryCode = false;
    backupConfirmed = false;
    return _state;
  }

  @override
  Future<String?> readRecoveryCode(
    AccountDeletionCredentialState currentState,
  ) async {
    if (readCompleter != null) {
      return readCompleter!.future;
    }
    return hasLocalRecoveryCode ? _recoveryCode : null;
  }

  @override
  Future<AccountDeletionCredentialState> markBackupConfirmed(
    AccountDeletionCredentialState currentState,
  ) async {
    backupConfirmed = true;
    return _state;
  }
}
