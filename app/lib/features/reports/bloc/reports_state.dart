part of 'reports_bloc.dart';

abstract class ReportsState {}

class ReportsInitial extends ReportsState {}
class ReportsLoading extends ReportsState {}

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
