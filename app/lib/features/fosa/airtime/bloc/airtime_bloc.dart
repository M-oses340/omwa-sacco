import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/constants/supabase_constants.dart';

part 'airtime_event.dart';
part 'airtime_state.dart';

class AirtimeBloc extends Bloc<AirtimeEvent, AirtimeState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  AirtimeBloc() : super(AirtimeInitial()) {
    on<AirtimePurchased>(_onPurchased);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session != null) session = refreshed.session!;
    } catch (e) {
      debugPrint('[AIRTIME] refresh failed: $e');
      session = _supabase.auth.currentSession ?? session;
    }

    if (session == null) {
      return {'success': false, 'error': 'Session expired. Please log in again.'};
    }

    final token = session.accessToken;
    final url   = Uri.parse('${SupabaseConstants.url}/functions/v1/airtime');

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

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        debugPrint('[AIRTIME] non-JSON response: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
        return {'success': false, 'error': 'Server error (${res.statusCode}). Please try again.'};
      }

      final data = jsonDecode(res.body);
      debugPrint('[AIRTIME] status=${res.statusCode} body=${res.body.substring(0, res.body.length.clamp(0, 120))}');

      if (res.statusCode != 200) {
        return {'success': false, 'error': data['error'] ?? 'Error: ${res.statusCode}'};
      }
      return data as Map<String, dynamic>;
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out. Please check your connection.'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error. Please try again.'};
    }
  }

  Future<void> _onPurchased(AirtimePurchased event, Emitter<AirtimeState> emit) async {
    emit(AirtimeLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke({
        'phone_number': event.phoneNumber,
        'network':      event.network,
        'amount':       event.amount,
      }));
      if (data['success'] == true) {
        emit(AirtimeSuccess(data['message'] ?? '${event.network} airtime purchased successfully'));
      } else {
        emit(AirtimeError(data['error'] ?? 'Airtime purchase failed'));
      }
    } catch (e) {
      emit(AirtimeError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
