part of 'reports_bloc.dart';

abstract class ReportsState {}

class ReportsInitial extends ReportsState {}
class ReportsLoading extends ReportsState {}

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

class ReportViewData extends ReportsState {
  final String reportId;
  final List<Map<String, dynamic>> allRows;   // full unfiltered dataset
  final List<Map<String, dynamic>> rows;      // filtered + searched + paginated view
  final String selectedType;
  final DateTimeRange? dateRange;
  final String searchQuery;
  final int page;
  final int pageSize;
  final bool hasMore;

  ReportViewData({
    required this.reportId,
    required this.allRows,
    required this.rows,
    required this.selectedType,
    this.dateRange,
    this.searchQuery = '',
    this.page = 0,
    this.pageSize = 50,
    this.hasMore = false,
  });

  ReportViewData copyWith({
    List<Map<String, dynamic>>? rows,
    List<Map<String, dynamic>>? allRows,
    String? selectedType,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? searchQuery,
    int? page,
    bool? hasMore,
  }) {
    return ReportViewData(
      reportId: reportId,
      allRows: allRows ?? this.allRows,
      rows: rows ?? this.rows,
      selectedType: selectedType ?? this.selectedType,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      pageSize: pageSize,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ReportsError extends ReportsState {
  final String message;
  ReportsError(this.message);
}
