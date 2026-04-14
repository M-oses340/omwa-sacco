import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/constants/supabase_constants.dart';

part 'withdraw_event.dart';
part 'withdraw_state.dart';

class WithdrawBloc extends Bloc<WithdrawEvent, WithdrawState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  WithdrawBloc() : super(WithdrawInitial()) {
    on<WithdrawInitiated>(_onWithdrawInitiated);
  }

  Future<Map<String, dynamic>> _invoke(String fn, Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session != null) session = refreshed.session!;
    } catch (e) {
      debugPrint('[WITHDRAW] refresh failed: $e');
      session = _supabase.auth.currentSession ?? session;
    }
    if (session == null) return {'success': false, 'error': 'Session expired. Please log in again.'};

    final token = session.accessToken;
    final url = Uri.parse('${SupabaseConstants.url}/functions/v1/$fn');
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

      if (res.body.isEmpty) return {'success': false, 'error': 'Empty response from server.'};
      final data = jsonDecode(res.body);
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

  Future<void> _onWithdrawInitiated(WithdrawInitiated event, Emitter<WithdrawState> emit) async {
    emit(WithdrawLoading());
    try {
      final data = await ConnectivityService.instance.guard(
          () => _invoke('fosa', {'action': 'withdraw', 'amount': event.amount}));
      if (data['success'] == true) {
        emit(WithdrawSuccess(data['message'] ?? 'Withdrawal of KES ${event.amount.toStringAsFixed(2)} is processing.'));
      } else {
        emit(WithdrawError(data['error'] ?? 'Withdrawal failed.'));
      }
    } catch (e) {
      emit(WithdrawError(e.toString()));
    }
  }
}
