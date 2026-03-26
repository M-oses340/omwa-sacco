import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/phone_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/pin_screen.dart';
import '../../features/auth/screens/pin_confirm_screen.dart';
import '../../features/auth/screens/registration_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(),
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
          if (state is AuthLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is AuthPhoneEntry) {
            return const PhoneScreen();
          }
          if (state is AuthOtpEntry) {
            return OtpScreen(phone: state.phone);
          }
          if (state is AuthPinEntry) {
            return PinScreen(isNewUser: state.isNewUser);
          }
          if (state is AuthPinConfirm) {
            return PinConfirmScreen(firstPin: state.firstPin);
          }
          if (state is AuthRegistration) {
            return const RegistrationScreen();
          }
          if (state is AuthAuthenticated) {
            return DashboardScreen(member: state.member);
          }
          // Default: welcome screen
          return const WelcomeScreen();
        },
      ),
    );
  }
}
