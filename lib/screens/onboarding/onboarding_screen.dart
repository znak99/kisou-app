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
import 'steps/time_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 5;
  static const _defaultDepartureTime = TimeOfDay(hour: 9, minute: 0);
  static const _defaultReturnTime = TimeOfDay(hour: 18, minute: 0);

  final _pageController = PageController();

  var _currentStep = 0;
  var _nickname = '';
  String? _gender;
  String? _coldSensitivity;
  String? _heatSensitivity;
  LocationValue? _location;
  TimeOfDay _departureTime = _defaultDepartureTime;
  TimeOfDay _returnTime = _defaultReturnTime;
  var _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentStep >= _stepCount - 1) {
      return;
    }
    final nextStep = _currentStep + 1;
    setState(() {
      _currentStep = nextStep;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _goBack() {
    if (_currentStep == 0) {
      return;
    }
    final previousStep = _currentStep - 1;
    setState(() {
      _currentStep = previousStep;
      _errorMessage = null;
    });
    _pageController.animateToPage(
      previousStep,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish({required bool useDefaultTimes}) async {
    final location = _location;
    final gender = _gender;
    final coldSensitivity = _coldSensitivity;
    final heatSensitivity = _heatSensitivity;
    if (_nickname.isEmpty ||
        gender == null ||
        coldSensitivity == null ||
        heatSensitivity == null ||
        location == null) {
      return;
    }

    final departureTime = useDefaultTimes
        ? _defaultDepartureTime
        : _departureTime;
    final returnTime = useDefaultTimes ? _defaultReturnTime : _returnTime;

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
              departureTime: formatApiTime(departureTime),
              returnTime: formatApiTime(returnTime),
            ),
          );

      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: const Text(AppStrings.onboardingComplete),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(AppStrings.ok),
              ),
            ],
          );
        },
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            KisouTheme.accent,
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
                      onLocationSelected: (value) {
                        setState(() => _location = value);
                        _goNext();
                      },
                    ),
                    TimeStep(
                      departureTime: _departureTime,
                      returnTime: _returnTime,
                      onDepartureChanged: (value) {
                        setState(() => _departureTime = value);
                      },
                      onReturnChanged: (value) {
                        setState(() => _returnTime = value);
                      },
                      onComplete: () => _finish(useDefaultTimes: false),
                      onSkip: () => _finish(useDefaultTimes: true),
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
