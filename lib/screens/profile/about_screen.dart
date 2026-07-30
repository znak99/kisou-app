import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_links.dart';
import '../../config/theme.dart';
import '../../constants/app_strings.dart';
import '../../providers/external_link_provider.dart';
import '../../widgets/brand_logo.dart';

class AboutKisouScreen extends ConsumerWidget {
  const AboutKisouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.aboutKisou)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KisouTheme.pagePad,
            KisouTheme.gapL,
            KisouTheme.pagePad,
            32,
          ),
          children: [
            const Center(
              child: BrandLogo(variant: BrandLogoVariant.mark, size: 72),
            ),
            const SizedBox(height: KisouTheme.gapM),
            Text(
              AppStrings.appName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: KisouTheme.gapS),
            Text(
              AppStrings.aboutDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: KisouTheme.gapXl),
            ClayCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      final value = info == null
                          ? '—'
                          : '${info.version} (${info.buildNumber})';
                      return _AboutRow(
                        icon: Icons.info_outline_rounded,
                        title: AppStrings.versionLabel,
                        value: value,
                      );
                    },
                  ),
                  const Divider(),
                  _AboutRow(
                    icon: Icons.description_outlined,
                    title: AppStrings.openSourceLicenses,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: AppStrings.appName,
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(KisouTheme.gapL),
                        child: BrandLogo(
                          variant: BrandLogoVariant.mark,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  _AboutRow(
                    icon: Icons.cloud_outlined,
                    title: AppStrings.openMeteoAttribution,
                    onTap: () => _openExternalLink(
                      context,
                      ref,
                      AppLinks.openMeteoTerms,
                    ),
                  ),
                  const Divider(),
                  _AboutRow(
                    icon: Icons.device_thermostat_outlined,
                    title: AppStrings.environmentMinistryWbgtAttribution,
                    onTap: () => _openExternalLink(
                      context,
                      ref,
                      AppLinks.environmentMinistryWbgt,
                    ),
                  ),
                ],
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
      // Show the same recovery message for launcher errors and false results.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.externalLinkOpenFailed)),
      );
    }
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = usesLargeText(context);
    final heading = Row(
      children: [
        Icon(icon, color: context.kisou.accent),
        const SizedBox(width: KisouTheme.gapM),
        Expanded(child: Text(title)),
        if (value == null)
          Icon(Icons.chevron_right_rounded, color: context.kisou.softInk),
      ],
    );
    return Semantics(
      button: onTap != null,
      label: title,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KisouTheme.gapL,
                vertical: KisouTheme.gapM,
              ),
              child: largeText && value != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading,
                        const SizedBox(height: KisouTheme.gapS),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Text(
                            value!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: heading),
                        if (value != null)
                          Text(
                            value!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
