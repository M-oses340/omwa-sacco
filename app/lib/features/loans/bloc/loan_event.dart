part of 'loan_bloc.dart';

abstract class LoanEvent {}

class LoanHistoryRequested extends LoanEvent {
  final String memberId;
  LoanHistoryRequested(this.memberId);
}

class LoanApplicationSubmitted extends LoanEvent {
  final String loanType;
  final double principal;
  final int durationMonths;
  final String purpose;

  LoanApplicationSubmitted({
    required this.loanType,
    required this.principal,
    required this.durationMonths,
    required this.purpose,
  });
}

class LoanCancellationRequested extends LoanEvent {
  final String loanId;
  final String memberId;
  LoanCancellationRequested({required this.loanId, required this.memberId});
}
