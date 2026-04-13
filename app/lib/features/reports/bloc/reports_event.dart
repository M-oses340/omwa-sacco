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
  final Map<String, dynamic>? params;
  ReportViewRequested({required this.reportId, required this.memberId, this.params});
}

class ReportsFilterChanged extends ReportsEvent {
  final String? type;
  final DateTimeRange? dateRange;
  final String? search;
  ReportsFilterChanged({this.type, this.dateRange, this.search});
}

class ReportsDateRangeCleared extends ReportsEvent {}

class ReportsSearchChanged extends ReportsEvent {
  final String query;
  ReportsSearchChanged(this.query);
}

class ReportsLoadMoreRequested extends ReportsEvent {}

class ReportsDatePresetApplied extends ReportsEvent {
  final DatePreset preset;
  ReportsDatePresetApplied(this.preset);
}

enum DatePreset { today, thisWeek, thisMonth, lastMonth, thisYear }

extension DatePresetX on DatePreset {
  String get label => switch (this) {
        DatePreset.today => 'Today',
        DatePreset.thisWeek => 'This Week',
        DatePreset.thisMonth => 'This Month',
        DatePreset.lastMonth => 'Last Month',
        DatePreset.thisYear => 'This Year',
      };

  DateTimeRange get range {
    final now = DateTime.now();
    return switch (this) {
      DatePreset.today => DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59)),
      DatePreset.thisWeek => DateTimeRange(
          start: now.subtract(Duration(days: now.weekday - 1)),
          end: now),
      DatePreset.thisMonth => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now),
      DatePreset.lastMonth => DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59)),
      DatePreset.thisYear => DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now),
    };
  }
}
