import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final hasError = authState.hasError;
    final c = context.kisou;

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
                      const Spacer(flex: 3),
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
                      const SizedBox(height: KisouTheme.gapM),
                      Text(
                        AppStrings.loginDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: c.softInk),
                      ),
                      const Spacer(flex: 4),

                      // Development logins sit above the social buttons, in a smaller size.
                      if (ApiConfig.showDevelopmentLogin) ...[
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
                        const SizedBox(height: KisouTheme.gapL),
                      ],

                      // Anonymous-only MVP: the app auto-creates an anonymous account on
                      // launch, so this screen only appears when that failed (e.g.
                      // offline). Social sign-in is intentionally not offered yet.
                      FilledButton(
                        onPressed: isLoading
                            ? null
                            : () => ref.invalidate(authProvider),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(AppStrings.retry),
                      ),

                      if (hasError) ...[
                        const SizedBox(height: KisouTheme.gapL),
                        Text(
                          AppStrings.loginFailed,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                      if (isLoading) ...[
                        const SizedBox(height: KisouTheme.gapL),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const Spacer(),
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
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.softInk,
          backgroundColor: Colors.transparent,
          minimumSize: const Size.fromHeight(38),
          side: BorderSide(color: c.hairline),
          shape: const StadiumBorder(),
          textStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
