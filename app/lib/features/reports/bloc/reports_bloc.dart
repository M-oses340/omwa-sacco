import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'reports_event.dart';
part 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  ReportsBloc() : super(ReportsInitial()) {
    on<ReportsLoaded>(_onLoaded);
    on<ReportsFilterChanged>(_onFilterChanged);
    on<ReportsDateRangeCleared>(_onDateRangeCleared);
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> all,
    String type,
    DateTimeRange? range,
  ) {
    return all.where((tx) {
      final typeMatch = type == 'all' || tx['transaction_type'] == type;
      final date = DateTime.tryParse(tx['created_at'] ?? '');
      final dateMatch = range == null || (date != null && !date.isBefore(range.start) && !date.isAfter(range.end));
      return typeMatch && dateMatch;
    }).toList();
  }

  Future<void> _onLoaded(ReportsLoaded event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final results = await ConnectivityService.instance.guard(() => Future.wait([
            _supabase.from('bosa_accounts').select().eq('member_id', event.memberId).maybeSingle(),
            _supabase.from('fosa_accounts').select().eq('member_id', event.memberId).maybeSingle(),
            _supabase.from('transactions').select().eq('member_id', event.memberId).order('created_at', ascending: false),
          ]));
      final all = (results[2] as List).cast<Map<String, dynamic>>();
      emit(ReportsData(
        allTransactions: all,
        filtered: all,
        bosa: results[0] as Map<String, dynamic>?,
        fosa: results[1] as Map<String, dynamic>?,
        selectedType: 'all',
      ));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _onFilterChanged(ReportsFilterChanged event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportsData) return;
    final newType = event.type ?? current.selectedType;
    final newRange = event.dateRange ?? current.dateRange;
    emit(current.copyWith(
      selectedType: newType,
      dateRange: newRange,
      filtered: _applyFilter(current.allTransactions, newType, newRange),
    ));
  }

  void _onDateRangeCleared(ReportsDateRangeCleared event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportsData) return;
    emit(current.copyWith(
      clearDateRange: true,
      filtered: _applyFilter(current.allTransactions, current.selectedType, null),
    ));
  }
}
