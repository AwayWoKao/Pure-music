import 'package:flutter/material.dart';
import 'package:pure_music/core/design_tokens.dart';

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: AppType.caption,
          fontWeight: AppType.weightSemibold,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
