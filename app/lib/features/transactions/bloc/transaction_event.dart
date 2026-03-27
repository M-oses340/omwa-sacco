part of 'transaction_bloc.dart';

abstract class TransactionEvent {}

class DepositInitiated extends TransactionEvent {
  final String memberId;
  final double amount;
  final String method; // 'mpesa' or 'bank'

  DepositInitiated({
    required this.memberId,
    required this.amount,
    required this.method,
  });
}

class DepositStatusChecked extends TransactionEvent {
  final String transactionId;
  DepositStatusChecked(this.transactionId);
}

class BankCheckoutCompleted extends TransactionEvent {
  final String transactionId;
  final bool success;
  BankCheckoutCompleted({required this.transactionId, required this.success});
}
