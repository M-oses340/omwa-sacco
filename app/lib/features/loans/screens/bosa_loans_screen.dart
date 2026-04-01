import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_product.dart';
import 'loan_apply_sheet.dart';

class BosaLoansScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final double bosaSavings;
  const BosaLoansScreen(
      {super.key, required this.member, required this.bosaSavings});

  @override
  Widget build(BuildContext context) {
    final products = LoanProduct.all
        .where((p) => p.category == LoanCategory.bosa)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('BOSA Loans')),
      body: Column(
        children: [
          // Eligibility banner
          if (bosaSavings > 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your BOSA deposits: KES ${bosaSavings.toStringAsFixed(0)}\n'
                      'Max loan (5×): KES ${(bosaSavings * 5).toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: products.length,
              itemBuilder: (_, i) => _ProductCard(
                product: products[i],
                bosaSavings: bosaSavings,
                onApply: () => LoanApplySheet.show(context,
                    product: products[i],
                    member: member,
                    bosaSavings: bosaSavings),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final LoanProduct product;
  final double bosaSavings;
  final VoidCallback onApply;
  const _ProductCard(
      {required this.product,
      required this.bosaSavings,
      required this.onApply});

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
                  _InfoChip(Icons.account_balance_wallet,
                      'Up to KES ${limit.toStringAsFixed(0)}', cs,
                      color: cs.primary),
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
                    child: Text(hasActive ? 'Active loan exists' : 'Apply'),
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
          Icon(icon, size: 12, color: color ?? cs.onSurface.withValues(alpha: 0.5)),
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
