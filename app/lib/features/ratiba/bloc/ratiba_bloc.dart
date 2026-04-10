import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'ratiba_event.dart';
part 'ratiba_state.dart';

class RatibaBloc extends Bloc<RatibaEvent, RatibaState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  RatibaBloc() : super(RatibaInitial()) {
    on<RatibaSchedulesLoaded>(_onLoaded);
    on<RatibaScheduleCreated>(_onCreated);
    on<RatibaScheduleCancelled>(_onCancelled);
  }

  Future<List<Map<String, dynamic>>> _fetchSchedules(String memberId) async {
    final data = await ConnectivityService.instance.guard(() =>
        _supabase.from('scheduled_payments').select().eq('member_id', memberId).order('next_run_date', ascending: true));
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> _onLoaded(RatibaSchedulesLoaded event, Emitter<RatibaState> emit) async {
    emit(RatibaLoading());
    try {
      emit(RatibaLoaded(await _fetchSchedules(event.memberId)));
    } catch (e) {
      emit(RatibaError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreated(RatibaScheduleCreated event, Emitter<RatibaState> emit) async {
    emit(RatibaLoading());
    try {
      await ConnectivityService.instance.guard(() => _supabase.from('scheduled_payments').insert({
            'member_id': event.memberId,
            'payment_type': event.paymentType,
            'amount': event.amount,
            'frequency': event.frequency,
            'next_run_date': event.startDate.toIso8601String(),
            'description': event.description,
            'status': 'active',
          }));
      final schedules = await _fetchSchedules(event.memberId);
      emit(RatibaActionSuccess(message: 'Schedule created successfully', schedules: schedules));
    } catch (e) {
      emit(RatibaError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCancelled(RatibaScheduleCancelled event, Emitter<RatibaState> emit) async {
    try {
      await ConnectivityService.instance.guard(() =>
          _supabase.from('scheduled_payments').update({'status': 'cancelled'}).eq('id', event.scheduleId));
      final schedules = await _fetchSchedules(event.memberId);
      emit(RatibaActionSuccess(message: 'Schedule cancelled', schedules: schedules));
    } catch (e) {
      emit(RatibaError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
