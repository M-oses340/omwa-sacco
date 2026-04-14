part of 'deposit_bloc.dart';

abstract class DepositState {}

class DepositInitial extends DepositState {}
class DepositLoading extends DepositState {}

class DepositCheckoutReady extends DepositState {
  final String checkoutUrl;
  final String transactionId;
  final double amount;
  DepositCheckoutReady({required this.checkoutUrl, required this.transactionId, required this.amount});
}

class DepositSuccess extends DepositState {
  final String message;
  DepositSuccess(this.message);
}

class DepositError extends DepositState {
  final String message;
  DepositError(this.message);
}
