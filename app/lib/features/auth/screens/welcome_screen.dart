import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../bloc/auth_bloc.dart';
import '../../../core/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthPhoneEntry) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showEmailSheet(context);
          });
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance,
                        color: cs.primary, size: 36),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Omwa Sacco',
                          style: TextStyle(
                              color: cs.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text('United for Prosperity',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'WELCOME TO OUR MOBILE BANKING',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickLink(
                        icon: Icons.info_outline,
                        label: 'About Us',
                        onTap: () {}),
                    _QuickLink(
                        icon: Icons.contact_phone_outlined,
                        label: 'Contact Us',
                        onTap: () {}),
                    _QuickLink(
                        icon: Icons.location_on_outlined,
                        label: 'Come Visit',
                        onTap: () {}),
                    _QuickLink(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Products',
                        onTap: () {}),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 24, bottom: 40),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.read<AuthBloc>().add(AuthNavigateToPhone()),
                    icon: const Icon(Icons.lock_open, color: Colors.white),
                    label: const Text('LOG IN',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailSheet(BuildContext ctx) {
    final bloc = ctx.read<AuthBloc>();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _EmailSheet(),
      ),
    );
  }
}

// ─── Email sheet ──────────────────────────────────────────────────────────────

class _EmailSheet extends StatefulWidget {
  const _EmailSheet();

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchEmailHints();
  }

  Future<void> _fetchEmailHints() async {
    try {
      final smartAuth = SmartAuth();
      final credential = await smartAuth.requestHint(
        isEmailAddressIdentifierSupported: true,
        isPhoneNumberIdentifierSupported: false,
      );
      if (credential?.id != null && mounted) {
        _controller.text = credential!.id;
        // Auto-submit — user explicitly picked their email
        _submit();
      }
    } catch (_) {
      // Not supported on iOS or older Android — user types manually
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      context
          .read<AuthBloc>()
          .add(AuthEmailSubmitted(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is! AuthLoading) setState(() => _loading = false);
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        }
        if (state is AuthOtpEntry) {
          // Replace this sheet with the OTP sheet
          final bloc = context.read<AuthBloc>();
          final email = state.email;
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              isDismissible: false,
              backgroundColor: Colors.transparent,
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: _OtpSheet(email: email),
              ),
            );
          });
        }
      },
      child: _SheetShell(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your email',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("We'll send you a one-time code",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                enabled: !_loading,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter your email address';
                  }
                  if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                      .hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('SEND OTP',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── OTP sheet ────────────────────────────────────────────────────────────────

class _OtpSheet extends StatefulWidget {
  final String email;
  const _OtpSheet({required this.email});

  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  bool _loading = false;
  bool _resent = false;

  void _resend() {
    context.read<AuthBloc>().add(AuthEmailSubmitted(widget.email));
    setState(() => _resent = true);
    Future.delayed(
        const Duration(seconds: 30), () => setState(() => _resent = false));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() => _loading = true);
        } else if (state is AuthError) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        } else if (state is! AuthOtpEntry) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      child: _SheetShell(
        child: _loading
            ? SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 16),
                      Text('Verifying...',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verify your email',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Enter the 6-digit code sent to ${widget.email}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 28),
                  Center(
                    child: Pinput(
                      length: 6,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      defaultPinTheme: PinTheme(
                        width: 52,
                        height: 56,
                        textStyle: TextStyle(
                            color: cs.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.5),
                              width: 1.5),
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
                      onCompleted: (otp) => context.read<AuthBloc>().add(
                            AuthOtpSubmitted(otp: otp, email: widget.email),
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          final bloc = context.read<AuthBloc>();
                          Navigator.of(context).pop();
                          bloc.add(AuthNavigateToPhone());
                        },
                        child: const Text('Wrong email?'),
                      ),
                      TextButton(
                        onPressed: _resent ? null : _resend,
                        child: Text(_resent ? 'Code resent' : 'Resend code'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Shared sheet shell ───────────────────────────────────────────────────────

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Quick link widget ────────────────────────────────────────────────────────

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLink(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }
}
