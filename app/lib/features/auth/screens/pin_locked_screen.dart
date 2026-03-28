import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_header.dart';

class PinLockedScreen extends StatefulWidget {
  final DateTime unlocksAt;
  const PinLockedScreen({super.key, required this.unlocksAt});

  @override
  State<PinLockedScreen> createState() => _PinLockedScreenState();
}

class _PinLockedScreenState extends State<PinLockedScreen> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final remaining = widget.unlocksAt.difference(DateTime.now());
    if (remaining.isNegative) {
      _timer.cancel();
      if (mounted) context.read<AuthBloc>().add(AuthCheckSession());
    } else {
      setState(() => _remaining = remaining);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const AuthHeader(),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.lock_outline, size: 64, color: cs.error),
                    const SizedBox(height: 16),
                    Text('Account Locked',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: cs.error)),
                    const SizedBox(height: 12),
                    Text(
                      'Too many incorrect PIN attempts.\nTry again in',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _format(_remaining),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                              fontWeight: FontWeight.bold, color: cs.error),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
