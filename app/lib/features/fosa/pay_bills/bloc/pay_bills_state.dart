part of 'pay_bills_bloc.dart';

abstract class PayBillsState {}

class PayBillsInitial extends PayBillsState {}
class PayBillsLoading extends PayBillsState {}

class PayBillsSuccess extends PayBillsState {
  final String message;
  PayBillsSuccess(this.message);
}

class PayBillsError extends PayBillsState {
  final String message;
  PayBillsError(this.message);
}
