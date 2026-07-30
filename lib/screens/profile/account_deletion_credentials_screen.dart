import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/account_deletion_credentials.dart';
import '../../providers/account_deletion_credential_provider.dart';
import '../../services/account_deletion_credential_store.dart';

class AccountDeletionCredentialsScreen extends ConsumerStatefulWidget {
  const AccountDeletionCredentialsScreen({super.key});

  @override
  ConsumerState<AccountDeletionCredentialsScreen> createState() =>
      _AccountDeletionCredentialsScreenState();
}

class _AccountDeletionCredentialsScreenState
    extends ConsumerState<AccountDeletionCredentialsScreen>
    with WidgetsBindingObserver {
  String? _revealedCode;
  var _actionInProgress = false;
  var _isResumed = true;
  var _sensitiveOperationRevision = 0;

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isResumed = false;
    _sensitiveOperationRevision += 1;
    _revealedCode = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isResumed = true;
      return;
    }
    _isResumed = false;
    _sensitiveOperationRevision += 1;
    if (_revealedCode != null && mounted) {
      setState(() => _revealedCode = null);
    }
    unawaited(_clearSensitiveClipboardBestEffort());
  }

  @override
  Widget build(BuildContext context) {
    // Watching this provider keeps its clipboard cleanup timer alive for the
    // lifetime of the screen.
    ref.watch(sensitiveClipboardServiceProvider);
    final credentialState = ref.watch(accountDeletionCredentialProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.accountDeletionCredentials)),
      body: SafeArea(
        top: false,
        child: credentialState.when(
          data: _buildContent,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadError(
            onRetry: () =>
                ref.read(accountDeletionCredentialProvider.notifier).refresh(),
            onDiscardLocal: error is AccountDeletionCredentialReadException
                ? _confirmDiscardLocalCredential
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AccountDeletionCredentialState state) {
    final descriptor = state.descriptor;
    final supportId = descriptor.supportId;
    final canReadCode = state.hasLocalRecoveryCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KisouTheme.pagePad,
        KisouTheme.gapM,
        KisouTheme.pagePad,
        32,
      ),
      children: [
        _CredentialCard(
          icon: Icons.badge_outlined,
          title: AppStrings.accountDeletionSupportId,
          value: supportId ?? AppStrings.accountDeletionNotIssued,
          valueSemanticsLabel: supportId == null
              ? AppStrings.accountDeletionNotIssued
              : '${AppStrings.accountDeletionSupportId}、$supportId',
          action: supportId == null
              ? null
              : IconButton(
                  onPressed: _actionInProgress
                      ? null
                      : () => _copySupportId(supportId),
                  tooltip: AppStrings.accountDeletionCopySupportId,
                  icon: const Icon(Icons.copy_rounded),
                ),
        ),
        const SizedBox(height: KisouTheme.gapM),
        _CredentialCard(
          icon: Icons.key_rounded,
          title: AppStrings.accountDeletionRecoveryCode,
          value: _codeValue(state),
          valueSemanticsLabel: !descriptor.configured
              ? AppStrings.accountDeletionNotIssued
              : _revealedCode == null
              ? AppStrings.accountDeletionCodeHidden
              : AppStrings.accountDeletionRecoveryCode,
          obscureValue: descriptor.configured && _revealedCode == null,
          actions: canReadCode
              ? [
                  IconButton(
                    onPressed: _actionInProgress ? null : _toggleCodeVisibility,
                    tooltip: _revealedCode == null
                        ? AppStrings.accountDeletionShowCode
                        : AppStrings.accountDeletionHideCode,
                    icon: Icon(
                      _revealedCode == null
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  IconButton(
                    onPressed: _actionInProgress ? null : _copyRecoveryCode,
                    tooltip: AppStrings.accountDeletionCopyCode,
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ]
              : const [],
        ),
        if (state.needsReplacement) ...[
          const SizedBox(height: KisouTheme.gapS),
          Text(
            AppStrings.accountDeletionLocalCodeMissing,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (descriptor.configured) ...[
          const SizedBox(height: KisouTheme.gapL),
          _StatusCard(state: state),
        ],
        const SizedBox(height: KisouTheme.gapM),
        _WarningCard(
          icon: Icons.shield_outlined,
          title: AppStrings.accountDeletionBackupWarningTitle,
          body: AppStrings.accountDeletionBackupWarningBody,
        ),
        const SizedBox(height: KisouTheme.gapM),
        const _WarningCard(
          icon: Icons.warning_amber_rounded,
          title: AppStrings.accountDeletionRecoveryCode,
          body: AppStrings.accountDeletionPermissionWarning,
        ),
        const SizedBox(height: KisouTheme.gapL),
        if (canReadCode)
          FilledButton.tonalIcon(
            onPressed: _actionInProgress || state.backupConfirmed
                ? null
                : () => _markBackupConfirmed(state),
            icon: Icon(
              state.backupConfirmed
                  ? Icons.verified_rounded
                  : Icons.task_alt_rounded,
            ),
            label: Text(
              state.backupConfirmed
                  ? AppStrings.accountDeletionBackupConfirmed
                  : AppStrings.accountDeletionMarkBackupConfirmed,
            ),
          ),
        if (canReadCode) ...[
          const SizedBox(height: KisouTheme.gapS),
          Text(
            AppStrings.accountDeletionRefreshHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk),
          ),
          const SizedBox(height: KisouTheme.gapL),
        ],
        OutlinedButton.icon(
          onPressed: _actionInProgress ? null : () => _confirmRotate(state),
          icon: _actionInProgress
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  descriptor.configured
                      ? Icons.autorenew_rounded
                      : Icons.add_circle_outline_rounded,
                ),
          label: Text(
            descriptor.configured
                ? AppStrings.accountDeletionReplace
                : AppStrings.accountDeletionIssue,
          ),
        ),
      ],
    );
  }

  String _codeValue(AccountDeletionCredentialState state) {
    if (!state.descriptor.configured) {
      return AppStrings.accountDeletionNotIssued;
    }
    if (!state.hasLocalRecoveryCode) {
      return AppStrings.accountDeletionLocalCodeMissing;
    }
    return _revealedCode ?? '•••• •••• •••• •••• •••• •••• •••• ••••';
  }

  Future<void> _toggleCodeVisibility() async {
    if (_revealedCode != null) {
      _sensitiveOperationRevision += 1;
      setState(() => _revealedCode = null);
      return;
    }
    if (!_isResumed) {
      return;
    }
    final operationRevision = ++_sensitiveOperationRevision;
    String? code;
    try {
      code = await ref
          .read(accountDeletionCredentialProvider.notifier)
          .readRecoveryCode();
    } catch (_) {
      if (_canCompleteSensitiveOperation(operationRevision)) {
        _showMessage(AppStrings.accountDeletionRevealFailed);
      }
      return;
    }
    if (!_canCompleteSensitiveOperation(operationRevision)) {
      return;
    }
    if (code == null) {
      _showMessage(AppStrings.accountDeletionRevealFailed);
      await ref.read(accountDeletionCredentialProvider.notifier).refresh();
      return;
    }
    setState(() => _revealedCode = code);
  }

  bool _canCompleteSensitiveOperation(int operationRevision) {
    return mounted &&
        _isResumed &&
        operationRevision == _sensitiveOperationRevision;
  }

  Future<void> _clearSensitiveClipboardBestEffort() async {
    try {
      await ref.read(sensitiveClipboardServiceProvider).clearIfUnchanged();
    } catch (_) {
      // Clipboard cleanup is best-effort when the OS is suspending the app.
    }
  }

  Future<void> _confirmDiscardLocalCredential() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.accountDeletionDiscardLocalTitle),
        content: const Text(AppStrings.accountDeletionDiscardLocalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.accountDeletionDiscardLocal),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final success = await ref
        .read(accountDeletionCredentialProvider.notifier)
        .discardLocalCredential();
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.accountDeletionDiscardLocalDone
          : AppStrings.accountDeletionOperationFailed,
    );
  }

  Future<void> _copySupportId(String supportId) async {
    try {
      await Clipboard.setData(ClipboardData(text: supportId));
      _showMessage(AppStrings.accountDeletionSupportIdCopied);
    } catch (_) {
      _showMessage(AppStrings.accountDeletionCopyFailed);
    }
  }

  Future<void> _copyRecoveryCode() async {
    if (!_isResumed) {
      return;
    }
    final operationRevision = ++_sensitiveOperationRevision;
    final clipboard = ref.read(sensitiveClipboardServiceProvider);
    try {
      final code = await ref
          .read(accountDeletionCredentialProvider.notifier)
          .readRecoveryCode();
      if (!_canCompleteSensitiveOperation(operationRevision)) {
        return;
      }
      if (code == null) {
        _showMessage(AppStrings.accountDeletionRevealFailed);
        return;
      }
      final clipboardRevision = await clipboard.copy(code);
      if (!_canCompleteSensitiveOperation(operationRevision)) {
        await clipboard.clearCopyIfUnchanged(clipboardRevision);
        return;
      }
      _showMessage(AppStrings.accountDeletionCodeCopied);
    } catch (_) {
      if (_canCompleteSensitiveOperation(operationRevision)) {
        _showMessage(AppStrings.accountDeletionCopyFailed);
      }
    }
  }

  Future<void> _markBackupConfirmed(
    AccountDeletionCredentialState state,
  ) async {
    if (_actionInProgress || state.backupConfirmed) {
      return;
    }
    setState(() => _actionInProgress = true);
    final success = await ref
        .read(accountDeletionCredentialProvider.notifier)
        .markBackupConfirmed();
    if (!mounted) {
      return;
    }
    setState(() => _actionInProgress = false);
    _showMessage(
      success
          ? AppStrings.accountDeletionBackupConfirmedDone
          : AppStrings.accountDeletionOperationFailed,
    );
  }

  Future<void> _confirmRotate(AccountDeletionCredentialState state) async {
    if (_actionInProgress) {
      return;
    }
    final replacing = state.descriptor.configured;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          replacing
              ? AppStrings.accountDeletionReplaceTitle
              : AppStrings.accountDeletionIssueTitle,
        ),
        content: Text(
          replacing
              ? AppStrings.accountDeletionReplaceBody
              : AppStrings.accountDeletionIssueBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              replacing
                  ? AppStrings.accountDeletionReplace
                  : AppStrings.accountDeletionIssue,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _actionInProgress = true;
      _revealedCode = null;
      _sensitiveOperationRevision += 1;
    });
    unawaited(_clearSensitiveClipboardBestEffort());
    final success = await ref
        .read(accountDeletionCredentialProvider.notifier)
        .rotate();
    if (!mounted) {
      return;
    }
    setState(() => _actionInProgress = false);
    _showMessage(
      success
          ? replacing
                ? AppStrings.accountDeletionReplaceDone
                : AppStrings.accountDeletionIssueDone
          : AppStrings.accountDeletionOperationFailed,
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.valueSemanticsLabel,
    this.action,
    this.actions = const [],
    this.obscureValue = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String valueSemanticsLabel;
  final Widget? action;
  final List<Widget> actions;
  final bool obscureValue;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: context.kisou.accent),
              const SizedBox(width: KisouTheme.gapS),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: KisouTheme.gapM),
          Semantics(
            label: valueSemanticsLabel,
            child: ExcludeSemantics(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KisouTheme.gapM),
                decoration: BoxDecoration(
                  color: context.kisou.surfaceAlt,
                  borderRadius: BorderRadius.circular(KisouTheme.rSm),
                  border: Border.all(color: context.kisou.hairline),
                ),
                child: Text(
                  value,
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: obscureValue ? null : 'monospace',
                    letterSpacing: obscureValue ? 2 : 0.6,
                  ),
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: KisouTheme.gapS),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: KisouTheme.gapS, children: actions),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final AccountDeletionCredentialState state;

  @override
  Widget build(BuildContext context) {
    final confirmed = state.backupConfirmed;
    return Semantics(
      label: confirmed
          ? AppStrings.accountDeletionBackupConfirmed
          : AppStrings.accountDeletionBackupUnconfirmed,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(
              confirmed ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: confirmed
                  ? context.kisou.success
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: KisouTheme.gapS),
            Expanded(
              child: Text(
                confirmed
                    ? AppStrings.accountDeletionBackupConfirmed
                    : AppStrings.accountDeletionBackupUnconfirmed,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      color: context.kisou.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: context.kisou.warm),
              const SizedBox(width: KisouTheme.gapS),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: KisouTheme.gapS),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, this.onDiscardLocal});

  final VoidCallback onRetry;
  final VoidCallback? onDiscardLocal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KisouTheme.pagePad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: KisouTheme.gapM),
            const Text(
              AppStrings.accountDeletionLoadFailed,
              textAlign: TextAlign.center,
            ),
            if (onDiscardLocal != null) ...[
              const SizedBox(height: KisouTheme.gapS),
              const Text(
                AppStrings.accountDeletionLocalStoreUnavailable,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: KisouTheme.gapL),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(AppStrings.accountDeletionRetry),
            ),
            if (onDiscardLocal != null) ...[
              const SizedBox(height: KisouTheme.gapS),
              OutlinedButton.icon(
                onPressed: onDiscardLocal,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text(AppStrings.accountDeletionDiscardLocal),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
