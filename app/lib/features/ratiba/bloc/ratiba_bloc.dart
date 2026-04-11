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
    on<RatibaScheduleStatusToggled>(_onToggled);
    on<RatibaScheduleCancelled>(_onCancelled);
  }

  Future<List<Map<String, dynamic>>> _fetchSchedules(String memberId) async {
    final data = await ConnectivityService.instance.guard(() =>
        _supabase
            .from('scheduled_payments')
            .select()
            .eq('member_id', memberId)
            .order('next_run_date', ascending: true));
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
      // DB column is DATE — send YYYY-MM-DD only
      final dateStr =
          '${event.startDate.year.toString().padLeft(4, '0')}-'
          '${event.startDate.month.toString().padLeft(2, '0')}-'
          '${event.startDate.day.toString().padLeft(2, '0')}';

      await ConnectivityService.instance.guard(() =>
          _supabase.from('scheduled_payments').insert({
            'member_id': event.memberId,
            'payment_type': event.paymentType,
            'amount': event.amount,
            'frequency': event.frequency,
            'next_run_date': dateStr,
            'description': event.description.isNotEmpty
                ? event.description
                : '${event.paymentType} - ${event.frequency}',
            'status': 'active',
            'destination_type': event.destinationType,
            'destination_account': event.destinationAccount,
            'destination_name': event.destinationName,
            'destination_ref': event.destinationRef,
          }));
      final schedules = await _fetchSchedules(event.memberId);
      emit(RatibaActionSuccess(message: 'Schedule created successfully', schedules: schedules));
    } catch (e) {
      emit(RatibaError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onToggled(RatibaScheduleStatusToggled event, Emitter<RatibaState> emit) async {
    try {
      await ConnectivityService.instance.guard(() =>
          _supabase
              .from('scheduled_payments')
              .update({'status': event.newStatus})
              .eq('id', event.scheduleId));
      final schedules = await _fetchSchedules(event.memberId);
      final label = event.newStatus == 'active' ? 'resumed' : 'paused';
      emit(RatibaActionSuccess(message: 'Schedule $label', schedules: schedules));
    } catch (e) {
      emit(RatibaError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCancelled(RatibaScheduleCancelled event, Emitter<RatibaState> emit) async {
    try {
      await ConnectivityService.instance.guard(() =>
          _supabase
              .from('scheduled_payments')
              .update({'status': 'cancelled'})
              .eq('id', event.scheduleId));
      final schedules = await _fetchSchedules(event.memberId);
      emit(RatibaActionSuccess(message: 'Schedule cancelled', schedules: schedules));
    } catch (e) {
      emit(RatibaError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
