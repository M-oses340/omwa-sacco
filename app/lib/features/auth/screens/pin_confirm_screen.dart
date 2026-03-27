import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_header.dart';

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

  void _onKeyTap(String key) {
    if (_isLoading) return;
    if (_pin.length < _pinLength) {
      setState(() => _pin.add(key));
      if (_pin.length == _pinLength) _confirm();
    }
  }

  void _onDelete() {
    if (_isLoading) return;
    if (_pin.isNotEmpty) setState(() => _pin.removeLast());
  }

  void _confirm() {
    final pin = _pin.join();
    if (pin != widget.firstPin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PINs do not match. Try again.'),
        backgroundColor: Colors.redAccent,
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
        } else {
          setState(() => _isLoading = false);
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent));
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: AuthHeader(),
              ),
              const Spacer(),
              Center(
                child: Text('Confirm Your PIN',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.5), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                      color: filled
                          ? cs.primary.withValues(alpha: 0.2)
                          : Colors.transparent,
                    ),
                    child: filled
                        ? Center(
                            child: Icon(Icons.circle, color: cs.primary, size: 14))
                        : null,
                  );
                }),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 12),
                      Text('Setting up your PIN...',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildRow(context, ['1', '2', '3'], isDark),
                      const SizedBox(height: 12),
                      _buildRow(context, ['4', '5', '6'], isDark),
                      const SizedBox(height: 12),
                      _buildRow(context, ['7', '8', '9'], isDark),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 80),
                          _NumKey(
                            isDark: isDark,
                            onTap: () => _onKeyTap('0'),
                            child: Text('0',
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500)),
                          ),
                          _NumKey(
                            isDark: isDark,
                            onTap: _onDelete,
                            child: Icon(Icons.backspace_outlined,
                                color: cs.onSurface.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> keys, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys
          .map((k) => _NumKey(
                isDark: isDark,
                onTap: () => _onKeyTap(k),
                child: Text(k,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w500)),
              ))
          .toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _NumKey({required this.child, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
