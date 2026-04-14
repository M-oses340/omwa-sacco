part of 'withdraw_bloc.dart';

abstract class WithdrawEvent {}

class WithdrawInitiated extends WithdrawEvent {
  final String memberId;
  final double amount;
  final String phoneNumber;
  WithdrawInitiated({required this.memberId, required this.amount, required this.phoneNumber});
}
