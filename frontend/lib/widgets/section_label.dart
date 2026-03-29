import 'package:flutter/material.dart';

/// Standardised section header used throughout list screens.
/// Renders [label] in uppercase with the app's section-label typography.
/// Wrap in a [Padding] to control surrounding space.
class SectionLabel extends StatelessWidget {
  final String label;

  const SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
