import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_header.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_pad.dart';

class PinConfirmScreen extends StatefulWidget {
  final String firstPin;
  const PinConfirmScreen({super.key, required this.firstPin});

  @override
  State<PinConfirmScreen> createState() => _PinConfirmScreenState();
}

class _PinConfirmScreenState extends State<PinConfirmScreen> {
  final List<String> _pin = [];
  static const int _pinLength = 4;
  bool _isLoading = false;

  void _onKey(String key) {
    if (_isLoading || _pin.length >= _pinLength) return;
    setState(() => _pin.add(key));
    if (_pin.length == _pinLength) _confirm();
  }

  void _onDelete() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  void _confirm() {
    final pin = _pin.join();
    if (pin != widget.firstPin) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('PINs do not match. Try again.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      setState(() => _pin.clear());
      return;
    }
    context.read<AuthBloc>().add(AuthPinSetup(pin));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else if (state is AuthError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error));
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: AuthHeader(),
                        ),
                        const Spacer(),
                        Center(
                          child: Text('Confirm your device PIN',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const SizedBox(height: 24),
                        PinDots(filled: _pin.length, total: _pinLength),
                        const SizedBox(height: 32),
                        PinPad(
                          isDark: isDark,
                          onKey: _onKey,
                          onDelete: _onDelete,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: cs.surface.withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: cs.primary),
                        const SizedBox(height: 12),
                        Text('Setting up your PIN...',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
