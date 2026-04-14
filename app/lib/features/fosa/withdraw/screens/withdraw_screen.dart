import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/withdraw_bloc.dart';

Future<bool?> showWithdrawSheet(BuildContext context, Map<String, dynamic> member) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => WithdrawBloc(),
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
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.member['phone_number'] ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<WithdrawBloc>().add(WithdrawInitiated(
      memberId: widget.member['id'],
      amount: double.parse(_amountController.text.trim()),
      phoneNumber: _phoneController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<WithdrawBloc, WithdrawState>(
      listener: (context, state) {
        if (state is WithdrawSuccess) {
          setState(() => _successMessage = state.message);
        } else if (state is WithdrawError) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: cs.error));
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomPadding),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BlocBuilder<WithdrawBloc, WithdrawState>(
          builder: (context, state) {
            final isLoading = state is WithdrawLoading;
            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.arrow_upward, color: Colors.orange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Withdraw from FOSA', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Via M-Pesa', style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                      ]),
                    ]),
                    const SizedBox(height: 20),
                    if (_successMessage == null) ...[
                      Text('Quick amounts', style: tt.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [500, 1000, 2000, 5000].map((amt) => ActionChip(
                          label: Text('KES $amt'),
                          onPressed: () => _amountController.text = amt.toString(),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: 'KES  ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'M-Pesa Phone Number',
                          hintText: '07XXXXXXXX',
                          prefixIcon: const Icon(Icons.phone),
                          suffixIcon: const Tooltip(message: 'Only your registered number can be used', child: Icon(Icons.lock_outline, size: 18)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number required' : null,
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_successMessage!, style: tt.bodyMedium?.copyWith(color: Colors.green.shade800))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: cs.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onPrimary)),
                        ),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _submit,
                          icon: isLoading
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2))
                              : const Icon(Icons.arrow_upward),
                          label: Text(isLoading ? 'Processing...' : 'Withdraw via M-Pesa',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onPrimary)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
