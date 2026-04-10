import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/airtime_bloc.dart';

Future<bool?> showBuyAirtimeSheet(BuildContext context, Map<String, dynamic> member) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => AirtimeBloc(),
      child: _AirtimeSheet(member: member),
    ),
  );
}

class _AirtimeSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  const _AirtimeSheet({required this.member});
  @override
  State<_AirtimeSheet> createState() => _AirtimeSheetState();
}

class _AirtimeSheetState extends State<_AirtimeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _network = 'Safaricom';

  static const _networks = ['Safaricom', 'Airtel', 'Telkom'];
  static const _quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    ctx.read<AirtimeBloc>().add(AirtimePurchased(
      memberId: widget.member['id'],
      phoneNumber: _phoneCtrl.text.trim(),
      network: _network,
      amount: double.parse(_amountCtrl.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<AirtimeBloc, AirtimeState>(
      listener: (ctx, state) {
        if (state is AirtimeSuccess) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        } else if (state is AirtimeError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: cs.error),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Icon(Icons.sim_card, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Buy Airtime', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Network', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Row(
                        children: _networks.map((n) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(n),
                            selected: _network == n,
                            onSelected: (_) => setState(() => _network = n),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone), hintText: '07XXXXXXXX'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 9) return 'Enter a valid phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Quick Amount', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _quickAmounts.map((a) => ActionChip(
                          label: Text('KES $a'),
                          onPressed: () => setState(() => _amountCtrl.text = a.toString()),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        decoration: const InputDecoration(labelText: 'Amount (KES)', prefixIcon: Icon(Icons.payments_outlined)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final n = double.tryParse(v);
                          if (n == null || n < 10) return 'Minimum amount is KES 10';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      BlocBuilder<AirtimeBloc, AirtimeState>(
                        builder: (ctx, state) => SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: state is AirtimeLoading ? null : () => _submit(ctx),
                            child: state is AirtimeLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Buy Airtime'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
