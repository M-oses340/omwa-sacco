import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
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

  Color _accentColor() {
    switch (product.category) {
      case LoanCategory.bosa:
        return AppColors.loanBosa;
      case LoanCategory.fosaAdvance:
        return AppColors.loanSalary;
      case LoanCategory.special:
        return AppColors.loanSpecial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accentColor();
    final limit = bosaSavings > 0 && product.depositMultiplier > 0
        ? bosaSavings * product.depositMultiplier
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored accent strip
            Container(
              height: 4,
              color: accent,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          product.category == LoanCategory.fosaAdvance
                              ? Icons.account_balance
                              : product.category == LoanCategory.special
                                  ? Icons.flash_on
                                  : Icons.savings,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.displayName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(product.rateLabel,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: accent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      // Duration badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${product.maxMonths}mo',
                            style: TextStyle(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  if (limit != null || product.notes != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                  ],
                  if (limit != null)
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 13,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          'Your limit: KES ${limit.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  if (product.notes != null) ...[
                    const SizedBox(height: 4),
                    Text(product.notes!,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                  if (product.noDividends || product.salaryRequired) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (product.noDividends)
                          _Tag('No dividends', AppColors.statusPending),
                        if (product.salaryRequired)
                          _Tag('Salary via FOSA', AppColors.loanSalary),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  BlocBuilder<LoanBloc, LoanState>(
                    builder: (ctx, state) {
                      if (state is! LoanHistoryLoaded) {
                        return _ApplyButton(
                            onTap: onApply, accent: accent);
                      }
                      final activeLoan = state.loans
                          .where((l) =>
                              l.status == 'pending' ||
                              l.status == 'approved' ||
                              l.status == 'disbursed')
                          .firstOrNull;
                      if (activeLoan != null) {
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.lock_outline, size: 14),
                            label: Text(
                              'Active ${activeLoan.status} loan',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }
                      return _ApplyButton(onTap: onApply, accent: accent);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  const _ApplyButton({required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Apply Now',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
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
