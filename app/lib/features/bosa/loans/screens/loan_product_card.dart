import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
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

  Color _accent() {
    // Use per-loan-type color if available, fall back to category color
    final colors = AppColors.colorsForLoanType(product.loanType);
    return colors[0];
  }

  List<Color> _gradientColors() => AppColors.colorsForLoanType(product.loanType);

  IconData _icon() {
    switch (product.category) {
      case LoanCategory.fosaAdvance:
        return Icons.account_balance;
      case LoanCategory.special:
        return Icons.flash_on;
      default:
        return Icons.savings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final gradientColors = _gradientColors();
    final limit = bosaSavings > 0 && product.depositMultiplier > 0
        ? bosaSavings * product.depositMultiplier
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_icon(), color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.displayName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(product.rateLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${product.maxMonths}mo',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            // ── Limit / notes ────────────────────────────────────────────────
            if (limit != null || product.notes != null) ...[
              const SizedBox(height: 10),
              Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 10),
            ],
            if (limit != null)
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text('Your limit: KES ${limit.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            if (product.notes != null) ...[
              const SizedBox(height: 4),
              Text(product.notes!,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
            if (product.noDividends || product.salaryRequired) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (product.noDividends)
                    const _WhiteTag('No dividends'),
                  if (product.salaryRequired)
                    const _WhiteTag('Salary via FOSA'),
                ],
              ),
            ],

            // ── Apply button ─────────────────────────────────────────────────
            const SizedBox(height: 14),
            BlocBuilder<LoanBloc, LoanState>(
              builder: (ctx, state) {
                if (state is! LoanHistoryLoaded) {
                  return _ApplyButton(onTap: onApply);
                }
                final activeLoan = state.loans
                    .where((l) =>
                        l.status == 'pending' ||
                        l.status == 'approved' ||
                        l.status == 'disbursed')
                    .firstOrNull;
                if (activeLoan != null) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text('Active ${activeLoan.status} loan',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  );
                }
                return _ApplyButton(onTap: onApply);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ApplyButton({required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Apply Now',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

class _WhiteTag extends StatelessWidget {
  final String label;
  const _WhiteTag(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      );
}

