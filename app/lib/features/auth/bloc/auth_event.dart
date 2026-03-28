part of 'auth_bloc.dart';

abstract class AuthEvent {}

class AuthCheckSession extends AuthEvent {}

class AuthNavigateToPhone extends AuthEvent {}

class AuthEmailSubmitted extends AuthEvent {
  final String email;
  AuthEmailSubmitted(this.email);
}

class AuthOtpSubmitted extends AuthEvent {
  final String otp;
  final String email;
  AuthOtpSubmitted({required this.otp, required this.email});
}

class AuthPinFirstEntry extends AuthEvent {
  final String pin;
  AuthPinFirstEntry(this.pin);
}

class AuthPinSubmitted extends AuthEvent {
  final String pin;
  AuthPinSubmitted(this.pin);
}

class AuthBiometricRequested extends AuthEvent {}

class AuthPinSetup extends AuthEvent {
  final String pin;
  AuthPinSetup(this.pin);
}

class AuthRegisterSubmitted extends AuthEvent {
  final String fullName;
  final String nationalId;
  final String phoneNumber;
  AuthRegisterSubmitted({
    required this.fullName,
    required this.nationalId,
    required this.phoneNumber,
  });
}

class AuthLogoutRequested extends AuthEvent {}
