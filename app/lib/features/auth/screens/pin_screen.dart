import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../bloc/auth_bloc.dart';

class PinScreen extends StatefulWidget {
  final bool isNewUser;
  const PinScreen({super.key, this.isNewUser = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final List<String> _pin = [];
  static const int _pinLength = 4;
  bool _isLoading = false;
  bool _biometricAvailable = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    final available = await _localAuth.getAvailableBiometrics();
    debugPrint('[BIOMETRIC] canCheckBiometrics: $canCheck');
    debugPrint('[BIOMETRIC] isDeviceSupported: $isSupported');
    debugPrint('[BIOMETRIC] availableBiometrics: $available');
    if (mounted) setState(() => _biometricAvailable = canCheck && isSupported);
    if (!widget.isNewUser && _biometricAvailable) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    debugPrint('[BIOMETRIC] Attempting authentication...');
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Use fingerprint to unlock Omwa Sacco',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      debugPrint('[BIOMETRIC] Result: $success');
      if (success && mounted) {
        context.read<AuthBloc>().add(AuthPinSubmitted('__biometric__'));
      }
    } catch (e) {
      debugPrint('[BIOMETRIC] Error: $e');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Night!';
  }

  void _onKeyTap(String key) {
    if (_isLoading) return;
    if (_pin.length < _pinLength) {
      setState(() => _pin.add(key));
      if (_pin.length == _pinLength) _submitPin();
    }
  }

  void _onDelete() {
    if (_isLoading) return;
    if (_pin.isNotEmpty) setState(() => _pin.removeLast());
  }

  void _submitPin() {
    final pin = _pin.join();
    if (widget.isNewUser) {
      // Go to confirm step via bloc
      context.read<AuthBloc>().add(AuthPinFirstEntry(pin));
    } else {
      context.read<AuthBloc>().add(AuthPinSubmitted(pin));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else {
          setState(() {
            _isLoading = false;
            if (state is AuthError) _pin.clear();
          });
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF90CAF9), Color(0xFF1565C0)],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Omwa Sacco',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text('United for Prosperity',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(_greeting(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w300)),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    widget.isNewUser ? 'Set Your PIN' : 'Enter Your PIN To Proceed',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                // PIN boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (i) {
                    final filled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                        color: filled
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                      child: filled
                          ? const Center(
                              child: Icon(Icons.circle,
                                  color: Colors.white, size: 14))
                          : null,
                    );
                  }),
                ),
                const SizedBox(height: 32),
                // Loading indicator or numpad
                if (_isLoading)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text('Verifying...',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildRow(['1', '2', '3']),
                        const SizedBox(height: 12),
                        _buildRow(['4', '5', '6']),
                        const SizedBox(height: 12),
                        _buildRow(['7', '8', '9']),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _NumKey(
                              onTap: _biometricAvailable ? _tryBiometric : () {},
                              child: Icon(
                                Icons.fingerprint,
                                color: _biometricAvailable ? Colors.white : Colors.white24,
                                size: 32,
                              ),
                            ),
                            _NumKey(
                              onTap: () => _onKeyTap('0'),
                              child: const Text('0',
                                  style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500)),
                            ),
                            _NumKey(
                              onTap: _onDelete,
                              child: const Icon(Icons.backspace_outlined,
                                  color: Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (!_isLoading)
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot PIN?',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys
          .map((k) => _NumKey(
                child: Text(k,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w500)),
                onTap: () => _onKeyTap(k),
              ))
          .toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NumKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
