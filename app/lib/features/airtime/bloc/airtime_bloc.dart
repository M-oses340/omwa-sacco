import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'airtime_event.dart';
part 'airtime_state.dart';

class AirtimeBloc extends Bloc<AirtimeEvent, AirtimeState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  AirtimeBloc() : super(AirtimeInitial()) {
    on<AirtimePurchased>(_onPurchased);
  }

  Future<void> _onPurchased(AirtimePurchased event, Emitter<AirtimeState> emit) async {
    emit(AirtimeLoading());
    try {
      final fosa = await ConnectivityService.instance.guard(() =>
          _supabase.from('fosa_accounts').select('balance').eq('member_id', event.memberId).single());
      final balance = double.tryParse(fosa['balance'].toString()) ?? 0;
      if (event.amount > balance) {
        emit(AirtimeError('Insufficient FOSA balance'));
        return;
      }
      await ConnectivityService.instance.guard(() => _supabase.rpc('buy_airtime', params: {
            'p_member_id': event.memberId,
            'p_phone_number': event.phoneNumber,
            'p_network': event.network,
            'p_amount': event.amount,
          }));
      emit(AirtimeSuccess('${event.network} airtime of KES ${event.amount.toStringAsFixed(2)} purchased'));
    } catch (e) {
      emit(AirtimeError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
