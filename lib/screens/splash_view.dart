import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';

/// Branded splash rendered in Flutter: the image logo and the KISOU text logo
/// are two SEPARATE images stacked vertically and centered. The text logo
/// swaps light/dark to stay legible on the current theme.
///
/// When the server is taking a while, [showMessage] fades in a status line
/// under the wordmark. The message slot is always reserved so the logo never
/// jumps when it appears.
class SplashView extends StatelessWidget {
  const SplashView({super.key, this.showMessage = false});

  /// Whether to show the "still loading" status line.
  final bool showMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordmark = isDark
        ? 'assets/brand/text_logo_dark.png'
        : 'assets/brand/text_logo_light.png';
    return Scaffold(
      backgroundColor: context.kisou.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/image_logo.png',
              width: 144,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Image.asset(wordmark, width: 130, fit: BoxFit.contain),
            // Reserved slot: keeps the logo centred whether or not the message
            // is showing.
            SizedBox(
              height: usesLargeText(context) ? 88 : 56,
              child: AnimatedOpacity(
                opacity: showMessage ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                // Only built while needed: the dot animation ticks on a timer,
                // so keeping it alive behind opacity 0 would schedule frames
                // forever (and hang pumpAndSettle in tests).
                child: showMessage
                    ? const Align(
                        alignment: Alignment.bottomCenter,
                        child: _LoadingMessage(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status line with dots that cycle 1 → 2 → 3 → 2 → … The dots live in a
/// fixed-width slot so the sentence itself never shifts as they change.
class _LoadingMessage extends StatefulWidget {
  const _LoadingMessage();

  @override
  State<_LoadingMessage> createState() => _LoadingMessageState();
}

class _LoadingMessageState extends State<_LoadingMessage> {
  static const _cycle = [1, 2, 3, 2];
  Timer? _timer;
  int _index = 0;
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    _timer?.cancel();
    _timer = null;
    _index = reduceMotion ? 2 : 0;
    if (!reduceMotion) {
      _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % _cycle.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.kisou.softInk);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KisouTheme.pagePad),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            AppStrings.splashLoading,
            textAlign: TextAlign.center,
            style: style,
          ),
          SizedBox(width: 18, child: Text('.' * _cycle[_index], style: style)),
        ],
      ),
    );
  }
}
