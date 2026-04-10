part of 'ratiba_bloc.dart';

abstract class RatibaState {}

class RatibaInitial extends RatibaState {}
class RatibaLoading extends RatibaState {}

class RatibaLoaded extends RatibaState {
  final List<Map<String, dynamic>> schedules;
  RatibaLoaded(this.schedules);
}

class RatibaActionSuccess extends RatibaState {
  final String message;
  final List<Map<String, dynamic>> schedules;
  RatibaActionSuccess({required this.message, required this.schedules});
}

class RatibaError extends RatibaState {
  final String message;
  RatibaError(this.message);
}
