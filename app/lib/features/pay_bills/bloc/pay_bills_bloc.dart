import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'pay_bills_event.dart';
part 'pay_bills_state.dart';

class PayBillsBloc extends Bloc<PayBillsEvent, PayBillsState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  PayBillsBloc() : super(PayBillsInitial()) {
    on<PayBillSubmitted>(_onPayBill);
    on<TillPaymentSubmitted>(_onTill);
  }

  Future<void> _checkBalance(String memberId, double amount) async {
    final fosa = await ConnectivityService.instance.guard(() =>
        _supabase.from('fosa_accounts').select('balance').eq('member_id', memberId).single());
    final balance = double.tryParse(fosa['balance'].toString()) ?? 0;
    if (amount > balance) throw Exception('Insufficient FOSA balance');
  }

  Future<void> _onPayBill(PayBillSubmitted event, Emitter<PayBillsState> emit) async {
    emit(PayBillsLoading());
    try {
      await _checkBalance(event.memberId, event.amount);
      await ConnectivityService.instance.guard(() => _supabase.rpc('paybill_payment', params: {
            'p_member_id': event.memberId,
            'p_business_number': event.businessNumber,
            'p_account_number': event.accountNumber,
            'p_amount': event.amount,
          }));
      emit(PayBillsSuccess('Paybill payment of KES ${event.amount.toStringAsFixed(2)} successful'));
    } catch (e) {
      emit(PayBillsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onTill(TillPaymentSubmitted event, Emitter<PayBillsState> emit) async {
    emit(PayBillsLoading());
    try {
      await _checkBalance(event.memberId, event.amount);
      await ConnectivityService.instance.guard(() => _supabase.rpc('till_payment', params: {
            'p_member_id': event.memberId,
            'p_till_number': event.tillNumber,
            'p_amount': event.amount,
          }));
      emit(PayBillsSuccess('Till payment of KES ${event.amount.toStringAsFixed(2)} successful'));
    } catch (e) {
      emit(PayBillsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
