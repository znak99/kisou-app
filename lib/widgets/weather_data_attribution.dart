import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_links.dart';
import '../config/theme.dart';
import '../constants/app_strings.dart';
import '../providers/external_link_provider.dart';

/// Compact, accessible attribution shown in the same scroll context as every
/// surface that presents processed weather data.
class WeatherDataAttribution extends ConsumerWidget {
  const WeatherDataAttribution({this.includesWbgt = false, super.key});

  final bool includesWbgt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.kisou.softInk,
      fontSize: 11,
      height: 1.3,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KisouTheme.gapXs,
          children: [
            _AttributionLink(
              label: AppStrings.openMeteoDataAttribution,
              semanticsLabel: AppStrings.openMeteoDataAttributionSemantics,
              uri: AppLinks.openMeteo,
              textStyle: textStyle,
              onOpen: (uri) => _openExternalLink(context, ref, uri),
            ),
            _AttributionLink(
              label: AppStrings.openMeteoLicense,
              semanticsLabel: AppStrings.openMeteoLicenseSemantics,
              uri: AppLinks.creativeCommonsAttribution40,
              textStyle: textStyle,
              onOpen: (uri) => _openExternalLink(context, ref, uri),
            ),
            if (includesWbgt)
              _AttributionLink(
                label: AppStrings.environmentMinistryWbgtDataAttribution,
                semanticsLabel:
                    AppStrings.environmentMinistryWbgtDataAttributionSemantics,
                uri: AppLinks.environmentMinistryWbgt,
                textStyle: textStyle,
                onOpen: (uri) => _openExternalLink(context, ref, uri),
              ),
            Semantics(
              label: AppStrings.weatherDataModifiedSemantics,
              child: ExcludeSemantics(
                child: Text(AppStrings.weatherDataModified, style: textStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalLink(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    var opened = false;
    try {
      opened = await ref.read(externalUrlLauncherProvider)(uri);
    } catch (_) {
      // Launcher errors and false results share the same recovery message.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.externalLinkOpenFailed)),
      );
    }
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.semanticsLabel,
    required this.uri,
    required this.textStyle,
    required this.onOpen,
  });

  final String label;
  final String semanticsLabel;
  final Uri uri;
  final TextStyle? textStyle;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    void open() => onOpen(uri);

    return Semantics(
      link: true,
      linkUrl: uri,
      label: semanticsLabel,
      onTap: open,
      child: ExcludeSemantics(
        child: TextButton(
          onPressed: open,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: KisouTheme.gapXs),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: textStyle?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: context.kisou.accent,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
