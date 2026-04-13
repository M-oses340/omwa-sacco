part of 'reports_bloc.dart';

abstract class ReportsState {}

class ReportsInitial extends ReportsState {}
class ReportsLoading extends ReportsState {}

// Hub state — member data loaded, ready to show categories
class ReportsHubData extends ReportsState {
  final Map<String, dynamic>? bosa;
  final Map<String, dynamic>? fosa;
  final List<Map<String, dynamic>> recentTransactions;
  final bool isAdmin;

  ReportsHubData({
    this.bosa,
    this.fosa,
    required this.recentTransactions,
    required this.isAdmin,
  });
}

// Individual report viewer state
class ReportViewData extends ReportsState {
  final String reportId;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> allRows;
  final String selectedType;
  final DateTimeRange? dateRange;

  ReportViewData({
    required this.reportId,
    required this.rows,
    required this.allRows,
    required this.selectedType,
    this.dateRange,
  });

  ReportViewData copyWith({
    List<Map<String, dynamic>>? rows,
    String? selectedType,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return ReportViewData(
      reportId: reportId,
      rows: rows ?? this.rows,
      allRows: allRows,
      selectedType: selectedType ?? this.selectedType,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }
}

// Legacy — kept for backward compat during transition
class ReportsData extends ReportsState {
  final List<Map<String, dynamic>> allTransactions;
  final List<Map<String, dynamic>> filtered;
  final Map<String, dynamic>? bosa;
  final Map<String, dynamic>? fosa;
  final String selectedType;
  final DateTimeRange? dateRange;

  ReportsData({
    required this.allTransactions,
    required this.filtered,
    this.bosa,
    this.fosa,
    required this.selectedType,
    this.dateRange,
  });

  ReportsData copyWith({
    List<Map<String, dynamic>>? filtered,
    String? selectedType,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return ReportsData(
      allTransactions: allTransactions,
      filtered: filtered ?? this.filtered,
      bosa: bosa,
      fosa: fosa,
      selectedType: selectedType ?? this.selectedType,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }
}

class ReportsError extends ReportsState {
  final String message;
  ReportsError(this.message);
}
