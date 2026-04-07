import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
  const _DepositSheet({super.key, required this.member});

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _useMpesa = true;
  String? _successMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    debugPrint('[DEPOSIT] submit: amount=$amount, mpesa=$_useMpesa');
    if (_useMpesa) {
      debugPrint('[DEPOSIT] firing DepositInitiated');
      context.read<TransactionBloc>().add(
            DepositInitiated(memberId: widget.member['id'], amount: amount),
          );
    } else {
      debugPrint('[DEPOSIT] firing CardDepositInitiated');
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
    if (result == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionCheckoutReady) {
          _openCheckout(state);
        } else if (state is TransactionSuccess) {
          // For M-Pesa: show the message in-sheet, don't auto-close
          if (_useMpesa) {
            setState(() => _successMessage = state.message);
          } else {
            Navigator.of(context).pop(true);
          }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── STK Push sent — waiting for PIN ──────────────────────────
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_android, color: Colors.green, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Check Your Phone', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_successMessage!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Text('Enter your M-Pesa PIN to complete the deposit.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_downward, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deposit to FOSA',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Choose payment method',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment method selector
            Row(
              children: [
                Expanded(
                  child: _MethodCard(
                    label: 'M-Pesa',
                    icon: Icons.phone_android,
                    color: Colors.green,
                    selected: _useMpesa,
                    onTap: () => setState(() => _useMpesa = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MethodCard(
                    label: 'Card',
                    icon: Icons.credit_card,
                    color: Colors.blue,
                    selected: !_useMpesa,
                    onTap: () => setState(() => _useMpesa = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick amounts
            Wrap(
              spacing: 8,
              children: [500, 1000, 2000, 5000].map((amt) {
                return ActionChip(
                  label: Text('KES $amt'),
                  onPressed: () => _amountController.text = amt.toString(),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: 'KES  ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 10) return 'Minimum KES 10';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),

            BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                final isLoading = state is TransactionLoading;
                return SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _submit,
                    icon: isLoading
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2))
                        : Icon(_useMpesa ? Icons.phone_android : Icons.credit_card),
                    label: Text(
                      isLoading
                          ? 'Processing...'
                          : _useMpesa
                              ? 'Pay via M-Pesa'
                              : 'Pay via Card',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _useMpesa ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              },
            ),

            if (!_useMpesa) ...[
              const SizedBox(height: 8),
              Text(
                'You will be redirected to a secure payment page',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ],
            ], // end else
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Card Checkout WebView ─────────────────────────────────────────────────────

class _CheckoutWebView extends StatefulWidget {
  final String url;
  const _CheckoutWebView({required this.url});

  @override
  State<_CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<_CheckoutWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _completed = false;

  bool _isSuccessUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('intasend.com/success') ||
        u.contains('payment/callback') ||
        u.contains('status=success') ||
        u.contains('status=completed');
  }

  void _handleSuccess() {
    if (_completed || !mounted) return;
    _completed = true;
    Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    WebViewCookieManager().clearCookies();

    final controller = WebViewController();

    if (controller.platform is AndroidWebViewController) {
      final p = controller.platform as AndroidWebViewController;
      p.setMediaPlaybackRequiresUserGesture(false);
      p.setOnPlatformPermissionRequest((r) => r.grant());
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _loading = true);
          if (_isSuccessUrl(url)) _handleSuccess();
        },
        onPageFinished: (url) {
          setState(() => _loading = false);
          if (_isSuccessUrl(url)) _handleSuccess();
        },
        onWebResourceError: (error) {
          if (error.errorCode == -101) _handleSuccess();
        },
      ))
      ..loadRequest(Uri.parse(widget.url));

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
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
