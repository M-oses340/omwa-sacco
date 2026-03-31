part of 'loan_bloc.dart';

abstract class LoanState {}

class LoanInitial extends LoanState {}

class LoanLoading extends LoanState {}

class LoanHistoryLoaded extends LoanState {
  final List<LoanModel> loans;
  LoanHistoryLoaded(this.loans);
}

class LoanApplicationSuccess extends LoanState {
  final LoanModel loan;
  LoanApplicationSuccess(this.loan);
}

class LoanError extends LoanState {
  final String message;
  LoanError(this.message);
}
