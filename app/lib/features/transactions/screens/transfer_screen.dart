import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/transaction_bloc.dart';

Future<bool?> showTransferSheet(
    BuildContext context, Map<String, dynamic> member) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => TransactionBloc(),
      child: _TransferSheet(member: member),
    ),
  );
}

class _TransferSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  const _TransferSheet({required this.member});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz,
                        color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Transfer',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Internal (Sacco)'),
                Tab(text: 'External (Bank)'),
              ],
            ),
            SizedBox(
              height: 380,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InternalTransferForm(member: widget.member),
                  _ExternalTransferForm(member: widget.member),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internal Transfer ────────────────────────────────────────────────────────

class _InternalTransferForm extends StatefulWidget {
  final Map<String, dynamic> member;
  const _InternalTransferForm({required this.member});

  @override
  State<_InternalTransferForm> createState() => _InternalTransferFormState();
}

class _InternalTransferFormState extends State<_InternalTransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _memberNumberController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _memberNumberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<TransactionBloc>().add(InternalTransferInitiated(
          fromMemberId: widget.member['id'],
          toMemberNumber: _memberNumberController.text.trim().toUpperCase(),
          amount: double.parse(_amountController.text.trim()),
          note: _noteController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        final isLoading = state is TransactionLoading;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _memberNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Recipient Member Number',
                    hintText: 'OM0001',
                    prefixIcon: const Icon(Icons.person_search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter member number';
                    }
                    if (v.trim().toUpperCase() ==
                        widget.member['member_number']) {
                      return 'Cannot transfer to yourself';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                    if (n < 10) return 'Minimum transfer is KES 10';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: const Icon(Icons.note_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                        : const Icon(Icons.swap_horiz),
                    label: Text(
                      isLoading ? 'Processing...' : 'Transfer',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
    );
  }
}

// ─── External Transfer ────────────────────────────────────────────────────────

class _ExternalTransferForm extends StatefulWidget {
  final Map<String, dynamic> member;
  const _ExternalTransferForm({required this.member});

  @override
  State<_ExternalTransferForm> createState() => _ExternalTransferFormState();
}

class _ExternalTransferFormState extends State<_ExternalTransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _accountNameController = TextEditingController();
  String? _selectedBankCode;
  List<Map<String, String>> _banks = [];
  bool _loadingBanks = true;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.functions.invoke('bank-codes');
      final data = res.data as Map<String, dynamic>;
      final list = (data['banks'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _banks = list
            .map((b) => {
                  'code': b['code'].toString(),
                  'name': b['name'].toString(),
                })
            .toList();
        _loadingBanks = false;
      });
    } catch (_) {
      setState(() => _loadingBanks = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<TransactionBloc>().add(ExternalTransferInitiated(
          fromMemberId: widget.member['id'],
          bankCode: _selectedBankCode!,
          accountNumber: _accountController.text.trim(),
          accountName: _accountNameController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        final isLoading = state is TransactionLoading;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _loadingBanks
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                  initialValue: _selectedBankCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Select Bank',
                    prefixIcon: const Icon(Icons.account_balance),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _banks.map((b) {
                    return DropdownMenuItem(
                      value: b['code'],
                      child: Text(b['name']!,
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedBankCode = v),
                  validator: (v) =>
                      v == null ? 'Select a bank' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter account number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter account name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                    if (n < 100) return 'Minimum bank transfer is KES 100';
                    return null;
                  },
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
                        : const Icon(Icons.account_balance),
                    label: Text(
                      isLoading ? 'Processing...' : 'Transfer to Bank',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
    );
  }
}
