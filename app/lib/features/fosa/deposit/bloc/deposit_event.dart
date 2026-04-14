part of 'deposit_bloc.dart';

abstract class DepositEvent {}

class DepositInitiated extends DepositEvent {
  final String memberId;
  final double amount;
  DepositInitiated({required this.memberId, required this.amount});
}

class CardDepositInitiated extends DepositEvent {
  final String memberId;
  final double amount;
  CardDepositInitiated({required this.memberId, required this.amount});
}

class CheckoutCompleted extends DepositEvent {
  final String transactionId;
  final bool success;
  CheckoutCompleted({required this.transactionId, required this.success});
}
