part of 'transaction_bloc.dart';

abstract class TransactionEvent {}

class DepositInitiated extends TransactionEvent {
  final String memberId;
  final double amount;

  DepositInitiated({
    required this.memberId,
    required this.amount,
  });
}

class DepositStatusChecked extends TransactionEvent {
  final String transactionId;
  DepositStatusChecked(this.transactionId);
}
