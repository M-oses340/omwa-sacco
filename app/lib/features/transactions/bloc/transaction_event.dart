part of 'transaction_bloc.dart';

abstract class TransactionEvent {}

class DepositInitiated extends TransactionEvent {
  final String memberId;
  DepositInitiated({required this.memberId});
}

class CheckoutCompleted extends TransactionEvent {
  final String transactionId;
  final bool success;
  CheckoutCompleted({required this.transactionId, required this.success});
}
