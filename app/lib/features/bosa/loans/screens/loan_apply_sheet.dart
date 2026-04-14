import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_model.dart';
import '../models/loan_product.dart';

/// Reusable bottom sheet for applying to any loan product.
class LoanApplySheet extends StatefulWidget {
  final LoanProduct product;
  final Map<String, dynamic> member;
  final double bosaSavings;

  const LoanApplySheet({
    super.key,
    required this.product,
    required this.member,
    required this.bosaSavings,
  });

  static Future<bool?> show(
    BuildContext context, {
    required LoanProduct product,
    required Map<String, dynamic> member,
    required double bosaSavings,
  }) {
    final bloc = context.read<LoanBloc>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: LoanApplySheet(
            product: product, member: member, bosaSavings: bosaSavings),
      ),
    );
  }

  @override
  State<LoanApplySheet> createState() => _LoanApplySheetState();
}

class _LoanApplySheetState extends State<LoanApplySheet> {
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

  double get _loanLimit {
    if (widget.product.depositMultiplier <= 0) return double.infinity;
    return widget.bosaSavings * widget.product.depositMultiplier;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = widget.product;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final calc = _principal > 0 ? product.calculate(_principal, _durationMonths) : null;

    return BlocListener<LoanBloc, LoanState>(
      listener: (context, state) {
        if (state is LoanApplicationSuccess) {
          Navigator.pop(context, true);
          _showSuccessDialog(context, state.loan);
        } else if (state is LoanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: cs.error),
          );
        }
      },
      child: Padding(
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
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),

                // Loan limit hint
                if (_loanLimit != double.infinity) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Your limit: KES ${_loanLimit.toStringAsFixed(0)} '
                            '(${product.depositMultiplier.toStringAsFixed(0)}× '
                            'KES ${widget.bosaSavings.toStringAsFixed(0)} deposits)',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Notes
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
                  inputFormatters: [_ThousandsFormatter()],
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
                    if (product.maxAmount != null &&
                        val > product.maxAmount!) {
                      return 'Max is KES ${product.maxAmount!.toStringAsFixed(0)}';
                    }
                    if (_loanLimit != double.infinity && val > _loanLimit) {
                      return 'Exceeds your limit of KES ${_loanLimit.toStringAsFixed(0)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Duration slider
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

                // Estimate
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

  void _showSuccessDialog(BuildContext context, LoanModel loan) {
    final product = LoanProduct.find(loan.loanType);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.green, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Application Submitted',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(loan.loanNumber,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _SummaryRow('Product', product?.displayName ?? loan.loanType),
            _SummaryRow('Amount', 'KES ${loan.principal.toStringAsFixed(2)}'),
            _SummaryRow('Duration', '${loan.durationMonths} months'),
            _SummaryRow('Monthly', 'KES ${loan.monthlyRepayment.toStringAsFixed(2)}'),
            _SummaryRow('Total', 'KES ${loan.totalRepayable.toStringAsFixed(2)}'),
            if (loan.commissionAmount > 0)
              _SummaryRow('Commission', 'KES ${loan.commissionAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pending approval by the SACCO.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
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

class _SummaryRow extends StatelessWidget {
  final String label, value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final raw = newValue.text.replaceAll(',', '');
    final hasDecimal = raw.contains('.');
    final parts = raw.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : null;
    if (intPart.isNotEmpty && int.tryParse(intPart) == null) return oldValue;
    final formatted = intPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final result =
        hasDecimal ? '$formatted.${decPart ?? ''}' : formatted;
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
