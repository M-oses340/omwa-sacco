import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_header.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_pad.dart';

class PinScreen extends StatefulWidget {
  final bool needsPinSetup;
  final String? memberName;
  const PinScreen({super.key, this.needsPinSetup = false, this.memberName});

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
    if (mounted) {
      setState(() => _biometricAvailable = canCheck && isSupported);
    }
    if (!widget.needsPinSetup && _biometricAvailable && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.read<AuthBloc>().add(AuthBiometricRequested());
      }
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  void _onKey(String key) {
    if (_isLoading || _pin.length >= _pinLength) return;
    setState(() => _pin.add(key));
    if (_pin.length == _pinLength) _submitPin();
  }

  void _onDelete() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  void _submitPin() {
    final pin = _pin.join();
    if (widget.needsPinSetup) {
      context.read<AuthBloc>().add(AuthPinFirstEntry(pin));
    } else {
      context.read<AuthBloc>().add(AuthPinSubmitted(pin));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else if (state is AuthError || state is AuthPinEntry) {
          setState(() {
            _isLoading = false;
            _pin.clear();
          });
        }
        // AuthAuthenticated / AuthPinConfirm etc. — let the router handle it,
        // don't touch local state to avoid a flash back to the PIN pad.
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: AuthHeader(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(_greeting(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w300)),
                        ),
                        if (widget.memberName != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.memberName!.split(' ').first,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Spacer(),
                        Center(
                          child: Text(
                            widget.needsPinSetup
                                ? 'Create a PIN'
                                : 'Enter Your PIN To Proceed',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 24),
                        PinDots(filled: _pin.length, total: _pinLength),
                        const SizedBox(height: 32),
                        PinPad(
                          isDark: isDark,
                          onKey: _onKey,
                          onDelete: _onDelete,
                          showBiometric:
                              _biometricAvailable && !widget.needsPinSetup,
                          onBiometric: () => context
                              .read<AuthBloc>()
                              .add(AuthBiometricRequested()),
                        ),
                        const SizedBox(height: 16),
                        if (!widget.needsPinSetup)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                // TODO: implement forgot PIN flow
                              },
                              child: const Text('Forgot PIN?'),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    // Loading overlay — sits on top, doesn't replace the PIN pad
                    if (_isLoading)
                      Container(
                        color: cs.surface.withValues(alpha: 0.85),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: cs.primary),
                              const SizedBox(height: 12),
                              Text('Verifying...',
                                  style: TextStyle(
                                      color: cs.onSurface
                                          .withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
