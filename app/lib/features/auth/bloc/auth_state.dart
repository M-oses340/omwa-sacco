part of 'auth_bloc.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthPhoneEntry extends AuthState {}

class AuthOtpEntry extends AuthState {
  final String email;
  AuthOtpEntry(this.email);
}

class AuthPinEntry extends AuthState {
  /// True when the user has no PIN stored locally (new device or first login).
  /// Does NOT mean they are a new member — use [isNewMember] for that.
  final bool needsPinSetup;
  final String? memberName;
  final int failedAttempts;
  AuthPinEntry({
    this.needsPinSetup = false,
    this.memberName,
    this.failedAttempts = 0,
  });
}

class AuthPinLocked extends AuthState {
  final DateTime unlocksAt;
  AuthPinLocked(this.unlocksAt);
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
