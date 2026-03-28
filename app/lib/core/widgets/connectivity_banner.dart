import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void initState() {
    super.initState();
    // Check initial state
    Connectivity().checkConnectivity().then(_updateStatus);
    // Listen for changes
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _isOffline) {
      setState(() => _isOffline = offline);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isOffline ? 36 : 0,
            color: cs.error,
            child: _isOffline
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: cs.onError, size: 16),
                      const SizedBox(width: 8),
                      Text('No internet connection',
                          style: TextStyle(
                              color: cs.onError,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
