import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final hasError = authState.hasError;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                AppStrings.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.loginDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(flex: 3),
              SignInWithAppleButton(
                text: AppStrings.appleLogin,
                height: 54,
                borderRadius: BorderRadius.circular(27),
                onPressed: isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).loginWithApple(),
              ),
              const SizedBox(height: 12),
              _GoogleSignInButton(
                isLoading: isLoading,
                onPressed: () =>
                    ref.read(authProvider.notifier).loginWithGoogle(),
              ),
              if (ApiConfig.showDevelopmentLogin) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authProvider.notifier)
                            .loginWithDevelopmentExistingUser(),
                  child: const Text(AppStrings.developmentExistingLogin),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authProvider.notifier)
                            .loginWithDevelopmentNewUser(),
                  child: const Text(AppStrings.developmentNewLogin),
                ),
              ],
              if (hasError) ...[
                const SizedBox(height: 16),
                Text(
                  AppStrings.loginFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (isLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: KisouTheme.ink,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: KisouTheme.hairline),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: KisouTheme.mistGray),
              shape: BoxShape.circle,
            ),
            child: const Text(
              'G',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4285F4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(AppStrings.googleLogin),
        ],
      ),
    );
  }
}
