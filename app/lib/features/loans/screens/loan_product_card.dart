import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_product.dart';

class LoanProductCard extends StatelessWidget {
  final LoanProduct product;
  final double bosaSavings;
  final VoidCallback onApply;

  const LoanProductCard({
    super.key,
    required this.product,
    required this.bosaSavings,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final limit = bosaSavings > 0 && product.depositMultiplier > 0
        ? bosaSavings * product.depositMultiplier
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(product.displayName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (product.noDividends)
                  _Tag('No dividends', Colors.orange),
                if (product.salaryRequired) ...[
                  const SizedBox(width: 4),
                  _Tag('Salary via FOSA', Colors.blue),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(Icons.schedule,
                    'Up to ${product.maxMonths} months', cs),
                _InfoChip(Icons.percent, product.rateLabel, cs),
                if (limit != null)
                  _InfoChip(
                    Icons.account_balance_wallet,
                    'Up to KES ${limit.toStringAsFixed(0)}',
                    cs,
                    color: cs.primary,
                  ),
              ],
            ),
            if (product.notes != null) ...[
              const SizedBox(height: 6),
              Text(product.notes!,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5))),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: BlocBuilder<LoanBloc, LoanState>(
                builder: (ctx, state) {
                  final hasActive = state is LoanHistoryLoaded &&
                      state.loans.any((l) =>
                          l.status == 'pending' ||
                          l.status == 'approved' ||
                          l.status == 'disbursed');
                  return OutlinedButton(
                    onPressed: hasActive ? null : onApply,
                    child:
                        Text(hasActive ? 'Active loan exists' : 'Apply'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color? color;
  const _InfoChip(this.icon, this.label, this.cs, {this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: color ?? cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color ?? cs.onSurface.withValues(alpha: 0.6))),
        ],
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600)),
      );
}
