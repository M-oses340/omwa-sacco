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
  final String destinationType;
  final String destinationAccount;
  final String destinationName;
  final String destinationRef;
  RatibaScheduleCreated({
    required this.memberId,
    required this.paymentType,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.description,
    required this.destinationType,
    required this.destinationAccount,
    required this.destinationName,
    required this.destinationRef,
  });
}

class RatibaScheduleStatusToggled extends RatibaEvent {
  final String scheduleId;
  final String memberId;
  final String newStatus; // 'active' or 'paused'
  RatibaScheduleStatusToggled({
    required this.scheduleId,
    required this.memberId,
    required this.newStatus,
  });
}

class RatibaScheduleCancelled extends RatibaEvent {
  final String scheduleId;
  final String memberId;
  RatibaScheduleCancelled({required this.scheduleId, required this.memberId});
}
