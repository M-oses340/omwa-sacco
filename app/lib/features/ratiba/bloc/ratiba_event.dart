part of 'ratiba_bloc.dart';

abstract class RatibaEvent {}

class RatibaSchedulesLoaded extends RatibaEvent {
  final String memberId;
  RatibaSchedulesLoaded(this.memberId);
}

class RatibaScheduleCreated extends RatibaEvent {
  final String memberId;
  final String paymentType;
  final double amount;
  final String frequency;
  final DateTime startDate;
  final String description;
  RatibaScheduleCreated({
    required this.memberId,
    required this.paymentType,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.description,
  });
}

class RatibaScheduleCancelled extends RatibaEvent {
  final String scheduleId;
  final String memberId;
  RatibaScheduleCancelled({required this.scheduleId, required this.memberId});
}
