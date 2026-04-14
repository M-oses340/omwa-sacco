part of 'transfer_bloc.dart';

abstract class TransferState {}

class TransferInitial extends TransferState {}
class TransferLoading extends TransferState {}

class TransferSuccess extends TransferState {
  final String message;
  TransferSuccess(this.message);
}

class TransferError extends TransferState {
  final String message;
  TransferError(this.message);
}
