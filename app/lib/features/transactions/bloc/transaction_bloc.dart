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
    on<WithdrawInitiated>(_onWithdrawInitiated);
    on<InternalTransferInitiated>(_onInternalTransfer);
    on<ExternalTransferInitiated>(_onExternalTransfer);
  }

  /// Always returns a valid access token by refreshing the session.
  Future<String?> _freshToken() async {
    try {
      // Force refresh to guarantee a valid token
      final refreshed = await _supabase.auth.refreshSession();
      final token = refreshed.session?.accessToken;
      if (token != null) return token;
    } catch (_) {
      // Refresh failed — fall back to current session
    }
    return _supabase.auth.currentSession?.accessToken;
  }

  Future<void> _onDepositInitiated(
      DepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final token = await _freshToken();
      if (token == null) {
        emit(TransactionError('Session expired. Please log in again.'));
        return;
      }

      debugPrint('[TRANSACTION] Initiating checkout for KES ${event.amount}');

      final response = await ConnectivityService.instance.guard(() async {
        return await _supabase.functions.invoke(
          'initiate-checkout',
          body: {'amount': event.amount},
          headers: {'Authorization': 'Bearer $token'},
        );
      });

      final data = response.data as Map<String, dynamic>;
      debugPrint('[TRANSACTION] Checkout URL: ${data['checkout_url']}');

      if (data['success'] == true) {
        emit(TransactionCheckoutReady(
          checkoutUrl: data['checkout_url'],
          transactionId: data['transaction_id'],
          amount: event.amount,
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

  Future<void> _onWithdrawInitiated(
      WithdrawInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final token = await _freshToken();
      debugPrint('[WITHDRAW] amount=${event.amount} phone=${event.phoneNumber}');
      if (token == null) {
        emit(TransactionError('Session expired. Please log in again.'));
        return;
      }

      final fosa = await ConnectivityService.instance.guard(() => _supabase
          .from('fosa_accounts')
          .select('id, balance, account_number')
          .eq('member_id', event.memberId)
          .single());

      final balance = double.tryParse(fosa['balance'].toString()) ?? 0;
      if (event.amount > balance) {
        emit(TransactionError(
            'Insufficient balance. Available: KES ${balance.toStringAsFixed(2)}'));
        return;
      }

      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'initiate-withdrawal',
            body: {
              'amount': event.amount,
              'phone': event.phoneNumber,
              'method': 'mpesa',
            },
            headers: {'Authorization': 'Bearer $token'},
          ));

      final data = response.data as Map<String, dynamic>;
      debugPrint('[WITHDRAW] Edge function response: $data');
      if (data['success'] == true) {
        emit(TransactionSuccess(
            'Withdrawal of KES ${event.amount.toStringAsFixed(2)} to ${event.phoneNumber} is being processed.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Withdrawal failed'));
      }
    } on FunctionException catch (e) {
      debugPrint('[WITHDRAW] FunctionException: ${e.details}');
      emit(TransactionError('Service error: ${e.details}'));
    } catch (e) {
      debugPrint('[WITHDRAW] Error: $e');
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

  Future<void> _onInternalTransfer(
      InternalTransferInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final token = await _freshToken();
      if (token == null) {
        emit(TransactionError('Session expired. Please log in again.'));
        return;
      }

      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'initiate-transfer',
            body: {
              'type': 'internal',
              'to_member_number': event.toMemberNumber,
              'amount': event.amount,
              'note': event.note,
            },
            headers: {'Authorization': 'Bearer $token'},
          ));

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        emit(TransactionSuccess(
            'KES ${event.amount.toStringAsFixed(2)} transferred to ${event.toMemberNumber}.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Transfer failed'));
      }
    } on FunctionException catch (e) {
      emit(TransactionError('Service error: ${e.details}'));
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onExternalTransfer(
      ExternalTransferInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final token = await _freshToken();
      if (token == null) {
        emit(TransactionError('Session expired. Please log in again.'));
        return;
      }

      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'initiate-transfer',
            body: {
              'type': 'external',
              'bank_code': event.bankCode,
              'account_number': event.accountNumber,
              'account_name': event.accountName,
              'amount': event.amount,
            },
            headers: {'Authorization': 'Bearer $token'},
          ));

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        emit(TransactionSuccess(
            'KES ${event.amount.toStringAsFixed(2)} bank transfer initiated.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Transfer failed'));
      }
    } on FunctionException catch (e) {
      emit(TransactionError('Service error: ${e.details}'));
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
