import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/pin_screen.dart';
import '../../features/auth/screens/pin_confirm_screen.dart';
import '../../features/auth/screens/pin_locked_screen.dart';
import '../../features/auth/screens/registration_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  static const _timeout = Duration(minutes: 5);
  AuthBloc? _authBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _startInactivityTimer();
    } else if (state == AppLifecycleState.resumed) {
      _inactivityTimer?.cancel();
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_timeout, () {
      _authBloc?.add(AuthLogoutRequested());
    });
  }

  void _resetTimer() {
    if (_inactivityTimer?.isActive == true) {
      _startInactivityTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        _authBloc = AuthBloc()..add(AuthCheckSession());
        return _authBloc!;
      },
      child: Listener(
        onPointerDown: (_) => _resetTimer(),
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is AuthLoading) return const SplashScreen();
            // PhoneEntry and OtpEntry are handled as bottom sheets
            // inside WelcomeScreen — keep it as the base for those states.
            if (state is AuthPhoneEntry || state is AuthOtpEntry) {
              return const WelcomeScreen();
            }
            if (state is AuthPinEntry) {
              return PinScreen(
                  needsPinSetup: state.needsPinSetup,
                  memberName: state.memberName);
            }
            if (state is AuthPinLocked) {
              return PinLockedScreen(unlocksAt: state.unlocksAt);
            }
            if (state is AuthPinConfirm) {
              return PinConfirmScreen(firstPin: state.firstPin);
            }
            if (state is AuthRegistration) return const RegistrationScreen();
            if (state is AuthAuthenticated) {
              return DashboardScreen(member: state.member);
            }
            return const WelcomeScreen();
          },
        ),
      ),
    );
  }
}
