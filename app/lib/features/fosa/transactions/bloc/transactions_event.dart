part of 'transactions_bloc.dart';

abstract class TransactionsEvent {}

class TransactionsLoaded extends TransactionsEvent {
  final String memberId;
  final String? type; // optional filter
  TransactionsLoaded({required this.memberId, this.type});
}
