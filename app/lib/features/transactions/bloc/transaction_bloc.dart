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

  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ6a3VkbWZ1dXRzenNwemZoem5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0Mzg2NjcsImV4cCI6MjA5MDAxNDY2N30.4ur7dJ_jeVDxg2Xta2YJsJmeI0vux8CYFsEO-hsL1Q8';

  // Raw HTTP — bypasses supabase_flutter which overrides Authorization header.
  // Sends anon key as Authorization + user JWT in body.jwt.
  Future<Map<String, dynamic>> _invoke(
      String fn, Map<String, dynamic> body) async {
    final token = _supabase.auth.currentSession?.accessToken;
    debugPrint('[INVOKE] $fn token_len=${token?.length}');
    final payload = token != null ? {...body, 'jwt': token} : body;
    final url = Uri.parse('${SupabaseConstants.url}/functions/v1/$fn');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
      },
      body: jsonEncode(payload),
    );
    debugPrint('[INVOKE] $fn → ${res.statusCode} ${res.body.substring(0, res.body.length.clamp(0, 120))}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── M-Pesa STK deposit ──────────────────────────────────────────────────────
  Future<void> _onDepositInitiated(
      DepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'deposit_mpesa', 'amount': event.amount}));
      if (data['success'] == true) {
        emit(TransactionSuccess(data['message'] ?? 'M-Pesa prompt sent.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Deposit failed'));
      }
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Card / Bank checkout deposit ────────────────────────────────────────────
  Future<void> _onCardDepositInitiated(
      CardDepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final data = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'deposit_card', 'amount': event.amount}));
      if (data['success'] == true) {
        emit(TransactionCheckoutReady(
          checkoutUrl: data['checkout_url'],
          transactionId: data['transaction_id'],
          amount: event.amount,
        ));
      } else {
        emit(TransactionError(data['error'] ?? 'Checkout failed'));
      }
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Checkout completed (WebView result) ─────────────────────────────────────
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

  // ── Withdrawal ──────────────────────────────────────────────────────────────
  Future<void> _onWithdrawInitiated(
      WithdrawInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final fosa = await ConnectivityService.instance.guard(() => _supabase
          .from('fosa_accounts')
          .select('balance')
          .eq('member_id', event.memberId)
          .single());
      final balance = double.tryParse(fosa['balance'].toString()) ?? 0;
      if (event.amount > balance) {
        emit(TransactionError(
            'Insufficient balance. Available: KES ${balance.toStringAsFixed(2)}'));
        return;
      }
      final data = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'withdraw', 'amount': event.amount}));
      if (data['success'] == true) {
        emit(TransactionSuccess(
            'Withdrawal of KES ${event.amount.toStringAsFixed(2)} is being processed.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Withdrawal failed'));
      }
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Internal transfer ───────────────────────────────────────────────────────
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
        emit(TransactionSuccess(data['message'] ?? 'Transfer successful'));
      } else {
        emit(TransactionError(data['error'] ?? 'Transfer failed'));
      }
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── External bank transfer ──────────────────────────────────────────────────
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
        emit(TransactionSuccess(
            'KES ${event.amount.toStringAsFixed(2)} bank transfer initiated.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Transfer failed'));
      }
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
