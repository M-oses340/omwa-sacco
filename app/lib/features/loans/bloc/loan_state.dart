part of 'loan_bloc.dart';

abstract class LoanState {}

class LoanInitial extends LoanState {}

class LoanLoading extends LoanState {}

class LoanHistoryLoaded extends LoanState {
  final List<LoanModel> loans;
  final double bosaSavings;
  final double fosaBalance;
  LoanHistoryLoaded(this.loans, {this.bosaSavings = 0, this.fosaBalance = 0});
}

class LoanApplicationSuccess extends LoanState {
  final LoanModel loan;
  final List<AmortizationEntry> schedule;
  LoanApplicationSuccess(this.loan, {this.schedule = const []});
}

class LoanCancelSuccess extends LoanState {}

class LoanScheduleLoaded extends LoanState {
  final List<AmortizationEntry> schedule;
  LoanScheduleLoaded(this.schedule);
}

class LoanRepaymentSuccess extends LoanState {
  final double amountPaid;
  final double balanceAfter;
  LoanRepaymentSuccess({required this.amountPaid, required this.balanceAfter});
}

class LoanError extends LoanState {
  final String message;
  LoanError(this.message);
}
