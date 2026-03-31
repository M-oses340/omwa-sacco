import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_model.dart';
import '../models/loan_product.dart';

class LoansScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  const LoansScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LoanBloc()..add(LoanHistoryRequested(member['id'] as String)),
      child: _LoansView(member: member),
    );
  }
}

class _LoansView extends StatelessWidget {
  final Map<String, dynamic> member;
  const _LoansView({required this.member});

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
      floatingActionButton: BlocBuilder<LoanBloc, LoanState>(
        builder: (ctx, state) {
          final hasActive = state is LoanHistoryLoaded &&
              state.loans.any((l) =>
                  l.status == 'pending' ||
                  l.status == 'approved' ||
                  l.status == 'disbursed');
          if (hasActive) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showProductPicker(ctx),
            icon: const Icon(Icons.add),
            label: const Text('Apply'),
          );
        },
      ),
      body: BlocConsumer<LoanBloc, LoanState>(
        listener: (ctx, state) {
          if (state is LoanApplicationSuccess) {
            // Pop the application sheet if still open
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Loan application submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            ctx.read<LoanBloc>().add(LoanHistoryRequested(member['id'] as String));
          } else if (state is LoanError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: cs.error),
            );
            // Reload history to restore previous state
            ctx.read<LoanBloc>().add(LoanHistoryRequested(member['id'] as String));
          }
        },
        builder: (ctx, state) {
          if (state is LoanLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LoanHistoryLoaded) {
            return _LoanList(loans: state.loans, member: member);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void _showProductPicker(BuildContext context) {
    final bloc = context.read<LoanBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _ProductPickerSheet(member: member),
      ),
    );
  }
}

// ── Loan list ─────────────────────────────────────────────────────────────────

