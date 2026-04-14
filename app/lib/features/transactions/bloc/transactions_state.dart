part of 'transactions_bloc.dart';

abstract class TransactionsState {}

class TransactionsInitial extends TransactionsState {}
class TransactionsLoading extends TransactionsState {}

// Named with trailing underscore to avoid conflict with the event
class TransactionsLoaded_ extends TransactionsState {
  final List<Map<String, dynamic>> transactions;
  final String? filter;
  TransactionsLoaded_({required this.transactions, this.filter});
}

class TransactionsError extends TransactionsState {
  final String message;
  TransactionsError(this.message);
}
