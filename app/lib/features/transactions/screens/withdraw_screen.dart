import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transaction_bloc.dart';

Future<bool?> showWithdrawSheet(
    BuildContext context, Map<String, dynamic> member) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => TransactionBloc(),
      child: _WithdrawSheet(member: member),
    ),
  );
}

class _WithdrawSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  const _WithdrawSheet({required this.member});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String _method = 'mpesa';

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    // ignore: avoid_print
    print('[WITHDRAW] method=$_method amount=$amount phone=${_phoneController.text.trim()} memberId=${widget.member['id']}');
    context.read<TransactionBloc>().add(WithdrawInitiated(
          memberId: widget.member['id'],
          amount: amount,
          method: _method,
          phoneNumber: _phoneController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionSuccess) {
          Navigator.of(context).pop(true);
        } else if (state is TransactionError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: cs.error,
          ));
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomPadding),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            final isLoading = state is TransactionLoading;
            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_upward,
                              color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Withdraw from FOSA',
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text('M-Pesa or ATM',
                                style: tt.bodySmall?.copyWith(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Method selector
                    Text('Withdrawal method',
                        style: tt.labelMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _MethodCard(
                            label: 'M-Pesa',
                            icon: Icons.phone_android,
                            selected: _method == 'mpesa',
                            onTap: () => setState(() => _method = 'mpesa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MethodCard(
                            label: 'ATM',
                            icon: Icons.credit_card,
                            selected: _method == 'atm',
                            onTap: () => setState(() => _method = 'atm'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick amounts
                    Text('Quick amounts',
                        style: tt.labelMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [500, 1000, 2000, 5000].map((amt) {
                        return ActionChip(
                          label: Text('KES $amt'),
                          onPressed: () =>
                              _amountController.text = amt.toString(),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Amount field
                    TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: tt.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: 'KES  ',
                        prefixStyle: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter amount';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        if (n < 100) return 'Minimum withdrawal is KES 100';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Phone field (M-Pesa only)
                    if (_method == 'mpesa')
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'M-Pesa Phone Number',
                          hintText: '07XXXXXXXX',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (_method != 'mpesa') return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          if (!RegExp(r'^(?:\+254|0)[17]\d{8}$')
                              .hasMatch(v.trim())) {
                            return 'Enter a valid Kenyan phone number';
                          }
                          return null;
                        },
                      ),

                    if (_method == 'atm')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Funds will be deducted immediately. Collect at any ATM using your card.',
                                style: tt.bodySmall?.copyWith(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: cs.onPrimary, strokeWidth: 2))
                            : const Icon(Icons.arrow_upward),
                        label: Text(
                          isLoading ? 'Processing...' : 'Withdraw',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.5),
                size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
