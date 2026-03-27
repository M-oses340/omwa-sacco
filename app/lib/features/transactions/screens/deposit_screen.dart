import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  String _method = 'mpesa';
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
          method: _method,
        ));
  }

  void _startPolling(String transactionId) {
    _pollTimer?.cancel();
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

  String get _maskedPhone {
    final phone = widget.member['phone_number'] ?? '';
    return phone.length >= 9
        ? '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}'
        : phone;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionStkPushSent) {
          _startPolling(state.transactionId);
        } else if (state is TransactionBankCheckoutReady) {
          _openBankCheckout(state);
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
            if (state is TransactionStkPushSent) {
              return _StkWaitingView(
                amount: state.amount,
                maskedPhone: _maskedPhone,
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
                    // FOSA info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00695C).withValues(alpha: 0.08),
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
                    // Payment method selector
                    Text('Payment Method',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MethodCard(
                            icon: Icons.phone_android,
                            label: 'M-Pesa',
                            subtitle: 'STK Push to $_maskedPhone',
                            color: Colors.green,
                            selected: _method == 'mpesa',
                            onTap: () => setState(() => _method = 'mpesa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MethodCard(
                            icon: Icons.credit_card,
                            label: 'Bank / Card',
                            subtitle: 'Pay via card or bank transfer',
                            color: Colors.blue,
                            selected: _method == 'bank',
                            onTap: () => setState(() => _method = 'bank'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Amount
                    Text('Amount (KES)',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                            : Icon(
                                _method == 'mpesa'
                                    ? Icons.phone_android
                                    : Icons.credit_card,
                                color: Colors.white),
                        label: Text(
                          isLoading
                              ? 'Processing...'
                              : _method == 'mpesa'
                                  ? 'Pay via M-Pesa'
                                  : 'Pay via Bank / Card',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _method == 'mpesa'
                              ? Colors.green
                              : Colors.blue,
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

  Future<void> _openBankCheckout(TransactionBankCheckoutReady state) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _BankCheckoutWebView(
          url: state.checkoutUrl,
          transactionId: state.transactionId,
        ),
      ),
    );
    if (mounted) {
      context.read<TransactionBloc>().add(BankCheckoutCompleted(
            transactionId: state.transactionId,
            success: result == true,
          ));
    }
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? color : Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _StkWaitingView extends StatelessWidget {
  final double amount;
  final String maskedPhone;
  final VoidCallback onCancel;

  const _StkWaitingView({
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
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'An M-Pesa prompt has been sent to $maskedPhone.\nEnter your M-Pesa PIN to complete the deposit of KES ${amount.toStringAsFixed(2)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: onCancel,
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCheckoutWebView extends StatefulWidget {
  final String url;
  final String transactionId;

  const _BankCheckoutWebView(
      {required this.url, required this.transactionId});

  @override
  State<_BankCheckoutWebView> createState() => _BankCheckoutWebViewState();
}

class _BankCheckoutWebViewState extends State<_BankCheckoutWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          if (request.url.contains('omwasacco.app/payment') ||
              request.url.contains('payment/callback')) {
            final success = !request.url.contains('failed') &&
                !request.url.contains('cancelled');
            Navigator.of(context).pop(success);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank / Card Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
