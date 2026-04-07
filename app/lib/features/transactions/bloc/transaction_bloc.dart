import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/constants/supabase_constants.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  TransactionBloc() : super(TransactionInitial()) {
    on<DepositInitiated>(_onDepositInitiated);
    on<CardDepositInitiated>(_onCardDepositInitiated);
    on<CheckoutCompleted>(_onCheckoutCompleted);
    on<WithdrawInitiated>(_onWithdrawInitiated);
    on<InternalTransferInitiated>(_onInternalTransfer);
    on<ExternalTransferInitiated>(_onExternalTransfer);
  }

  /// Centralized invoker for Edge Functions.
  /// Uses a 60s timeout to accommodate IntaSend Sandbox latency.
  Future<Map<String, dynamic>> _invoke(String fn, Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;

    // Always try to get a fresh session
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session != null) session = refreshed.session!;
    } catch (e) {
      debugPrint('[INVOKE] refresh failed: $e — using existing session');
      // Re-read session in case it was updated externally
      session = _supabase.auth.currentSession ?? session;
    }

    if (session == null) {
      return {'success': false, 'error': 'Session expired. Please log in again.'};
    }

    final token = session.accessToken;

    final payload = {
      ...body, 
      'jwt': token
    };
    
    final url = Uri.parse('${SupabaseConstants.url}/functions/v1/$fn');

    try {
      debugPrint('[INVOKE] calling $fn, jwt prefix: ${token.substring(0, 20)}');
      debugPrint('[INVOKE] full body: ${jsonEncode(payload).substring(0, 100)}');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConstants.anonKey,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60)); // Increased to handle EarlyDrop

      if (res.body.isEmpty) {
        return {'success': false, 'error': 'Empty response from server.'};
      }

      final data = jsonDecode(res.body);
      debugPrint('[INVOKE] $fn status=${res.statusCode} body=${res.body.substring(0, res.body.length.clamp(0, 100))}');
      
      if (res.statusCode != 200) {
        // Capture specific IntaSend or Deno error messages
        final String errorMsg = data['error'] ?? data['detail'] ?? 'Error: ${res.statusCode}';
        return {'success': false, 'error': errorMsg};
      }
      
      return data as Map<String, dynamic>;
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out. Please check your connection.'};
    } catch (e) {
      debugPrint('[TRANSACTION_BLOC] Invoke Exception: $e');
      return {'success': false, 'error': 'Connection error. Please try again.'};
    }
  }

  // ── M-Pesa STK Push ────────────────────────────────────────────────────────
  Future<void> _onDepositInitiated(
      DepositInitiated event, Emitter<TransactionState> emit) async {
    debugPrint('[BLOC] DepositInitiated: amount=${event.amount}');
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'deposit_mpesa', 'amount': event.amount}));
      debugPrint('[BLOC] deposit_mpesa response: $data');
      if (data['success'] == true) {
        emit(TransactionSuccess(data['message'] ?? 'M-Pesa STK prompt sent.'));
      } else {
        emit(TransactionError(data['error'] ?? 'M-Pesa initiation failed.'));
      }
    } catch (e) {
      debugPrint('[BLOC] DepositInitiated error: $e');
      emit(TransactionError(_cleanError(e)));
    }
  }

  // ── Card / Bank Checkout (IntaSend) ─────────────────────────────────────────
  Future<void> _onCardDepositInitiated(
      CardDepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'deposit_card', 'amount': event.amount}));

      if (data['success'] == true) {
        debugPrint('[CHECKOUT_URL] ${data['checkout_url']}');
        emit(TransactionCheckoutReady(
          checkoutUrl: data['checkout_url'],
          transactionId: data['transaction_id'],
          amount: event.amount,
        ));
      } else {
        emit(TransactionError(data['error'] ?? 'Checkout initialization failed.'));
      }
    } catch (e) {
      emit(TransactionError(_cleanError(e)));
    }
  }

  // ── WebView Completion Logic ────────────────────────────────────────────────
  Future<void> _onCheckoutCompleted(
      CheckoutCompleted event, Emitter<TransactionState> emit) async {
    if (event.success) {
      emit(TransactionSuccess('Payment received! Updating your balance shortly.'));
    } else {
      emit(TransactionError('Payment was cancelled or failed.'));
      // Optional: Inform the DB that the user cancelled
      try {
        await _supabase
            .from('transactions')
            .update({'status': 'cancelled'})
            .eq('id', event.transactionId);
      } catch (_) {} 
    }
  }

  // ── M-Pesa B2C Withdrawal ───────────────────────────────────────────────────
  Future<void> _onWithdrawInitiated(
      WithdrawInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'withdraw', 'amount': event.amount}));
      
      if (data['success'] == true) {
        emit(TransactionSuccess(
            'Withdrawal of KES ${event.amount.toStringAsFixed(2)} is processing.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Withdrawal failed.'));
      }
    } catch (e) {
      emit(TransactionError(_cleanError(e)));
    }
  }

  // ── Internal Member-to-Member Transfer ──────────────────────────────────────
  Future<void> _onInternalTransfer(
      InternalTransferInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke(
          'transfer', {
            'type': 'internal',
            'to_member_number': event.toMemberNumber,
            'amount': event.amount,
            'note': event.note,
          }));

      if (data['success'] == true) {
        emit(TransactionSuccess('Transfer to ${event.toMemberNumber} successful.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Internal transfer failed.'));
      }
    } catch (e) {
      emit(TransactionError(_cleanError(e)));
    }
  }

  // ── External Bank (EFT/RTGS) Transfer ───────────────────────────────────────
  Future<void> _onExternalTransfer(
      ExternalTransferInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke(
          'transfer', {
            'type': 'external',
            'bank_code': event.bankCode,
            'account_number': event.accountNumber,
            'account_name': event.accountName,
            'amount': event.amount,
          }));

      if (data['success'] == true) {
        emit(TransactionSuccess('Bank transfer initiated successfully.'));
      } else {
        emit(TransactionError(data['error'] ?? 'External transfer failed.'));
      }
    } catch (e) {
      emit(TransactionError(_cleanError(e)));
    }
  }

  String _cleanError(dynamic e) {
    return e.toString()
        .replaceAll('Exception: ', '')
        .replaceAll('HttpException: ', '')
        .split(':')
        .last
        .trim();
  }
}