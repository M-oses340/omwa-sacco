part of 'transaction_bloc.dart';

abstract class TransactionState {}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

// STK push sent — waiting for member to enter M-Pesa PIN
class TransactionStkPushSent extends TransactionState {
  final String transactionId;
  final String invoiceId;
  final double amount;

  TransactionStkPushSent({
    required this.transactionId,
    required this.invoiceId,
    required this.amount,
  });
}

class TransactionSuccess extends TransactionState {
  final String message;
  TransactionSuccess(this.message);
}

class TransactionError extends TransactionState {
  final String message;
  TransactionError(this.message);
}
