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
    on<CardDepositInitiated>(_onCardDepositInitiated);
    on<CheckoutCompleted>(_onCheckoutCompleted);
    on<WithdrawInitiated>(_onWithdrawInitiated);
    on<InternalTransferInitiated>(_onInternalTransfer);
    on<ExternalTransferInitiated>(_onExternalTransfer);
  }

  Future<String?> _freshToken() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = session.expiresAt ?? 0;
    if (expiresAt - now < 300) {
      try {
        final r = await _supabase.auth.refreshSession();
        if (r.session != null) return r.session!.accessToken;
      } catch (_) {}
    }
    return session.accessToken;
  }

  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ6a3VkbWZ1dXRzenNwemZoem5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0Mzg2NjcsImV4cCI6MjA5MDAxNDY2N30.4ur7dJ_jeVDxg2Xta2YJsJmeI0vux8CYFsEO-hsL1Q8';

  // Workaround: ES256 JWTs crash eu-central-2 edge runtime as Authorization header.
  // Send anon key as Authorization + user JWT in body.jwt.
  Future<FunctionResponse> _invoke(String fn, Map<String, dynamic> body) async {
    final token = await _freshToken();
    final payload = token != null ? {...body, 'jwt': token} : body;
    return await _supabase.functions.invoke(
      fn,
      body: payload,
      headers: {'Authorization': 'Bearer $_anonKey'},
    );
  }

  // ── M-Pesa STK deposit ──────────────────────────────────────────────────────
  Future<void> _onDepositInitiated(
      DepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      debugPrint('[TRANSACTION] M-Pesa deposit KES ${event.amount}');
      final response = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'deposit_mpesa', 'amount': event.amount}));

      final data = response.data as Map<String, dynamic>;
      debugPrint('[TRANSACTION] Response: $data');

      if (data['success'] == true) {
        emit(TransactionSuccess(data['message'] ?? 'M-Pesa prompt sent.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Deposit failed'));
      }
    } on FunctionException catch (e) {
      debugPrint('[TRANSACTION] FunctionException: ${e.status} ${e.details}');
      final msg = (e.details is Map) ? (e.details as Map)['error']?.toString() ?? 'Service error' : 'Service error';
      emit(TransactionError(msg));
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Card / Bank checkout deposit ────────────────────────────────────────────
  Future<void> _onCardDepositInitiated(
      CardDepositInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      debugPrint('[TRANSACTION] Card deposit KES ${event.amount}');
      final response = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'deposit_card', 'amount': event.amount}));

      final data = response.data as Map<String, dynamic>;
      debugPrint('[TRANSACTION] Card response: $data');

      if (data['success'] == true) {
        emit(TransactionCheckoutReady(
          checkoutUrl: data['checkout_url'],
          transactionId: data['transaction_id'],
          amount: event.amount,
        ));
      } else {
        emit(TransactionError(data['error'] ?? 'Checkout failed'));
      }
    } on FunctionException catch (e) {
      debugPrint('[TRANSACTION] Card FunctionException: ${e.status} ${e.details}');
      final msg = (e.details is Map) ? (e.details as Map)['error']?.toString() ?? 'Service error' : 'Service error';
      emit(TransactionError(msg));
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
          .from('transactions').select('status, amount').eq('id', event.transactionId).single();
      final amount = double.tryParse(tx['amount'].toString()) ?? 0;
      if (event.success) {
        emit(TransactionSuccess('Deposit of KES ${amount.toStringAsFixed(2)} is being processed'));
      } else {
        await _supabase.from('transactions').update({'status': 'failed'}).eq('id', event.transactionId);
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
      debugPrint('[WITHDRAW] KES ${event.amount}');
      final fosa = await ConnectivityService.instance.guard(() => _supabase
          .from('fosa_accounts').select('balance').eq('member_id', event.memberId).single());
      final balance = double.tryParse(fosa['balance'].toString()) ?? 0;
      if (event.amount > balance) {
        emit(TransactionError('Insufficient balance. Available: KES ${balance.toStringAsFixed(2)}'));
        return;
      }

      final response = await ConnectivityService.instance.guard(() =>
          _invoke('fosa', {'action': 'withdraw', 'amount': event.amount}));

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        emit(TransactionSuccess('Withdrawal of KES ${event.amount.toStringAsFixed(2)} is being processed.'));
      } else {
        emit(TransactionError(data['error'] ?? 'Withdrawal failed'));
      }
    } on FunctionException catch (e) {
      emit(TransactionError('Service error: ${e.details}'));
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Internal transfer ───────────────────────────────────────────────────────
  Future<void> _onInternalTransfer(
      InternalTransferInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final response = await ConnectivityService.instance.guard(() =>
          _invoke('transfer', {
            'type': 'internal',
            'to_member_number': event.toMemberNumber,
            'amount': event.amount,
            'note': event.note,
          }));
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        emit(TransactionSuccess(data['message'] ?? 'Transfer successful'));
      } else {
        emit(TransactionError(data['error'] ?? 'Transfer failed'));
      }
    } on FunctionException catch (e) {
      emit(TransactionError('Service error: ${e.details}'));
    } catch (e) {
      emit(TransactionError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── External bank transfer ──────────────────────────────────────────────────
  Future<void> _onExternalTransfer(
      ExternalTransferInitiated event, Emitter<TransactionState> emit) async {
    emit(TransactionLoading());
    try {
      final response = await ConnectivityService.instance.guard(() =>
          _invoke('transfer', {
            'type': 'external',
            'bank_code': event.bankCode,
            'account_number': event.accountNumber,
            'account_name': event.accountName,
            'amount': event.amount,
          }));
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        emit(TransactionSuccess('KES ${event.amount.toStringAsFixed(2)} bank transfer initiated.'));
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
