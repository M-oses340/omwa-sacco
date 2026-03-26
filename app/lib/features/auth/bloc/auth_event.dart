part of 'auth_bloc.dart';

abstract class AuthEvent {}

class AuthNavigateToPhone extends AuthEvent {}

class AuthPhoneSubmitted extends AuthEvent {
  final String phone;
  AuthPhoneSubmitted(this.phone);
}

class AuthOtpSubmitted extends AuthEvent {
  final String otp;
  AuthOtpSubmitted(this.otp);
}

class AuthPinFirstEntry extends AuthEvent {
  final String pin;
  AuthPinFirstEntry(this.pin);
}

class AuthPinSubmitted extends AuthEvent {
  final String pin;
  AuthPinSubmitted(this.pin);
}

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
