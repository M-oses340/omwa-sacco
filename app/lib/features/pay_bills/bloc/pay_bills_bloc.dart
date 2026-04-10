import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/constants/supabase_constants.dart';

part 'pay_bills_event.dart';
part 'pay_bills_state.dart';

class PayBillsBloc extends Bloc<PayBillsEvent, PayBillsState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  PayBillsBloc() : super(PayBillsInitial()) {
    on<PayBillSubmitted>(_onPayBill);
    on<TillPaymentSubmitted>(_onTill);
  }

  /// Calls the pay-bills edge function — mirrors TransactionBloc._invoke
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session != null) session = refreshed.session!;
    } catch (e) {
      debugPrint('[PAY_BILLS] refresh failed: $e');
      session = _supabase.auth.currentSession ?? session;
    }

    if (session == null) {
      return {'success': false, 'error': 'Session expired. Please log in again.'};
    }

    final token = session.accessToken;
    final url   = Uri.parse('${SupabaseConstants.url}/functions/v1/pay-bills');

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
          'apikey':        SupabaseConstants.anonKey,
        },
        body: jsonEncode({...body, 'jwt': token}),
      ).timeout(const Duration(seconds: 60));

      if (res.body.isEmpty) return {'success': false, 'error': 'Empty response from server.'};

      // Guard against non-JSON responses (e.g. HTML error pages)
      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        debugPrint('[PAY_BILLS] non-JSON response: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
        return {'success': false, 'error': 'Server error (${res.statusCode}). Please try again.'};
      }

      final data = jsonDecode(res.body);
      debugPrint('[PAY_BILLS] status=${res.statusCode} body=${res.body.substring(0, res.body.length.clamp(0, 120))}');

      if (res.statusCode != 200) {
        return {'success': false, 'error': data['error'] ?? data['detail'] ?? 'Error: ${res.statusCode}'};
      }
      return data as Map<String, dynamic>;
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out. Please check your connection.'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error. Please try again.'};
    }
  }

  Future<void> _onPayBill(PayBillSubmitted event, Emitter<PayBillsState> emit) async {
    emit(PayBillsLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke({
        'action':          'paybill',
        'amount':          event.amount,
        'business_number': event.businessNumber,
        'account_number':  event.accountNumber,
      }));
      if (data['success'] == true) {
        emit(PayBillsSuccess(data['message'] ?? 'Paybill payment successful'));
      } else {
        emit(PayBillsError(data['error'] ?? 'Paybill payment failed'));
      }
    } catch (e) {
      emit(PayBillsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onTill(TillPaymentSubmitted event, Emitter<PayBillsState> emit) async {
    emit(PayBillsLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke({
        'action':      'till',
        'amount':      event.amount,
        'till_number': event.tillNumber,
      }));
      if (data['success'] == true) {
        emit(PayBillsSuccess(data['message'] ?? 'Till payment successful'));
      } else {
        emit(PayBillsError(data['error'] ?? 'Till payment failed'));
      }
    } catch (e) {
      emit(PayBillsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
