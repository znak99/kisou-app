import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../constants/app_strings.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItemData(Icons.home_rounded, AppStrings.tabHome),
    _NavItemData(Icons.insights_rounded, AppStrings.tabAnalysis),
    _NavItemData(Icons.person_rounded, AppStrings.tabProfile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KisouTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F2C2622),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  data: _items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? KisouTheme.deepSky : KisouTheme.softInk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? KisouTheme.deepSky.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(data.icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
