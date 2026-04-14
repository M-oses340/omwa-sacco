part of 'transfer_bloc.dart';

abstract class TransferEvent {}

class InternalTransferInitiated extends TransferEvent {
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

class ExternalTransferInitiated extends TransferEvent {
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
