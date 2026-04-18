import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/constants/supabase_constants.dart';

part 'deposit_event.dart';
part 'deposit_state.dart';

class DepositBloc extends Bloc<DepositEvent, DepositState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DepositBloc() : super(DepositInitial()) {
    on<DepositInitiated>(_onDepositInitiated);
    on<CardDepositInitiated>(_onCardDepositInitiated);
    on<CheckoutCompleted>(_onCheckoutCompleted);
  }

  Future<Map<String, dynamic>> _invoke(String fn, Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;
    debugPrint('[DEPOSIT] _invoke fn=$fn body=${jsonEncode(body)}');
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session != null) session = refreshed.session!;
      debugPrint('[DEPOSIT] session refreshed, user=${session?.user.id}');
    } catch (e) {
      debugPrint('[DEPOSIT] refresh failed: $e');
      session = _supabase.auth.currentSession ?? session;
    }
    if (session == null) {
      debugPrint('[DEPOSIT] no session — aborting');
      return {'success': false, 'error': 'Session expired. Please log in again.'};
    }

    final token = session.accessToken;
    final url = Uri.parse('${SupabaseConstants.url}/functions/v1/$fn');
    debugPrint('[DEPOSIT] POST $url');
    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConstants.anonKey,
        },
        body: jsonEncode({...body, 'jwt': token}),
      ).timeout(const Duration(seconds: 60));

      debugPrint('[DEPOSIT] response status=${res.statusCode} body=${res.body}');
      if (res.body.isEmpty) return {'success': false, 'error': 'Empty response from server.'};
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        debugPrint('[DEPOSIT] error response: ${data['error'] ?? data['detail']}');
        return {'success': false, 'error': data['error'] ?? data['detail'] ?? 'Error: ${res.statusCode}'};
      }
      return data as Map<String, dynamic>;
    } on TimeoutException {
      debugPrint('[DEPOSIT] request timed out');
      return {'success': false, 'error': 'Request timed out. Please check your connection.'};
    } catch (e) {
      debugPrint('[DEPOSIT] exception: $e');
      return {'success': false, 'error': 'Connection error. Please try again.'};
    }
  }

  Future<void> _onDepositInitiated(DepositInitiated event, Emitter<DepositState> emit) async {
    debugPrint('[DEPOSIT] _onDepositInitiated amount=${event.amount}');
    emit(DepositLoading());
    try {
      final data = await ConnectivityService.instance.guard(
          () => _invoke('fosa', {'action': 'deposit_mpesa', 'amount': event.amount}));
      debugPrint('[DEPOSIT] deposit_mpesa result: $data');
      if (data['success'] == true) {
        emit(DepositSuccess(data['message'] ?? 'M-Pesa STK prompt sent.'));
      } else {
        emit(DepositError(data['error'] ?? 'M-Pesa initiation failed.'));
      }
    } catch (e) {
      debugPrint('[DEPOSIT] _onDepositInitiated exception: $e');
      emit(DepositError(e.toString()));
    }
  }

  Future<void> _onCardDepositInitiated(CardDepositInitiated event, Emitter<DepositState> emit) async {
    emit(DepositLoading());
    try {
      final data = await ConnectivityService.instance.guard(
          () => _invoke('fosa', {'action': 'deposit_card', 'amount': event.amount}));
      if (data['success'] == true) {
        emit(DepositCheckoutReady(
          checkoutUrl: data['checkout_url'],
          transactionId: data['transaction_id'],
          amount: event.amount,
        ));
      } else {
        emit(DepositError(data['error'] ?? 'Checkout initialization failed.'));
      }
    } catch (e) {
      emit(DepositError(e.toString()));
    }
  }

  Future<void> _onCheckoutCompleted(CheckoutCompleted event, Emitter<DepositState> emit) async {
    if (event.success) {
      emit(DepositSuccess('Payment received! Updating your balance shortly.'));
    } else {
      emit(DepositError('Payment was cancelled or failed.'));
      try {
        await _supabase.from('transactions').update({'status': 'cancelled'}).eq('id', event.transactionId);
      } catch (_) {}
    }
  }
}
