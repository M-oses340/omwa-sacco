import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../bloc/transaction_bloc.dart';

Future<bool?> showDepositSheet(
    BuildContext context, Map<String, dynamic> member) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => TransactionBloc(),
      child: _DepositSheet(member: member),
    ),
  );
}

class _DepositSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  const _DepositSheet({required this.member});

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _useMpesa = true;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    if (_useMpesa) {
      context.read<TransactionBloc>().add(
            DepositInitiated(memberId: widget.member['id'], amount: amount),
          );
    } else {
      context.read<TransactionBloc>().add(
            CardDepositInitiated(memberId: widget.member['id'], amount: amount),
          );
    }
  }

  Future<void> _openCheckout(TransactionCheckoutReady state) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CheckoutWebView(url: state.checkoutUrl),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
      context.read<TransactionBloc>().add(
            CheckoutCompleted(transactionId: state.transactionId, success: true));
    } else {
      context.read<TransactionBloc>().add(
            CheckoutCompleted(transactionId: state.transactionId, success: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionCheckoutReady) {
          _openCheckout(state);
        } else if (state is TransactionSuccess) {
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.account_balance_wallet,
                          color: cs.onPrimaryContainer, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deposit to FOSA',
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Choose payment method',
                            style: tt.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Payment method toggle
                Row(
                  children: [
                    Expanded(
                      child: _MethodCard(
                        icon: Icons.phone_android, label: 'M-Pesa',
                        subtitle: 'STK Push', selected: _useMpesa,
                        color: Colors.green,
                        onTap: () => setState(() => _useMpesa = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MethodCard(
                        icon: Icons.credit_card, label: 'Card / Bank',
                        subtitle: 'Checkout', selected: !_useMpesa,
                        color: Colors.blue,
                        onTap: () => setState(() => _useMpesa = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Quick amounts',
                    style: tt.labelMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [500, 1000, 2000, 5000].map((amt) {
                    return ActionChip(
                      label: Text('KES $amt'),
                      onPressed: () => _amountController.text = amt.toString(),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: 'KES  ',
                      prefixStyle: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter amount';
                      final n = double.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      if (n < 10) return 'Minimum deposit is KES 10';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _submit,
                    icon: isLoading
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: cs.onPrimary, strokeWidth: 2))
                        : Icon(
                            _useMpesa ? Icons.phone_android : Icons.credit_card,
                            color: cs.onPrimary),
                    label: Text(
                      isLoading
                          ? 'Processing...'
                          : _useMpesa ? 'Send M-Pesa Prompt' : 'Continue to Checkout',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          color: cs.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _MethodCard({
    required this.icon, required this.label, required this.subtitle,
    required this.selected, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : cs.onSurface.withValues(alpha: 0.5), size: 22),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: selected ? color : cs.onSurface)),
                Text(subtitle, style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutWebView extends StatefulWidget {
  final String url;
  const _CheckoutWebView({required this.url});

  @override
  State<_CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<_CheckoutWebView> {
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
        title: const Text('Complete Deposit'),
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
