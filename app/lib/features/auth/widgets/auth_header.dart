import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.account_balance, color: cs.primary, size: 24),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Omwa Sacco',
                style: TextStyle(
                    color: cs.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            Text('United for Prosperity',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
