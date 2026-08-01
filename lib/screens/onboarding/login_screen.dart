import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/brand_logo.dart';

/// Startup recovery screen for the anonymous-account MVP.
///
/// This is intentionally not presented as a sign-in screen: OAuth is not
/// available yet, and the only user action is to retry startup.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  var _automaticRetryUsed = false;
  var _cleanupRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivity,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Connectivity().checkConnectivity().then(_handleConnectivity);
    }
  }

  void _handleConnectivity(List<ConnectivityResult> results) {
    if (_automaticRetryUsed ||
        results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none)) {
      return;
    }
    final auth = ref.read(authProvider).value;
    if (auth?.startupErrorKind != ApiErrorKind.offline) {
      return;
    }
    _automaticRetryUsed = true;
    ref.invalidate(authProvider);
  }

  void _retry() {
    _automaticRetryUsed = false;
    ref.invalidate(authProvider);
  }

  Future<void> _retryLocalCleanup() async {
    if (_cleanupRetrying) {
      return;
    }
    setState(() => _cleanupRetrying = true);
    final succeeded = await ref
        .read(authProvider.notifier)
        .retryLocalAccountCleanup();
    if (!mounted) {
      return;
    }
    setState(() => _cleanupRetrying = false);
    if (succeeded) {
      ref.invalidate(authProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cleanupScope = authState.value?.localCleanupScope;
    final cleanupRequired = cleanupScope != null;
    final isLoading = authState.isLoading || _cleanupRetrying;
    final kind = authState.value?.startupErrorKind;
    final c = context.kisou;
    final (title, body, icon) = switch ((cleanupScope, kind)) {
      (LocalCleanupScope.logout, _) => (
        AppStrings.logoutLocalCleanupTitle,
        AppStrings.logoutLocalCleanupFailed,
        Icons.phonelink_erase_rounded,
      ),
      (LocalCleanupScope.accountSwitch, _) => (
        AppStrings.accountSwitchLocalCleanupTitle,
        AppStrings.accountSwitchLocalCleanupFailed,
        Icons.phonelink_erase_rounded,
      ),
      (LocalCleanupScope.accountDeletionRequest, _) => (
        AppStrings.accountDeleteRequestRecoveryTitle,
        AppStrings.accountDeleteRequestRecoveryFailed,
        Icons.person_remove_alt_1_outlined,
      ),
      (LocalCleanupScope.accountDeletion, _) => (
        AppStrings.accountDeleteLocalCleanupTitle,
        AppStrings.accountDeleteLocalCleanupFailed,
        Icons.phonelink_erase_rounded,
      ),
      (null, ApiErrorKind.offline) => (
        AppStrings.offlineError,
        AppStrings.startupOfflineBody,
        Icons.wifi_off_rounded,
      ),
      (null, ApiErrorKind.timeout) => (
        AppStrings.timeoutError,
        AppStrings.startupTimeoutBody,
        Icons.cloud_off_rounded,
      ),
      _ => (
        AppStrings.startupFailedTitle,
        AppStrings.startupFailedBody,
        Icons.error_outline_rounded,
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      const Center(
                        child: BrandLogo(
                          variant: BrandLogoVariant.mark,
                          size: 76,
                        ),
                      ),
                      const SizedBox(height: KisouTheme.gapL),
                      Text(
                        AppStrings.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: KisouTheme.gapL),
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          children: [
                            Icon(
                              icon,
                              size: 40,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: KisouTheme.gapM),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: KisouTheme.gapS),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: c.softInk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: KisouTheme.gapXl),
                      FilledButton(
                        onPressed: isLoading
                            ? null
                            : cleanupRequired
                            ? _retryLocalCleanup
                            : _retry,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder(),
                        ),
                        child: isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                cleanupRequired
                                    ? switch (cleanupScope) {
                                        LocalCleanupScope.logout =>
                                          AppStrings.logoutLocalCleanupRetry,
                                        LocalCleanupScope.accountSwitch =>
                                          AppStrings
                                              .accountSwitchLocalCleanupRetry,
                                        LocalCleanupScope
                                            .accountDeletionRequest =>
                                          AppStrings
                                              .accountDeleteRequestRecoveryRetry,
                                        _ =>
                                          AppStrings
                                              .accountDeleteLocalCleanupRetry,
                                      }
                                    : AppStrings.retry,
                              ),
                      ),
                      if (!cleanupRequired &&
                          ApiConfig.showDevelopmentLogin) ...[
                        const SizedBox(height: KisouTheme.gapL),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(AppStrings.developerOptions),
                          children: [
                            _DevLoginButton(
                              label: AppStrings.developmentExistingLogin,
                              onPressed: isLoading
                                  ? null
                                  : () => ref
                                        .read(authProvider.notifier)
                                        .loginWithDevelopmentExistingUser(),
                            ),
                            const SizedBox(height: KisouTheme.gapS),
                            _DevLoginButton(
                              label: AppStrings.developmentNewLogin,
                              onPressed: isLoading
                                  ? null
                                  : () => ref
                                        .read(authProvider.notifier)
                                        .loginWithDevelopmentNewUser(),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DevLoginButton extends StatelessWidget {
  const _DevLoginButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.kisou;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.softInk,
        backgroundColor: Colors.transparent,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: c.hairline),
        shape: const StadiumBorder(),
        textStyle: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
