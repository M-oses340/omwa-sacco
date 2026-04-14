part of 'transactions_bloc.dart';

abstract class TransactionsState {}

class TransactionsInitial extends TransactionsState {}
class TransactionsLoading extends TransactionsState {}

// Renamed from TransactionsLoaded_ to avoid conflict with the event name
class TransactionsSuccess extends TransactionsState {
  final List<Map<String, dynamic>> transactions;
  final String? filter;
  TransactionsSuccess({required this.transactions, this.filter});
}

class TransactionsError extends TransactionsState {
  final String message;
  TransactionsError(this.message);
}
