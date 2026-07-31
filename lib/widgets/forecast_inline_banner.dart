import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ads_provider.dart';
import '../providers/shell_provider.dart';
import '../services/ad_gateway.dart';
import '../config/theme.dart';

final bannerRetryDelaysProvider = Provider<List<Duration>>((ref) {
  return const [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];
});

class ForecastInlineBanner extends ConsumerStatefulWidget {
  const ForecastInlineBanner({super.key});

  @override
  ConsumerState<ForecastInlineBanner> createState() =>
      _ForecastInlineBannerState();
}

class _ForecastInlineBannerState extends ConsumerState<ForecastInlineBanner>
    with WidgetsBindingObserver {
  InlineBannerHandle? _handle;
  int? _loadedWidth;
  int? _loadedConsentGeneration;
  int _loadToken = 0;
  int _attempt = 0;
  bool _retriesExhausted = false;
  bool _loading = false;
  int? _loadingWidth;
  int? _loadingConsentGeneration;
  int? _lastRequestWidth;
  int? _lastRequestConsentGeneration;
  Timer? _retryTimer;
  bool _appIsActive = true;

  bool _desired = false;
  int _desiredWidth = 0;
  int _desiredConsentGeneration = 0;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appIsActive == active) {
      return;
    }
    setState(() => _appIsActive = active);
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsProvider);
    final isForecastTab = ref.watch(shellTabProvider) == ShellTab.forecast;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        final desired =
            ads.mayLoadAds && isForecastTab && _appIsActive && width > 0;
        _scheduleSync(
          desired: desired,
          width: width,
          consentGeneration: ads.generation,
        );
        final handle = _handle;
        if (!desired ||
            handle == null ||
            _loadedWidth != width ||
            _loadedConsentGeneration != ads.generation) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: KisouTheme.gapL),
          child: SizedBox(
            width: double.infinity,
            height: handle.height,
            child: KeyedSubtree(
              key: ObjectKey(handle),
              child: handle.buildWidget(),
            ),
          ),
        );
      },
    );
  }

  void _scheduleSync({
    required bool desired,
    required int width,
    required int consentGeneration,
  }) {
    _desired = desired;
    _desiredWidth = width;
    _desiredConsentGeneration = consentGeneration;
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) {
        _sync();
      }
    });
  }

  void _sync() {
    final currentMatches =
        _handle != null &&
        _loadedWidth == _desiredWidth &&
        _loadedConsentGeneration == _desiredConsentGeneration;
    if (!_desired) {
      _cancelPendingLoad(resetAttempts: true);
      _retireCurrentHandle();
      return;
    }
    if (_loading &&
        (_loadingWidth != _desiredWidth ||
            _loadingConsentGeneration != _desiredConsentGeneration)) {
      _cancelPendingLoad(resetAttempts: true);
    }
    if (_retriesExhausted &&
        (_lastRequestWidth != _desiredWidth ||
            _lastRequestConsentGeneration != _desiredConsentGeneration)) {
      _attempt = 0;
      _retriesExhausted = false;
    }
    if (currentMatches ||
        _loading ||
        _retryTimer != null ||
        _retriesExhausted) {
      return;
    }
    if (_handle != null) {
      _retireCurrentHandle();
    }
    _startLoad();
  }

  Future<void> _startLoad() async {
    final token = ++_loadToken;
    final width = _desiredWidth;
    final consentGeneration = _desiredConsentGeneration;
    final policy = ref.read(adsRuntimePolicyProvider);
    _loading = true;
    _loadingWidth = width;
    _loadingConsentGeneration = consentGeneration;
    _lastRequestWidth = width;
    _lastRequestConsentGeneration = consentGeneration;
    _attempt++;
    try {
      final handle = await ref
          .read(adGatewayProvider)
          .loadInlineBanner(width: width, adUnitId: policy.ids.bannerId);
      final stale =
          !mounted ||
          token != _loadToken ||
          !_desired ||
          width != _desiredWidth ||
          consentGeneration != _desiredConsentGeneration;
      if (stale) {
        await handle.dispose();
        return;
      }
      _attempt = 0;
      _retriesExhausted = false;
      setState(() {
        _handle = handle;
        _loadedWidth = width;
        _loadedConsentGeneration = consentGeneration;
      });
    } catch (_) {
      if (mounted &&
          token == _loadToken &&
          _desired &&
          width == _desiredWidth &&
          consentGeneration == _desiredConsentGeneration) {
        _scheduleRetry();
      }
    } finally {
      if (token == _loadToken) {
        _loading = false;
        _loadingWidth = null;
        _loadingConsentGeneration = null;
      }
      if (mounted) {
        _scheduleSync(
          desired: _desired,
          width: _desiredWidth,
          consentGeneration: _desiredConsentGeneration,
        );
      }
    }
  }

  void _scheduleRetry() {
    final delays = ref.read(bannerRetryDelaysProvider);
    if (_attempt > delays.length) {
      _retriesExhausted = true;
      return;
    }
    _retryTimer = Timer(delays[_attempt - 1], () {
      _retryTimer = null;
      if (mounted) {
        _sync();
      }
    });
  }

  void _cancelPendingLoad({required bool resetAttempts}) {
    _loadToken++;
    _loading = false;
    _loadingWidth = null;
    _loadingConsentGeneration = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (resetAttempts) {
      _attempt = 0;
      _retriesExhausted = false;
    }
  }

  void _retireCurrentHandle() {
    final oldHandle = _handle;
    if (oldHandle == null) {
      return;
    }
    setState(() {
      _handle = null;
      _loadedWidth = null;
      _loadedConsentGeneration = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_disposeHandle(oldHandle));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelPendingLoad(resetAttempts: true);
    final oldHandle = _handle;
    _handle = null;
    if (oldHandle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_disposeHandle(oldHandle));
      });
    }
    super.dispose();
  }

  Future<void> _disposeHandle(InlineBannerHandle handle) async {
    try {
      await handle.dispose();
    } catch (_) {
      // The widget has already removed this handle. A platform cleanup error
      // must not become an unhandled Future or resurrect the banner slot.
    }
  }
}
