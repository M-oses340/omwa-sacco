part of 'loan_bloc.dart';

abstract class LoanState {}

class LoanInitial extends LoanState {}

class LoanLoading extends LoanState {}

class LoanHistoryLoaded extends LoanState {
  final List<LoanModel> loans;
  final double bosaSavings;   // used to compute loan limit in UI
  final double fosaBalance;
  LoanHistoryLoaded(this.loans, {this.bosaSavings = 0, this.fosaBalance = 0});
}

class LoanApplicationSuccess extends LoanState {
  final LoanModel loan;
  LoanApplicationSuccess(this.loan);
}

class LoanCancelSuccess extends LoanState {}

class LoanError extends LoanState {
  final String message;
  LoanError(this.message);
}
