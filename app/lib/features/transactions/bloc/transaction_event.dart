part of 'transaction_bloc.dart';

abstract class TransactionEvent {}

class DepositInitiated extends TransactionEvent {
  final String memberId;
  final double amount;
  DepositInitiated({required this.memberId, required this.amount});
}

class CheckoutCompleted extends TransactionEvent {
  final String transactionId;
  final bool success;
  CheckoutCompleted({required this.transactionId, required this.success});
}

class WithdrawInitiated extends TransactionEvent {
  final String memberId;
  final double amount;
  final String phoneNumber;
  WithdrawInitiated({
    required this.memberId,
    required this.amount,
    required this.phoneNumber,
  });
}

class InternalTransferInitiated extends TransactionEvent {
  final String fromMemberId;
  final String toMemberNumber;
  final double amount;
  final String note;
  InternalTransferInitiated({
    required this.fromMemberId,
    required this.toMemberNumber,
    required this.amount,
    required this.note,
  });
}

class ExternalTransferInitiated extends TransactionEvent {
  final String fromMemberId;
  final String bankCode;
  final String accountNumber;
  final String accountName;
  final double amount;
  ExternalTransferInitiated({
    required this.fromMemberId,
    required this.bankCode,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
  });
}
