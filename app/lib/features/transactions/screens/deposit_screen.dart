import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transaction_bloc.dart';

class DepositScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const DepositScreen({super.key, required this.member});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Timer? _pollTimer;

  @override
  void dispose() {
    _amountController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    context.read<TransactionBloc>().add(DepositInitiated(
          memberId: widget.member['id'],
          amount: amount,
        ));
  }

  void _startPolling(String transactionId) {
    _pollTimer?.cancel();
    // Poll every 5 seconds for up to 2 minutes
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      attempts++;
      if (attempts > 24) {
        timer.cancel();
        return;
      }
      context.read<TransactionBloc>().add(DepositStatusChecked(transactionId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.member['phone_number'] ?? '';
    final maskedPhone = phone.length >= 9
        ? '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}'
        : phone;

    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionStkPushSent) {
          _startPolling(state.transactionId);
        } else if (state is TransactionSuccess) {
          _pollTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.green,
          ));
          Navigator.of(context).pop(true);
        } else if (state is TransactionError) {
          _pollTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.redAccent,
          ));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Deposit to FOSA')),
        body: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            // STK push sent — show waiting screen
            if (state is TransactionStkPushSent) {
              return _StkPushWaitingView(
                amount: state.amount,
                maskedPhone: maskedPhone,
                onCancel: () {
                  _pollTimer?.cancel();
                  Navigator.of(context).pop(false);
                },
              );
            }

            final isLoading = state is TransactionLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00695C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF00695C).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: Color(0xFF00695C)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('FOSA Account',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00695C))),
                                Text('Deposit goes directly to your FOSA account',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // M-Pesa phone info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_android, color: Colors.green),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('M-Pesa STK Push',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                              Text('PIN prompt will be sent to $maskedPhone',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Amount (KES)',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: 'KES ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter amount';
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        if (n < 10) return 'Minimum deposit is KES 10';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.phone_android,
                                color: Colors.white),
                        label: Text(
                            isLoading ? 'Sending...' : 'Pay via M-Pesa',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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

class _StkPushWaitingView extends StatelessWidget {
  final double amount;
  final String maskedPhone;
  final VoidCallback onCancel;

  const _StkPushWaitingView({
    required this.amount,
    required this.maskedPhone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 32),
            const Icon(Icons.phone_android, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Check your phone',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'An M-Pesa prompt has been sent to $maskedPhone.\nEnter your M-Pesa PIN to complete the deposit of KES ${amount.toStringAsFixed(2)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
