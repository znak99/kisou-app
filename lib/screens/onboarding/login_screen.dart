import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              const Center(
                child: BrandLogo(variant: BrandLogoVariant.mark, size: 76),
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

              // Social sign-in in its natural position near the bottom.
              SignInWithAppleButton(
                text: AppStrings.appleLogin,
                height: 50,
                style: Theme.of(context).brightness == Brightness.dark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                borderRadius: BorderRadius.circular(25),
                onPressed: isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).loginWithApple(),
              ),
              const SizedBox(height: KisouTheme.gapM),
              _GoogleSignInButton(
                isLoading: isLoading,
                onPressed: () =>
                    ref.read(authProvider.notifier).loginWithGoogle(),
              ),

              if (hasError) ...[
                const SizedBox(height: KisouTheme.gapL),
                Text(
                  AppStrings.loginFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
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
    final c = context.kisou;
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: c.hairline),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/brand/google_logo.svg',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: KisouTheme.gapM),
          Text(
            AppStrings.googleLogin,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
