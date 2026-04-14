part of 'dashboard_bloc.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}

class DashboardSuccess extends DashboardState {
  final Map<String, dynamic>? bosa;
  final Map<String, dynamic>? fosa;
  final List<Map<String, dynamic>> recentTransactions;
  DashboardSuccess({required this.bosa, required this.fosa, required this.recentTransactions});
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}
