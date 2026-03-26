import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_header.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  bool _resent = false;

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
              const SizedBox(height: 48),
              Text('Verify your email',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Enter the 6-digit code sent to ${widget.phone}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 40),
              Center(
                child: Pinput(
                  length: 6,
                  keyboardType: TextInputType.number,
                  defaultPinTheme: PinTheme(
                    width: 52,
                    height: 56,
                    textStyle: TextStyle(
                        color: cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.5), width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 52,
                    height: 56,
                    textStyle: TextStyle(
                        color: cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary, width: 2),
                      borderRadius: BorderRadius.circular(10),
                      color: cs.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  onCompleted: (otp) =>
                      context.read<AuthBloc>().add(AuthOtpSubmitted(otp)),
                ),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: _resent
                      ? null
                      : () {
                          context
                              .read<AuthBloc>()
                              .add(AuthPhoneSubmitted(widget.phone));
                          setState(() => _resent = true);
                          Future.delayed(const Duration(seconds: 30),
                              () => setState(() => _resent = false));
                        },
                  child: Text(_resent ? 'Code resent' : 'Resend code'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Wrong email? Go back'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
