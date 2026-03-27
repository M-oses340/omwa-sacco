import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  TransactionBloc() : super(TransactionInitial()) {
    on<DepositInitiated>(_onDepositInitiated);
    on<CheckoutCompleted>(_onCheckoutCompleted);
  }

  Future<void> _onDepositInitiated(
      DepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        emit(TransactionError('Session expired. Please log in again.'));
        return;
      }

      debugPrint('[TRANSACTION] Initiating checkout');

      final response = await ConnectivityService.instance.guard(() async {
        return await _supabase.functions.invoke(
          'initiate-checkout',
          body: {},
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );
      });

      final data = response.data as Map<String, dynamic>;
      debugPrint('[TRANSACTION] Checkout URL: ${data['checkout_url']}');

      if (data['success'] == true) {
        emit(TransactionCheckoutReady(
          checkoutUrl: data['checkout_url'],
          transactionId: data['transaction_id'],
          amount: 0,
        ));
      } else {
        emit(TransactionError(data['error'] ?? 'Failed to initiate deposit'));
      }
    } on FunctionException catch (e) {
      debugPrint('[TRANSACTION] Function error: ${e.details}');
      emit(TransactionError('Payment service error. Please try again.'));
    } catch (e) {
      debugPrint('[TRANSACTION] Error: $e');
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCheckoutCompleted(
      CheckoutCompleted event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final tx = await _supabase
          .from('transactions')
          .select('status, amount')
          .eq('id', event.transactionId)
          .single();

      final amount = double.tryParse(tx['amount'].toString()) ?? 0;

      if (event.success) {
        emit(TransactionSuccess(
            'Deposit of KES ${amount.toStringAsFixed(2)} is being processed'));
      } else {
        await _supabase
            .from('transactions')
            .update({'status': 'failed'})
            .eq('id', event.transactionId);
        emit(TransactionError('Payment was cancelled'));
      }
    } catch (e) {
      emit(TransactionError(e.toString()));
    }
  }
}
