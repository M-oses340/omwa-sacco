part of 'transaction_bloc.dart';

abstract class TransactionState {}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionPendingCheckout extends TransactionState {
  final String reference;
  final double amount;
  final String accountType;
  final String memberId;

  TransactionPendingCheckout({
    required this.reference,
    required this.amount,
    required this.accountType,
    required this.memberId,
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
