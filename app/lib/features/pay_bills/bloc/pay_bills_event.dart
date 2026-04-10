part of 'pay_bills_bloc.dart';

abstract class PayBillsEvent {}

class PayBillSubmitted extends PayBillsEvent {
  final String memberId;
  final String businessNumber;
  final String accountNumber;
  final double amount;
  PayBillSubmitted({
    required this.memberId,
    required this.businessNumber,
    required this.accountNumber,
    required this.amount,
  });
}

class TillPaymentSubmitted extends PayBillsEvent {
  final String memberId;
  final String tillNumber;
  final double amount;
  TillPaymentSubmitted({
    required this.memberId,
    required this.tillNumber,
    required this.amount,
  });
}
