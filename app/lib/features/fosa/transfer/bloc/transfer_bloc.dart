import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/constants/supabase_constants.dart';

part 'transfer_event.dart';
part 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  TransferBloc() : super(TransferInitial()) {
    on<InternalTransferInitiated>(_onInternalTransfer);
    on<ExternalTransferInitiated>(_onExternalTransfer);
  }

  Future<Map<String, dynamic>> _invoke(String fn, Map<String, dynamic> body) async {
    var session = _supabase.auth.currentSession;
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session != null) session = refreshed.session!;
    } catch (e) {
      debugPrint('[TRANSFER] refresh failed: $e');
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

  Future<void> _onInternalTransfer(InternalTransferInitiated event, Emitter<TransferState> emit) async {
    emit(TransferLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke('transfer', {
            'type': 'internal',
            'to_member_number': event.toMemberNumber,
            'amount': event.amount,
            'note': event.note,
          }));
      if (data['success'] == true) {
        emit(TransferSuccess('Transfer to ${event.toMemberNumber} successful.'));
      } else {
        emit(TransferError(data['error'] ?? 'Internal transfer failed.'));
      }
    } catch (e) {
      emit(TransferError(e.toString()));
    }
  }

  Future<void> _onExternalTransfer(ExternalTransferInitiated event, Emitter<TransferState> emit) async {
    emit(TransferLoading());
    try {
      final data = await ConnectivityService.instance.guard(() => _invoke('transfer', {
            'type': 'external',
            'bank_code': event.bankCode,
            'account_number': event.accountNumber,
            'account_name': event.accountName,
            'amount': event.amount,
          }));
      if (data['success'] == true) {
        emit(TransferSuccess('Bank transfer initiated successfully.'));
      } else {
        emit(TransferError(data['error'] ?? 'External transfer failed.'));
      }
    } catch (e) {
      emit(TransferError(e.toString()));
    }
  }
}
