import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../models/location.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'steps/gender_step.dart';
import 'steps/location_step.dart';
import 'steps/nickname_step.dart';
import 'steps/sensitivity_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  final _pageController = PageController();

  var _currentStep = 0;
  var _nickname = '';
  String? _gender;
  String? _coldSensitivity;
  String? _heatSensitivity;
  LocationValue? _location;
  var _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _goNext() {
    if (_currentStep >= _stepCount - 1) {
      return;
    }
    _dismissKeyboard();
    final nextStep = _currentStep + 1;
    setState(() {
      _currentStep = nextStep;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      nextStep,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    if (_currentStep == 0) {
      return;
    }
    _dismissKeyboard();
    final previousStep = _currentStep - 1;
    setState(() {
      _currentStep = previousStep;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      previousStep,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isSaving) {
      return;
    }
    _dismissKeyboard();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(AppStrings.accountDeleteTitle),
          content: const Text(AppStrings.onboardingAccountDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(AppStrings.deleteAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (error) {
      if (mounted && error is! LocalAccountCleanupException) {
        setState(() => _errorMessage = AppStrings.deleteFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _finish() async {
    final location = _location;
    final gender = _gender;
    final coldSensitivity = _coldSensitivity;
    final heatSensitivity = _heatSensitivity;
    if (_isSaving ||
        _nickname.isEmpty ||
        gender == null ||
        coldSensitivity == null ||
        heatSensitivity == null ||
        location == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(userProvider.notifier)
          .updateMe(
            UserUpdate(
              nickname: _nickname,
              gender: gender,
              coldSensitivity: coldSensitivity,
              heatSensitivity: heatSensitivity,
              latitude: location.latitude,
              longitude: location.longitude,
              regionName: location.regionName,
            ),
          );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.onboardingComplete)),
      );
      await ref.read(authProvider.notifier).completeOnboarding();
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = AppStrings.saveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KisouTheme.gapS,
                  KisouTheme.gapM,
                  KisouTheme.pagePad,
                  KisouTheme.gapXs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _currentStep == 0 ? null : _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: AppStrings.back,
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(KisouTheme.rSm),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / _stepCount,
                          minHeight: 6,
                          backgroundColor: context.kisou.hairline,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.kisou.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: KisouTheme.gapM),
                    Text(
                      '${_currentStep + 1}/$_stepCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KisouTheme.pagePad,
                  ),
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _confirmDeleteAccount,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(AppStrings.onboardingAccountDelete),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KisouTheme.pagePad,
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    NicknameStep(
                      initialValue: _nickname,
                      onNext: (value) {
                        setState(() => _nickname = value);
                        _goNext();
                      },
                    ),
                    GenderStep(
                      selectedValue: _gender,
                      onSelected: (value) => setState(() => _gender = value),
                      onNext: _goNext,
                    ),
                    SensitivityStep(
                      coldSensitivity: _coldSensitivity,
                      heatSensitivity: _heatSensitivity,
                      onColdSelected: (value) {
                        setState(() => _coldSensitivity = value);
                      },
                      onHeatSelected: (value) {
                        setState(() => _heatSensitivity = value);
                      },
                      onNext: _goNext,
                    ),
                    LocationStep(
                      selectedLocation: _location,
                      onLocationSelected: (value) =>
                          setState(() => _location = value),
                      onComplete: _finish,
                      isSaving: _isSaving,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
