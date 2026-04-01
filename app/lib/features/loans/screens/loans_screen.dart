import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_model.dart';
import '../models/loan_product.dart';
import 'bosa_loans_screen.dart';
import 'salary_advances_screen.dart';
import 'special_products_screen.dart';
import 'loan_history_screen.dart';
import 'loan_repayments_screen.dart';

class LoansScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  const LoansScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LoanBloc()..add(LoanHistoryRequested(member['id'] as String)),
      child: _LoansDashboard(member: member),
    );
  }
}

class _LoansDashboard extends StatelessWidget {
  final Map<String, dynamic> member;
  const _LoansDashboard({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        actions: [
          BlocBuilder<LoanBloc, LoanState>(
            builder: (ctx, state) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: state is LoanLoading
                  ? null
                  : () => ctx
                      .read<LoanBloc>()
                      .add(LoanHistoryRequested(member['id'] as String)),
            ),
          ),
        ],
      ),
      body: BlocBuilder<LoanBloc, LoanState>(
        builder: (context, state) {
          final bosaSavings =
              state is LoanHistoryLoaded ? state.bosaSavings : 0.0;
          final loans =
              state is LoanHistoryLoaded ? state.loans : <LoanModel>[];
          final activeLoan = loans
              .where((l) =>
                  l.status == 'disbursed' ||
                  l.status == 'pending' ||
                  l.status == 'approved')
              .firstOrNull;
          final hasActiveLoan = activeLoan != null;

          return RefreshIndicator(
            onRefresh: () async => context
                .read<LoanBloc>()
                .add(LoanHistoryRequested(member['id'] as String)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ── Eligibility banner ──────────────────────────────────────
                if (state is LoanHistoryLoaded)
                  _EligibilityBanner(
                      bosaSavings: bosaSavings,
                      hasActiveLoan: hasActiveLoan,
                      activeLoan: activeLoan),
                if (state is LoanLoading)
                  const _SkeletonBanner(),
                const SizedBox(height: 16),

                // ── Dashboard cards ─────────────────────────────────────────
                Text('Products',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 10),

                _DashCard(
                  icon: Icons.savings_outlined,
                  title: 'BOSA Loans',
                  subtitle: '12 products · Up to 108 months',
                  color: AppColors.loanBosa,
                  badge: hasActiveLoan ? null : 'Apply',
                  onTap: () => _push(context, BosaLoansScreen(
                      member: member, bosaSavings: bosaSavings)),
                ),
                const SizedBox(height: 10),

                _DashCard(
                  icon: Icons.account_balance_outlined,
                  title: 'Salary Advances',
                  subtitle: '4 products · Salary via FOSA required',
                  color: AppColors.loanSalary,
                  badge: hasActiveLoan ? null : 'Apply',
                  onTap: () => _push(context, SalaryAdvancesScreen(
                      member: member, bosaSavings: bosaSavings)),
                ),
                const SizedBox(height: 10),

                _DashCard(
                  icon: Icons.flash_on_outlined,
                  title: 'Special Products',
                  subtitle: 'Q-Cash · Dividend Advance',
                  color: AppColors.loanSpecial,
                  badge: hasActiveLoan ? null : 'Apply',
                  onTap: () => _push(context, SpecialProductsScreen(
                      member: member, bosaSavings: bosaSavings)),
                ),
                const SizedBox(height: 20),

                Text('My Loans',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 10),

                _DashCard(
                  icon: Icons.history_outlined,
                  title: 'Loan History',
                  subtitle: state is LoanHistoryLoaded
                      ? '${loans.length} loan${loans.length == 1 ? '' : 's'}'
                      : 'View all your loans',
                  color: AppColors.loanHistory,
                  onTap: () => _push(context,
                      LoanHistoryScreen(member: member, loans: loans)),
                ),
                const SizedBox(height: 10),

                _DashCard(
                  icon: Icons.payment_outlined,
                  title: 'Loan Repayments',
                  subtitle: activeLoan != null
                      ? 'KES ${activeLoan.outstandingBalance.toStringAsFixed(0)} outstanding'
                      : 'No active loan',
                  color: activeLoan != null
                      ? AppColors.loanRepayment
                      : AppColors.loanRepayment.withValues(alpha: 0.3),
                  badge: activeLoan?.status == 'disbursed' ? 'Pay Now' : null,
                  onTap: activeLoan != null
                      ? () => _push(context,
                          LoanRepaymentsScreen(member: member, loan: activeLoan))
                      : null,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    final bloc = context.read<LoanBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(value: bloc, child: screen),
      ),
    ).then((_) => bloc.add(LoanHistoryRequested(member['id'] as String)));
  }
}

// ── Eligibility banner ────────────────────────────────────────────────────────

class _EligibilityBanner extends StatelessWidget {
  final double bosaSavings;
  final bool hasActiveLoan;
  final LoanModel? activeLoan;
  const _EligibilityBanner(
      {required this.bosaSavings,
      required this.hasActiveLoan,
      this.activeLoan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (hasActiveLoan && activeLoan != null) {
      final loan = activeLoan!;
      final progress = loan.totalRepayable > 0
          ? (loan.amountRepaid / loan.totalRepayable).clamp(0.0, 1.0)
          : 0.0;
      final product = LoanProduct.find(loan.loanType);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(product?.displayName ?? loan.loanType,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                _StatusChip(status: loan.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('KES ${loan.principal.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toStringAsFixed(0)}% repaid',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                Text(
                    'KES ${loan.outstandingBalance.toStringAsFixed(0)} left',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Loan Eligibility',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer)),
                const SizedBox(height: 2),
                Text(
                  bosaSavings > 0
                      ? 'Up to KES ${_fmt(bosaSavings * 5)} (BOSA) · '
                          'KES ${_fmt(bosaSavings * 4)} (Muslim)'
                      : 'Make BOSA deposits to qualify for loans',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _SkeletonBanner extends StatelessWidget {
  const _SkeletonBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

// ── Dashboard card ────────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _DashCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: enabled ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: enabled
                        ? color
                        : color.withValues(alpha: 0.4),
                    size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: enabled
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                )
              else
                Icon(Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared status chip ────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() => switch (status) {
        'approved' => AppColors.statusApproved,
        'disbursed' => AppColors.statusDisbursed,
        'rejected' => AppColors.statusRejected,
        'repaid' => AppColors.statusRepaid,
        'defaulted' => AppColors.statusDefaulted,
        _ => AppColors.statusPending,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                color: _color(),
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );
}
