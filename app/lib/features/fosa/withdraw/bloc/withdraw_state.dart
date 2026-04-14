part of 'withdraw_bloc.dart';

abstract class WithdrawState {}

class WithdrawInitial extends WithdrawState {}
class WithdrawLoading extends WithdrawState {}

class WithdrawSuccess extends WithdrawState {
  final String message;
  WithdrawSuccess(this.message);
}

class WithdrawError extends WithdrawState {
  final String message;
  WithdrawError(this.message);
}
