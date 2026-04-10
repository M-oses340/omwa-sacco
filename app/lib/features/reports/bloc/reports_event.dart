part of 'reports_bloc.dart';

abstract class ReportsEvent {}

class ReportsLoaded extends ReportsEvent {
  final String memberId;
  ReportsLoaded(this.memberId);
}

class ReportsFilterChanged extends ReportsEvent {
  final String? type;
  final DateTimeRange? dateRange;
  ReportsFilterChanged({this.type, this.dateRange});
}

class ReportsDateRangeCleared extends ReportsEvent {}
