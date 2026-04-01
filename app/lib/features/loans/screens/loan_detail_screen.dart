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
      bottomNavigationBar: loan.status == 'disbursed'
          ? _RepayBar(loan: loan)
          : null,
      body: BlocConsumer<LoanBloc, LoanState>(
        listener: (context, state) {
          if (state is LoanRepaymentSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'KES ${state.amountPaid.toStringAsFixed(2)} repaid. Balance: KES ${state.balanceAfter.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
            ));
            // Reload schedule with updated data
            context.read<LoanBloc>().add(LoanScheduleRequested(
                loanId: loan.id, memberId: member['id'] as String));
          } else if (state is LoanError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ));
            context.read<LoanBloc>().add(LoanScheduleRequested(
                loanId: loan.id, memberId: member['id'] as String));
          }
        },
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

// ── Repay bottom bar ──────────────────────────────────────────────────────────

class _RepayBar extends StatelessWidget {
  final LoanModel loan;
  const _RepayBar({required this.loan});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: BlocBuilder<LoanBloc, LoanState>(
          builder: (context, state) => ElevatedButton.icon(
            onPressed: state is LoanLoading
                ? null
                : () => _showRepaySheet(context),
            icon: const Icon(Icons.payment),
            label: Text(
                'Make Repayment · KES ${loan.outstandingBalance.toStringAsFixed(0)} outstanding'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _showRepaySheet(BuildContext context) {
    final bloc = context.read<LoanBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _RepaySheet(loan: loan),
      ),
    );
  }
}

class _RepaySheet extends StatefulWidget {
  final LoanModel loan;
  const _RepaySheet({required this.loan});

  @override
  State<_RepaySheet> createState() => _RepaySheetState();
}

class _RepaySheetState extends State<_RepaySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  bool _payFull = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.loan.monthlyRepayment.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final outstanding = widget.loan.outstandingBalance;

    return BlocListener<LoanBloc, LoanState>(
      listener: (context, state) {
        if (state is LoanRepaymentSuccess || state is LoanError) {
          Navigator.pop(context);
        }
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Make Repayment',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Outstanding: KES ${outstanding.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 13)),
              const SizedBox(height: 16),

              // Quick options
              Row(
                children: [
                  _QuickBtn(
                    label: 'Monthly\nKES ${widget.loan.monthlyRepayment.toStringAsFixed(0)}',
                    onTap: () => setState(() {
                      _payFull = false;
                      _amountCtrl.text = widget.loan.monthlyRepayment.toStringAsFixed(2);
                    }),
                    selected: !_payFull,
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  _QuickBtn(
                    label: 'Full Balance\nKES ${outstanding.toStringAsFixed(0)}',
                    onTap: () => setState(() {
                      _payFull = true;
                      _amountCtrl.text = outstanding.toStringAsFixed(2);
                    }),
                    selected: _payFull,
                    cs: cs,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount (KES)', prefixText: 'KES '),
                onChanged: (_) => setState(() => _payFull = false),
                validator: (v) {
                  final val = double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  if (val > outstanding + 0.01) {
                    return 'Cannot exceed outstanding balance of KES ${outstanding.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              BlocBuilder<LoanBloc, LoanState>(
                builder: (ctx, state) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state is LoanLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52)),
                    child: state is LoanLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Pay KES ${_amount.toStringAsFixed(2)}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<LoanBloc>().add(LoanRepaymentSubmitted(
        loanId: widget.loan.id, amount: _amount));
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final ColorScheme cs;
  const _QuickBtn(
      {required this.label,
      required this.onTap,
      required this.selected,
      required this.cs});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: cs.primary, width: 1.5)
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.primary : cs.onSurface)),
          ),
        ),
      );
}
