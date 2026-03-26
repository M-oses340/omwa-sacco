part of 'transaction_bloc.dart';

abstract class TransactionEvent {}

class DepositInitiated extends TransactionEvent {
  final String memberId;
  final String accountType; // 'bosa' or 'fosa'
  final double amount;
  final String paymentMethod; // 'mpesa' or 'bank'
  final String? description;

  DepositInitiated({
    required this.memberId,
    required this.accountType,
    required this.amount,
    required this.paymentMethod,
    this.description,
  });
}

class DepositCompleted extends TransactionEvent {
  final String reference;
  final String memberId;
  final String accountType;
  final double amount;
  final bool success;
  final String? intasendRef;

  DepositCompleted({
    required this.reference,
    required this.memberId,
    required this.accountType,
    required this.amount,
    required this.success,
    this.intasendRef,
  });
}
