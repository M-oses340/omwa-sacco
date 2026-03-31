import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_model.dart';
import '../models/loan_product.dart';
import '../models/amortization_entry.dart';

class LoanDetailScreen extends StatelessWidget {
  final LoanModel loan;
  final Map<String, dynamic> member;

  const LoanDetailScreen(
      {super.key, required this.loan, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoanBloc()
        ..add(LoanScheduleRequested(
            loanId: loan.id, memberId: member['id'] as String)),
      child: _LoanDetailView(loan: loan, member: member),
    );
  }
}

class _LoanDetailView extends StatelessWidget {
  final LoanModel loan;
  final Map<String, dynamic> member;
  const _LoanDetailView({required this.loan, required this.member});

  @override
  Widget build(BuildContext context) {
    final product = LoanProduct.find(loan.loanType);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.displayName ?? loan.loanType),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<LoanBloc>().add(
                LoanScheduleRequested(
                    loanId: loan.id, memberId: member['id'] as String)),
          ),
        ],
      ),
      body: BlocBuilder<LoanBloc, LoanState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Summary card ──────────────────────────────────────────────
              _SummaryCard(loan: loan, product: product),
              const SizedBox(height: 16),

              // ── Key figures ───────────────────────────────────────────────
              _KeyFiguresCard(loan: loan, cs: cs),
              const SizedBox(height: 16),

              // ── Purpose & dates ───────────────────────────────────────────
              _InfoCard(loan: loan, cs: cs),
              const SizedBox(height: 16),

              // ── Amortization schedule ─────────────────────────────────────
              Text('Repayment Schedule',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (state is LoanLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              else if (state is LoanScheduleLoaded)
                _ScheduleTable(schedule: state.schedule, cs: cs)
              else if (state is LoanError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline,
                            color: cs.error, size: 40),
                        const SizedBox(height: 8),
                        Text(state.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.error)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.read<LoanBloc>().add(
                              LoanScheduleRequested(
                                  loanId: loan.id,
                                  memberId: member['id'] as String)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final LoanModel loan;
  final LoanProduct? product;
  const _SummaryCard({required this.loan, required this.product});

  @override
  Widget build(BuildContext context) {
    final progress = loan.totalRepayable > 0
        ? (loan.amountRepaid / loan.totalRepayable).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.75)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loan.loanNumber,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  if (product != null)
                    Text(product!.rateLabel,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                ],
              ),
              _StatusBadge(status: loan.status),
            ],
          ),
          const SizedBox(height: 12),
          Text('KES ${_fmt(loan.principal)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          Text('${loan.durationMonths} months',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          if (loan.dueDate != null)
            Text('Due: ${_fmtDate(loan.dueDate!)}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(0)}% repaid',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
              Text('KES ${_fmt(loan.outstandingBalance)} remaining',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Key figures ───────────────────────────────────────────────────────────────

class _KeyFiguresCard extends StatelessWidget {
  final LoanModel loan;
  final ColorScheme cs;
  const _KeyFiguresCard({required this.loan, required this.cs});

  @override
  Widget build(BuildContext context) {
    final totalInterest = loan.totalRepayable - loan.principal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _Row('Principal', 'KES ${_fmt(loan.principal)}', cs),
          _Div(),
          _Row('Monthly Repayment',
              'KES ${_fmt(loan.monthlyRepayment)}', cs,
              highlight: true),
          _Div(),
          _Row('Total Repayable', 'KES ${_fmt(loan.totalRepayable)}', cs),
          _Div(),
          _Row('Total Interest',
              'KES ${_fmt(totalInterest > 0 ? totalInterest : 0)}', cs),
          if (loan.commissionAmount > 0) ...[
            _Div(),
            _Row('Commission', 'KES ${_fmt(loan.commissionAmount)}', cs,
                color: Colors.orange),
          ],
          _Div(),
          _Row('Amount Repaid', 'KES ${_fmt(loan.amountRepaid)}', cs,
              color: Colors.green),
          _Div(),
          _Row('Outstanding', 'KES ${_fmt(loan.outstandingBalance)}', cs,
              color: loan.outstandingBalance > 0 ? cs.error : Colors.green),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _Row extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  final bool highlight;
  final Color? color;
  const _Row(this.label, this.value, this.cs,
      {this.highlight = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.7))),
            Text(value,
                style: TextStyle(
                    fontSize: highlight ? 15 : 13,
                    fontWeight: highlight
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: color ?? cs.onSurface)),
          ],
        ),
      );
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
      height: 1,
      color:
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08));
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final LoanModel loan;
  final ColorScheme cs;
  const _InfoCard({required this.loan, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loan.purpose != null && loan.purpose!.isNotEmpty) ...[
            Text('Purpose',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(loan.purpose!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _DateItem(
                    label: 'Applied',
                    date: loan.createdAt,
                    cs: cs),
              ),
              if (loan.disbursedAt != null)
                Expanded(
                  child: _DateItem(
                      label: 'Disbursed',
                      date: loan.disbursedAt!,
                      cs: cs),
                ),
              if (loan.dueDate != null)
                Expanded(
                  child: _DateItem(
                      label: 'Due Date',
                      date: loan.dueDate!,
                      cs: cs,
                      highlight: true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  final String label;
  final DateTime date;
  final ColorScheme cs;
  final bool highlight;
  const _DateItem(
      {required this.label,
      required this.date,
      required this.cs,
      this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          Text(
            '${date.day}/${date.month}/${date.year}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight ? cs.error : cs.onSurface),
          ),
        ],
      );
}

// ── Amortization schedule table ───────────────────────────────────────────────

class _ScheduleTable extends StatelessWidget {
  final List<AmortizationEntry> schedule;
  final ColorScheme cs;
  const _ScheduleTable({required this.schedule, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (schedule.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No schedule available',
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                _Hdr('Mo', flex: 1),
                _Hdr('Payment', flex: 3),
                _Hdr('Principal', flex: 3),
                _Hdr('Interest', flex: 3),
                _Hdr('Balance', flex: 3),
              ],
            ),
          ),
          // Rows
          ...schedule.map((e) => _ScheduleRow(entry: e, cs: cs)),
        ],
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  final String text;
  final int flex;
  const _Hdr(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      );
}

class _ScheduleRow extends StatelessWidget {
  final AmortizationEntry entry;
  final ColorScheme cs;
  const _ScheduleRow({required this.entry, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isEven = entry.month % 2 == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isEven
          ? cs.onSurface.withValues(alpha: 0.03)
          : Colors.transparent,
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text('${entry.month}',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.6)))),
          Expanded(
              flex: 3,
              child: Text(_fmt(entry.payment),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(
              flex: 3,
              child: Text(_fmt(entry.principal),
                  style: TextStyle(
                      fontSize: 11, color: Colors.green.shade700))),
          Expanded(
              flex: 3,
              child: Text(_fmt(entry.interest),
                  style: TextStyle(
                      fontSize: 11,
                      color: entry.interest > 0
                          ? cs.error.withValues(alpha: 0.8)
                          : cs.onSurface.withValues(alpha: 0.4)))),
          Expanded(
              flex: 3,
              child: Text(_fmt(entry.balance),
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.7)))),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color _color() => switch (status) {
        'approved' => Colors.blue,
        'disbursed' => Colors.green,
        'rejected' => Colors.red,
        'repaid' => Colors.teal,
        'defaulted' => Colors.deepOrange,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _color().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                color: _color(),
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}
