import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardDataLoaded>(_onLoaded);
  }

  Future<void> _onLoaded(DashboardDataLoaded event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final memberId = event.memberId;
      final results = await ConnectivityService.instance.guard(() => Future.wait([
            _supabase.from('bosa_accounts').select().eq('member_id', memberId).maybeSingle(),
            _supabase.from('fosa_accounts').select().eq('member_id', memberId).maybeSingle(),
            _supabase
                .from('transactions')
                .select()
                .eq('member_id', memberId)
                .order('created_at', ascending: false)
                .limit(3),
          ]));

      emit(DashboardSuccess(
        bosa: results[0] as Map<String, dynamic>?,
        fosa: results[1] as Map<String, dynamic>?,
        recentTransactions: (results[2] as List).cast<Map<String, dynamic>>(),
      ));
    } catch (e) {
      emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
