part of 'dashboard_bloc.dart';

abstract class DashboardEvent {}

class DashboardDataLoaded extends DashboardEvent {
  final String memberId;
  DashboardDataLoaded({required this.memberId});
}
