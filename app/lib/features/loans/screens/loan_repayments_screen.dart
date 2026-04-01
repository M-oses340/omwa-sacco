import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_model.dart';
import '../models/loan_product.dart';
import '../models/amortization_entry.dart';

class LoanRepaymentsScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final LoanModel loan;
  const LoanRepaymentsScreen(
      {super.key, required this.member, required this.loan});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoanBloc()
        ..add(LoanScheduleRequested(
            loanId: loan.id, memberId: member['id'] as String)),
      child: _LoanRepaymentsView(loan: loan, member: member),
    );
  }
}

class _LoanRepaymentsView extends StatelessWidget {
  final LoanModel loan;
  final Map<String, dynamic> member;
  const _LoanRepaymentsView({required this.loan, required this.member});

  @override
  Widget build(BuildContext context) {
    final product = LoanProduct.find(loan.loanType);
    final cs = Theme.of(context).colorScheme;
    final progress = loan.totalRepayable > 0
        ? (loan.amountRepaid / loan.totalRepayable).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Repayments')),
      bottomNavigationBar: loan.status == 'disbursed'
          ? _RepayBar(loan: loan)
          : null,
      body: BlocConsumer<LoanBloc, LoanState>(
        listener: (context, state) {
          if (state is LoanRepaymentSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'KES ${state.amountPaid.toStringAsFixed(2)} repaid. '
                  'Balance: KES ${state.balanceAfter.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
            ));
            context.read<LoanBloc>().add(LoanScheduleRequested(
                loanId: loan.id, memberId: member['id'] as String));
          } else if (state is LoanError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: cs.error,
            ));
          }
        },
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Loan summary ──────────────────────────────────────────────
              Container(
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
                        Text(product?.displayName ?? loan.loanType,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        _StatusBadge(status: loan.status),
                      ],
                    ),
                    if (product != null)
                      Text(product.rateLabel,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 10),
                    Text('KES ${loan.principal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    if (loan.dueDate != null)
                      Text(
                          'Due: ${loan.dueDate!.day}/${loan.dueDate!.month}/${loan.dueDate!.year}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem('Monthly',
                            'KES ${loan.monthlyRepayment.toStringAsFixed(0)}'),
                        _StatItem('Repaid',
                            'KES ${loan.amountRepaid.toStringAsFixed(0)}'),
                        _StatItem('Outstanding',
                            'KES ${loan.outstandingBalance.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 4),
                    Text('${(progress * 100).toStringAsFixed(0)}% repaid',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Repayment schedule ────────────────────────────────────────
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
                _ScheduleView(
                  schedule: state.schedule,
                  amountRepaid: loan.amountRepaid,
                  monthlyRepayment: loan.monthlyRepayment,
                  cs: cs,
                )
              else if (state is LoanError)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Icon(Icons.error_outline, color: cs.error, size: 40),
                      const SizedBox(height: 8),
                      Text(state.message, style: TextStyle(color: cs.error)),
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

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

// ── Schedule view ─────────────────────────────────────────────────────────────

class _ScheduleView extends StatefulWidget {
  final List<AmortizationEntry> schedule;
  final double amountRepaid;
  final double monthlyRepayment;
  final ColorScheme cs;
  const _ScheduleView(
      {required this.schedule,
      required this.amountRepaid,
      required this.monthlyRepayment,
      required this.cs});

  @override
  State<_ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<_ScheduleView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final paidMonths = widget.monthlyRepayment > 0
        ? (widget.amountRepaid / widget.monthlyRepayment).floor()
        : 0;
    final visible = _expanded
        ? widget.schedule
        : widget.schedule.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: widget.cs.surfaceContainerHighest,
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
            child: const Row(
              children: [
                _Hdr('Mo', flex: 1),
                _Hdr('Payment', flex: 3),
                _Hdr('Principal', flex: 3),
                _Hdr('Interest', flex: 3),
                _Hdr('Balance', flex: 3),
              ],
            ),
          ),
          ...visible.map((e) => _ScheduleRow(
                entry: e,
                cs: widget.cs,
                isPaid: e.month <= paidMonths,
              )),
          if (!_expanded && widget.schedule.length > 6)
            TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('Show all ${widget.schedule.length} months'),
            )
          else if (_expanded)
            TextButton(
              onPressed: () => setState(() => _expanded = false),
              child: const Text('Collapse'),
            ),
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
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      );
}

class _ScheduleRow extends StatelessWidget {
  final AmortizationEntry entry;
  final ColorScheme cs;
  final bool isPaid;
  const _ScheduleRow(
      {required this.entry, required this.cs, this.isPaid = false});

  @override
  Widget build(BuildContext context) {
    final isEven = entry.month % 2 == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isPaid
          ? Colors.green.withValues(alpha: 0.06)
          : isEven
              ? cs.onSurface.withValues(alpha: 0.03)
              : Colors.transparent,
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: isPaid
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 12)
                  : Text('${entry.month}',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.6)))),
          Expanded(
              flex: 3,
              child: Text(_fmt(entry.payment),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.green.shade700 : cs.onSurface))),
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

// ── Repay bar ─────────────────────────────────────────────────────────────────

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
            onPressed:
                state is LoanLoading ? null : () => _showRepaySheet(context),
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
              Text('Outstanding: KES ${outstanding.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _QuickBtn(
                    label:
                        'Monthly\nKES ${widget.loan.monthlyRepayment.toStringAsFixed(0)}',
                    onTap: () => setState(() {
                      _payFull = false;
                      _amountCtrl.text =
                          widget.loan.monthlyRepayment.toStringAsFixed(2);
                    }),
                    selected: !_payFull,
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  _QuickBtn(
                    label:
                        'Full Balance\nKES ${outstanding.toStringAsFixed(0)}',
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
                  final val =
                      double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  if (val > outstanding + 0.01) {
                    return 'Cannot exceed KES ${outstanding.toStringAsFixed(2)}';
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
    context.read<LoanBloc>().add(
        LoanRepaymentSubmitted(loanId: widget.loan.id, amount: _amount));
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
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

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
