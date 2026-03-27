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
  @override
  void initState() {
    super.initState();
    // Auto-initiate checkout when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionBloc>().add(
            DepositInitiated(memberId: widget.member['id']),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionCheckoutReady) {
          _openCheckout(state);
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
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Deposit')),
        body: BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening payment...'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCheckout(TransactionCheckoutReady state) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CheckoutWebView(
          url: state.checkoutUrl,
          transactionId: state.transactionId,
        ),
      ),
    );
    if (mounted) {
      context.read<TransactionBloc>().add(CheckoutCompleted(
            transactionId: state.transactionId,
            success: result == true,
          ));
    }
  }
}

class _CheckoutWebView extends StatefulWidget {
  final String url;
  final String transactionId;
  const _CheckoutWebView({required this.url, required this.transactionId});

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
        title: const Text('Complete Payment'),
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
