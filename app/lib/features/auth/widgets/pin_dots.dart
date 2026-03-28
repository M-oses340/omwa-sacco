import 'package:flutter/material.dart';

/// Shared PIN dots indicator.
class PinDots extends StatelessWidget {
  final int filled;
  final int total;

  const PinDots({super.key, required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(
                color: cs.outline.withValues(alpha: 0.5), width: 1.5),
            borderRadius: BorderRadius.circular(8),
            color: isFilled
                ? cs.primary.withValues(alpha: 0.2)
                : Colors.transparent,
          ),
          child: isFilled
              ? Center(
                  child: Icon(Icons.circle, color: cs.primary, size: 14))
              : null,
        );
      }),
    );
  }
}
