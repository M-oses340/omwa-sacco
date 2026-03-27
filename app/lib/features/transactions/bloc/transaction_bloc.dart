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
    on<DepositStatusChecked>(_onDepositStatusChecked);
    on<BankCheckoutCompleted>(_onBankCheckoutCompleted);
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

      debugPrint('[TRANSACTION] Session user: ${session.user.id}');
      debugPrint('[TRANSACTION] Token (first 20): ${session.accessToken.substring(0, 20)}...');
      debugPrint('[TRANSACTION] Method: ${event.method}');

      final functionName = event.method == 'bank'
          ? 'initiate-bank-deposit'
          : 'initiate-deposit';

      final response = await ConnectivityService.instance.guard(() async {
        return await _supabase.functions.invoke(
          functionName,
          body: {'amount': event.amount},
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );
      });

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        if (event.method == 'bank') {
          emit(TransactionBankCheckoutReady(
            checkoutUrl: data['checkout_url'],
            transactionId: data['transaction_id'],
            amount: event.amount,
          ));
        } else {
          emit(TransactionStkPushSent(
            transactionId: data['transaction_id'],
            invoiceId: data['invoice_id'] ?? '',
            amount: event.amount,
          ));
        }
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

  Future<void> _onDepositStatusChecked(
      DepositStatusChecked event, Emitter<TransactionState> emit) async {
    try {
      final tx = await _supabase
          .from('transactions')
          .select('status, amount')
          .eq('id', event.transactionId)
          .single();

      final status = tx['status'] as String;
      final amount = double.tryParse(tx['amount'].toString()) ?? 0;

      if (status == 'completed') {
        emit(TransactionSuccess(
            'Deposit of KES ${amount.toStringAsFixed(2)} successful'));
      } else if (status == 'failed') {
        emit(TransactionError('Payment failed. Please try again.'));
      }
    } catch (e) {
      debugPrint('[TRANSACTION] Status check error: $e');
    }
  }

  Future<void> _onBankCheckoutCompleted(
      BankCheckoutCompleted event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      if (event.success) {
        // Webhook will handle the actual credit — just check status
        final tx = await _supabase
            .from('transactions')
            .select('status, amount')
            .eq('id', event.transactionId)
            .single();

        final amount = double.tryParse(tx['amount'].toString()) ?? 0;
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
