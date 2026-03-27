part of 'transaction_bloc.dart';

abstract class TransactionState {}

class TransactionInitial extends TransactionState {}
class TransactionLoading extends TransactionState {}

class TransactionCheckoutReady extends TransactionState {
  final String checkoutUrl;
  final String transactionId;
  final double amount;
  TransactionCheckoutReady({
    required this.checkoutUrl,
    required this.transactionId,
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
