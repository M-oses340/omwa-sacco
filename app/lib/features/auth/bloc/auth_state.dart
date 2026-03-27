part of 'auth_bloc.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthPhoneEntry extends AuthState {}

class AuthOtpEntry extends AuthState {
  final String phone;
  AuthOtpEntry(this.phone);
}

class AuthPinEntry extends AuthState {
  final bool isNewUser;
  final String? memberName;
  AuthPinEntry({this.isNewUser = false, this.memberName});
}

class AuthPinConfirm extends AuthState {
  final String firstPin;
  AuthPinConfirm(this.firstPin);
}

class AuthRegistration extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> member;
  AuthAuthenticated(this.member);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
