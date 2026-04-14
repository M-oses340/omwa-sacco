import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/pay_bills_bloc.dart';

Future<bool?> showPayBillsSheet(BuildContext context, Map<String, dynamic> member, {Map<String, dynamic>? initialData}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => PayBillsBloc(),
      child: _PayBillsSheet(member: member, initialData: initialData),
    ),
  );
}

class _PayBillsSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  final Map<String, dynamic>? initialData;
  const _PayBillsSheet({required this.member, this.initialData});
  @override
  State<_PayBillsSheet> createState() => _PayBillsSheetState();
}

class _PayBillsSheetState extends State<_PayBillsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    // If scanned a till, open on till tab (index 1)
    final initialIndex = widget.initialData?['type'] == 'till' ? 1 : 0;
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<PayBillsBloc, PayBillsState>(
      listener: (_, state) {
        if (state is PayBillsSuccess) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        } else if (state is PayBillsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: cs.error),
          );
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Icon(Icons.receipt_long, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Pay Bills', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              ),
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(icon: Icon(Icons.business), text: 'Paybill'),
                  Tab(icon: Icon(Icons.storefront), text: 'Lipa na M-Pesa'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _PaybillForm(member: widget.member, scrollCtrl: scrollCtrl, initialData: widget.initialData),
                    _TillForm(member: widget.member, scrollCtrl: scrollCtrl, initialData: widget.initialData),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Paybill Form ──────────────────────────────────────────────────────────────

class _PaybillForm extends StatefulWidget {
  final Map<String, dynamic> member;
  final ScrollController scrollCtrl;
  final Map<String, dynamic>? initialData;
  const _PaybillForm({required this.member, required this.scrollCtrl, this.initialData});
  @override
  State<_PaybillForm> createState() => _PaybillFormState();
}

class _PaybillFormState extends State<_PaybillForm> {
  final _formKey = GlobalKey<FormState>();
  final _businessNumberCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData?['type'] == 'paybill') {
      _businessNumberCtrl.text = widget.initialData?['businessNumber'] ?? '';
      _accountNumberCtrl.text = widget.initialData?['accountNumber'] ?? '';
      if (widget.initialData?['amount'] != null) {
        _amountCtrl.text = widget.initialData!['amount'].toString();
      }
    }
  }

  static const _commonPaybills = [
    {'name': 'KPLC Prepaid', 'number': '888880'},
    {'name': 'KPLC Postpaid', 'number': '888882'},
    {'name': 'Nairobi Water', 'number': '888861'},
    {'name': 'DSTV', 'number': '444700'},
    {'name': 'Safaricom Home', 'number': '200200'},
  ];

  @override
  void dispose() {
    _businessNumberCtrl.dispose();
    _accountNumberCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    ctx.read<PayBillsBloc>().add(PayBillSubmitted(
      memberId: widget.member['id'],
      businessNumber: _businessNumberCtrl.text.trim(),
      accountNumber: _accountNumberCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayBillsBloc, PayBillsState>(
      builder: (ctx, state) => SingleChildScrollView(
        controller: widget.scrollCtrl,
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Select', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonPaybills.map((p) => ActionChip(
                  label: Text(p['name']!),
                  onPressed: () => setState(() => _businessNumberCtrl.text = p['number']!),
                )).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _businessNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Business Number', prefixIcon: Icon(Icons.business)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberCtrl,
                decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.tag)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Amount (KES)', prefixIcon: Icon(Icons.payments_outlined)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state is PayBillsLoading ? null : () => _submit(ctx),
                  child: state is PayBillsLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Pay Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Till (Buy Goods) Form ─────────────────────────────────────────────────────

class _TillForm extends StatefulWidget {
  final Map<String, dynamic> member;
  final ScrollController scrollCtrl;
  final Map<String, dynamic>? initialData;
  const _TillForm({required this.member, required this.scrollCtrl, this.initialData});
  @override
  State<_TillForm> createState() => _TillFormState();
}

class _TillFormState extends State<_TillForm> {
  final _formKey = GlobalKey<FormState>();
  final _tillNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData?['type'] == 'till') {
      _tillNumberCtrl.text = widget.initialData?['tillNumber'] ?? '';
      if (widget.initialData?['amount'] != null) {
        _amountCtrl.text = widget.initialData!['amount'].toString();
      }
    }
  }

  @override
  void dispose() {
    _tillNumberCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    ctx.read<PayBillsBloc>().add(TillPaymentSubmitted(
      memberId: widget.member['id'],
      tillNumber: _tillNumberCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<PayBillsBloc, PayBillsState>(
      builder: (ctx, state) => SingleChildScrollView(
        controller: widget.scrollCtrl,
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.storefront, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Buy Goods & Services using M-Pesa Till Number',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tillNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Till Number', prefixIcon: Icon(Icons.storefront)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Amount (KES)', prefixIcon: Icon(Icons.payments_outlined)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state is PayBillsLoading ? null : () => _submit(ctx),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  child: state is PayBillsLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Pay Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
