import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../bloc/transaction_bloc.dart';
import '../../../core/constants/payment_constants.dart';

class DepositScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const DepositScreen({super.key, required this.member});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _accountType = 'bosa';
  String _paymentMethod = 'mpesa';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    debugPrint('[DEPOSIT] Proceed to payment pressed');
    debugPrint('[DEPOSIT] Account type: $_accountType');
    debugPrint('[DEPOSIT] Payment method: $_paymentMethod');
    debugPrint('[DEPOSIT] Amount: $amount');
    debugPrint('[DEPOSIT] Member ID: ${widget.member['id']}');
    debugPrint('[DEPOSIT] Member email: ${widget.member['email']}');
    context.read<TransactionBloc>().add(DepositInitiated(
          memberId: widget.member['id'],
          accountType: _accountType,
          amount: amount,
          paymentMethod: _paymentMethod,
        ));
  }

  Future<void> _launchCheckout(TransactionPendingCheckout state) async {
    final name = (widget.member['full_name'] ?? '').split(' ');
    final firstName = Uri.encodeComponent(name.isNotEmpty ? name.first : 'Member');
    final lastName = Uri.encodeComponent(name.length > 1 ? name.last : '');
    final email = Uri.encodeComponent(widget.member['email'] ?? '');
    final phone = Uri.encodeComponent(widget.member['phone_number'] ?? '');

    // Build IntaSend hosted checkout URL directly (no API call needed)
    final checkoutUrl = 'https://sandbox.intasend.com/pay/host/'
        '?public_key=${PaymentConstants.intasendPublicKey}'
        '&amount=${state.amount}'
        '&currency=${PaymentConstants.currency}'
        '&email=$email'
        '&first_name=$firstName'
        '&last_name=$lastName'
        '&phone_number=$phone'
        '&api_ref=${state.reference}'
        '&redirect_url=https://omwasacco.app/payment/callback';

    debugPrint('[DEPOSIT] Opening checkout URL: $checkoutUrl');

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _IntaSendWebView(
          url: checkoutUrl,
          reference: state.reference,
        ),
      ),
    );

    if (mounted) {
      context.read<TransactionBloc>().add(DepositCompleted(
            reference: state.reference,
            memberId: state.memberId,
            accountType: state.accountType,
            amount: state.amount,
            success: result == true,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionPendingCheckout) {
          _launchCheckout(state);
        } else if (state is TransactionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.green,
          ));
          Navigator.of(context).pop(true);
        } else if (state is TransactionError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.redAccent,
          ));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Deposit')),
        body: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            final isLoading = state is TransactionLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deposit to Account',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    Text('Select Account',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _AccountOption(
                            label: 'BOSA',
                            subtitle: 'Savings & Shares',
                            icon: Icons.savings,
                            selected: _accountType == 'bosa',
                            onTap: () => setState(() => _accountType = 'bosa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AccountOption(
                            label: 'FOSA',
                            subtitle: 'Current Account',
                            icon: Icons.account_balance_wallet,
                            selected: _accountType == 'fosa',
                            onTap: () => setState(() => _accountType = 'fosa'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Payment Method',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PaymentOption(
                            label: 'M-Pesa',
                            icon: Icons.phone_android,
                            selected: _paymentMethod == 'mpesa',
                            onTap: () =>
                                setState(() => _paymentMethod = 'mpesa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PaymentOption(
                            label: 'Bank',
                            icon: Icons.account_balance,
                            selected: _paymentMethod == 'bank',
                            onTap: () =>
                                setState(() => _paymentMethod = 'bank'),
                          ),
                        ),
                      ],
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
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Proceed to Payment',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
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

class _IntaSendWebView extends StatefulWidget {
  final String url;
  final String reference;
  const _IntaSendWebView({required this.url, required this.reference});

  @override
  State<_IntaSendWebView> createState() => _IntaSendWebViewState();
}

class _IntaSendWebViewState extends State<_IntaSendWebView> {
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
          // Detect success redirect
          if (request.url.contains('/payment/callback') ||
              request.url.contains('omwasacco.app')) {
            final success = request.url.contains('success') ||
                !request.url.contains('failed');
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
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _AccountOption({required this.label, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? cs.primary : cs.onSurface, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? cs.primary : cs.onSurface)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? cs.primary : cs.onSurface, size: 22),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? cs.primary : cs.onSurface)),
          ],
        ),
      ),
    );
  }
}
