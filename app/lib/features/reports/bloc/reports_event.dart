part of 'reports_bloc.dart';

abstract class ReportsEvent {}

// Hub
class ReportsLoaded extends ReportsEvent {
  final String memberId;
  ReportsLoaded(this.memberId);
}

// Viewer
class ReportViewRequested extends ReportsEvent {
  final String reportId;
  final String memberId;
  ReportViewRequested({required this.reportId, required this.memberId});
}

class ReportsFilterChanged extends ReportsEvent {
  final String? type;
  final DateTimeRange? dateRange;
  ReportsFilterChanged({this.type, this.dateRange});
}

class ReportsDateRangeCleared extends ReportsEvent {}
