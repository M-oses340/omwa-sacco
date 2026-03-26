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
    on<DepositCompleted>(_onDepositCompleted);
  }

  /// Creates a pending transaction and returns the reference
  Future<void> _onDepositInitiated(
      DepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final ref = await ConnectivityService.instance.guard(() async {
        // Generate reference
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final reference = 'DEP-$timestamp';

        // Insert pending transaction
        await _supabase.from('transactions').insert({
          'member_id': event.memberId,
          'account_type': event.accountType,
          'transaction_type': 'deposit',
          'amount': event.amount,
          'reference': reference,
          'description': event.description ?? 'Deposit via ${event.paymentMethod}',
          'status': 'pending',
        });

        return reference;
      });

      emit(TransactionPendingCheckout(
        reference: ref,
        amount: event.amount,
        accountType: event.accountType,
        memberId: event.memberId,
      ));
    } on PostgrestException catch (e) {
      debugPrint('[TRANSACTION] DB error: ${e.message}');
      emit(TransactionError('Failed to initiate deposit: ${e.message}'));
    } catch (e) {
      debugPrint('[TRANSACTION] Error: $e');
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Called after IntaSend checkout completes — updates transaction + balance
  Future<void> _onDepositCompleted(
      DepositCompleted event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      await ConnectivityService.instance.guard(() async {
        // Update transaction status
        await _supabase
            .from('transactions')
            .update({
              'status': event.success ? 'completed' : 'failed',
              'intasend_ref': event.intasendRef,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('reference', event.reference);

        if (event.success) {
          // Update account balance
          if (event.accountType == 'bosa') {
            final account = await _supabase
                .from('bosa_accounts')
                .select('savings_balance')
                .eq('member_id', event.memberId)
                .single();

            final current =
                double.tryParse(account['savings_balance'].toString()) ?? 0;
            await _supabase.from('bosa_accounts').update({
              'savings_balance': current + event.amount,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('member_id', event.memberId);
          } else {
            final account = await _supabase
                .from('fosa_accounts')
                .select('balance')
                .eq('member_id', event.memberId)
                .single();

            final current =
                double.tryParse(account['balance'].toString()) ?? 0;
            await _supabase.from('fosa_accounts').update({
              'balance': current + event.amount,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('member_id', event.memberId);
          }
        }
      });

      if (event.success) {
        emit(TransactionSuccess('Deposit of KES ${event.amount.toStringAsFixed(2)} successful'));
      } else {
        emit(TransactionError('Payment was not completed'));
      }
    } catch (e) {
      debugPrint('[TRANSACTION] Complete error: $e');
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
