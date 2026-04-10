part of 'airtime_bloc.dart';

abstract class AirtimeState {}

class AirtimeInitial extends AirtimeState {}
class AirtimeLoading extends AirtimeState {}

class AirtimeSuccess extends AirtimeState {
  final String message;
  AirtimeSuccess(this.message);
}

class AirtimeError extends AirtimeState {
  final String message;
  AirtimeError(this.message);
}