class _LoanList extends StatelessWidget {
  final List<LoanModel> loans;
  final Map<String, dynamic> member;
  const _LoanList({required this.loans, required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeLoan =
        loans.where((l) => l.status == 'disbursed').firstOrNull;

    return RefreshIndicator(
      onRefresh: () async => context
          .read<LoanBloc>()
          .add(LoanHistoryRequested(member['id'] as String)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (activeLoan != null) ...[
            _ActiveLoanCard(loan: activeLoan),
            const SizedBox(height: 16),
          ],
          if (loans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No loan history',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 6),
                    Text('Tap + Apply to request a loan',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            )
          else ...[
            Text('Loan History',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...loans.map((l) => _LoanTile(loan: l)),
          ],
        ],
      ),
    );
  }
}

// ── Active loan card ──────────────────────────────────────────────────────────

class _ActiveLoanCard extends StatelessWidget {
  final LoanModel loan;
  const _ActiveLoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final product = LoanProduct.find(loan.loanType);
    final progress = loan.totalRepayable > 0
        ? (loan.amountRepaid / loan.totalRepayable).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              _StatusChip(status: loan.status),
            ],
          ),
          if (product != null)
            Text(product.rateLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 10),
          Text('KES ${loan.principal.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          Text('${loan.durationMonths} months',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          if (loan.commissionAmount > 0)
            Text('Commission: KES ${loan.commissionAmount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.amber, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoItem(
                  label: 'Monthly',
                  value: 'KES ${loan.monthlyRepayment.toStringAsFixed(0)}'),
              _InfoItem(
                  label: 'Outstanding',
                  value: 'KES ${loan.outstandingBalance.toStringAsFixed(0)}'),
              _InfoItem(
                  label: 'Repaid',
                  value: 'KES ${loan.amountRepaid.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).toStringAsFixed(0)}% repaid',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label, value;
  const _InfoItem({required this.label, required this.value});

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

// ── Loan tile ─────────────────────────────────────────────────────────────────

class _LoanTile extends StatelessWidget {
  final LoanModel loan;
  const _LoanTile({required this.loan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = LoanProduct.find(loan.loanType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product?.displayName ?? loan.loanType,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${loan.loanNumber} · ${loan.durationMonths}mo',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('KES ${loan.principal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              _StatusChip(status: loan.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _color().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                color: _color(),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      );
}

// ── Product picker sheet ──────────────────────────────────────────────────────

class _ProductPickerSheet extends StatelessWidget {
  final Map<String, dynamic> member;
  const _ProductPickerSheet({required this.member});

  @override
  Widget build(BuildContext context) {
    final groups = {
      'BOSA Loans': LoanProduct.all
          .where((p) => p.category == LoanCategory.bosa)
          .toList(),
      'Salary Advances': LoanProduct.all
          .where((p) => p.category == LoanCategory.fosaAdvance)
          .toList(),
      'Special Products': LoanProduct.all
          .where((p) => p.category == LoanCategory.special)
          .toList(),
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Choose Loan Product',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: groups.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(entry.key,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                    ),
                    ...entry.value.map((product) => _ProductTile(
                          product: product,
                          onTap: () {
                            Navigator.pop(context);
                            _showApplicationSheet(context, product);
                          },
                        )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicationSheet(BuildContext context, LoanProduct product) {
    final bloc = context.read<LoanBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _LoanApplicationSheet(product: product, member: member),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final LoanProduct product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(product.displayName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (product.noDividends) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('No dividends',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.orange)),
                        ),
                      ],
                      if (product.salaryRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Salary via FOSA',
                              style:
                                  TextStyle(fontSize: 9, color: Colors.blue)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(product.rateLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6))),
                  if (product.notes != null)
                    Text(product.notes!,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${product.maxMonths} mo',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('max',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ── Application sheet ─────────────────────────────────────────────────────────

class _LoanApplicationSheet extends StatefulWidget {
  final LoanProduct product;
  final Map<String, dynamic> member;
  const _LoanApplicationSheet(
      {required this.product, required this.member});

  @override
  State<_LoanApplicationSheet> createState() => _LoanApplicationSheetState();
}

class _LoanApplicationSheetState extends State<_LoanApplicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  int _durationMonths = 1;

  @override
  void initState() {
    super.initState();
    _durationMonths = widget.product.maxMonths;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  double get _principal =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = widget.product;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final calc = _principal > 0
        ? product.calculate(_principal, _durationMonths)
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(product.rateLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              // Product notes (Muslim loan warning, Q-Cash rules, etc.)
              if (product.notes != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(product.notes!,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (KES)',
                  prefixText: 'KES ',
                  helperText: product.maxAmount != null
                      ? 'Max KES ${product.maxAmount!.toStringAsFixed(0)}'
                      : product.depositMultiplier > 0
                          ? '${product.depositMultiplier.toStringAsFixed(0)}× your BOSA deposits'
                          : null,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final val =
                      double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (val == null || val < 1000) {
                    return 'Minimum amount is KES 1,000';
                  }
                  if (product.maxAmount != null && val > product.maxAmount!) {
                    return 'Max is KES ${product.maxAmount!.toStringAsFixed(0)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Duration slider (only if product allows variable duration)
              if (product.maxMonths > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Duration: $_durationMonths months',
                        style: const TextStyle(fontSize: 13)),
                    Text('Max: ${product.maxMonths} mo',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
                Slider(
                  value: _durationMonths.toDouble(),
                  min: 1,
                  max: product.maxMonths.toDouble(),
                  divisions: product.maxMonths - 1,
                  label: '$_durationMonths mo',
                  onChanged: (v) =>
                      setState(() => _durationMonths = v.round()),
                ),
                const SizedBox(height: 4),
              ],

              // Purpose
              TextFormField(
                controller: _purposeCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'Briefly describe the loan purpose',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Purpose is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // Repayment estimate
              if (calc != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _EstItem(
                            label: 'Monthly Repayment',
                            value: 'KES ${calc.monthly.toStringAsFixed(2)}',
                            cs: cs,
                            large: true,
                          ),
                          _EstItem(
                            label: 'Total Repayable',
                            value: 'KES ${calc.total.toStringAsFixed(2)}',
                            cs: cs,
                          ),
                        ],
                      ),
                      if (calc.commission > 0) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14,
                                color: cs.onPrimaryContainer
                                    .withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Text(
                              'One-off commission: KES ${calc.commission.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onPrimaryContainer
                                      .withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              BlocBuilder<LoanBloc, LoanState>(
                builder: (ctx, state) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state is LoanLoading ? null : _submit,
                    child: state is LoanLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Application'),
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
    context.read<LoanBloc>().add(LoanApplicationSubmitted(
          loanType: widget.product.loanType,
          principal: _principal,
          durationMonths: _durationMonths,
          purpose: _purposeCtrl.text.trim(),
        ));
  }
}

class _EstItem extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  final bool large;
  const _EstItem(
      {required this.label,
      required this.value,
      required this.cs,
      this.large = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
          Text(value,
              style: TextStyle(
                  fontSize: large ? 18 : 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer)),
        ],
      );
}
