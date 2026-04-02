import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';
import '../models/loan_model.dart';
import '../models/amortization_entry.dart';

part 'loan_event.dart';
part 'loan_state.dart';

class LoanBloc extends Bloc<LoanEvent, LoanState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  LoanBloc() : super(LoanInitial()) {
    on<LoanHistoryRequested>(_onHistoryRequested);
    on<LoanApplicationSubmitted>(_onApplicationSubmitted);
    on<LoanCancellationRequested>(_onCancellationRequested);
    on<LoanScheduleRequested>(_onScheduleRequested);
    on<LoanRepaymentSubmitted>(_onRepaymentSubmitted);
  }

  /// Returns a valid access token, refreshing if expiring within 5 minutes.
  Future<String?> _freshToken() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = session.expiresAt ?? 0;

    // Refresh if expired or expiring within 5 minutes
    if (expiresAt - now < 300) {
      debugPrint('[AUTH] Token expires in ${expiresAt - now}s, refreshing...');
      try {
        final refreshed = await _supabase.auth.refreshSession();
        if (refreshed.session != null) {
          debugPrint('[AUTH] Refresh OK, new expiry: ${refreshed.session!.expiresAt}');
          return refreshed.session!.accessToken;
        }
      } catch (e) {
        debugPrint('[AUTH] Refresh failed: $e');
        // If refresh fails and token is truly expired, return null
        if (expiresAt < now) return null;
      }
    }
    return session.accessToken;
  }

  Future<void> _onHistoryRequested(
      LoanHistoryRequested event, Emitter<LoanState> emit) async {
    emit(LoanLoading());
    try {
      debugPrint('[LOAN] Fetching history for member: ${event.memberId}');
      final results = await ConnectivityService.instance.guard(() =>
          Future.wait([
            _supabase
                .from('loans')
                .select()
                .eq('member_id', event.memberId)
                .order('created_at', ascending: false),
            _supabase
                .from('bosa_accounts')
                .select('savings_balance')
                .eq('member_id', event.memberId)
                .maybeSingle(),
            _supabase
                .from('fosa_accounts')
                .select('balance')
                .eq('member_id', event.memberId)
                .maybeSingle(),
          ]));

      final loans = (results[0] as List)
          .map((e) => LoanModel.fromMap(e as Map<String, dynamic>))
          .toList();
      final bosa = results[1] as Map<String, dynamic>?;
      final fosa = results[2] as Map<String, dynamic>?;
      final bosaSavings =
          double.tryParse(bosa?['savings_balance']?.toString() ?? '0') ?? 0;
      final fosaBalance =
          double.tryParse(fosa?['balance']?.toString() ?? '0') ?? 0;

      debugPrint('[LOAN] Loaded ${loans.length} loan(s)');
      emit(LoanHistoryLoaded(loans,
          bosaSavings: bosaSavings, fosaBalance: fosaBalance));
    } catch (e) {
      debugPrint('[LOAN] History error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onApplicationSubmitted(
      LoanApplicationSubmitted event, Emitter<LoanState> emit) async {
    emit(LoanLoading());
    try {
      final token = await _freshToken();
      if (token == null) {
        emit(LoanError('Session expired. Please log in again.'));
        return;
      }

      final payload = {
        'action': 'apply',
        'loan_type': event.loanType,
        'principal': event.principal,
        'duration_months': event.durationMonths,
        'purpose': event.purpose,
      };
      debugPrint('[LOAN] Submitting: $payload');

      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'process-loan',
            body: payload,
            headers: {'Authorization': 'Bearer $token'},
          ));

      debugPrint('[LOAN] Response: ${response.data}');
      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final loan = LoanModel.fromMap(data['loan'] as Map<String, dynamic>);
        final schedule = (data['schedule'] as List? ?? [])
            .map((e) => AmortizationEntry.fromMap(e as Map<String, dynamic>))
            .toList();
        debugPrint('[LOAN] Success — ${loan.loanNumber}, ${schedule.length} schedule entries');
        emit(LoanApplicationSuccess(loan, schedule: schedule));
      } else {
        debugPrint('[LOAN] Rejected: ${data['error']}');
        emit(LoanError(data['error'] ?? 'Failed to submit application'));
      }
    } on FunctionException catch (e) {
      debugPrint('[LOAN] FunctionException: ${e.status} ${e.details}');
      emit(LoanError('Service error. Please try again.'));
    } catch (e) {
      debugPrint('[LOAN] Error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCancellationRequested(
      LoanCancellationRequested event, Emitter<LoanState> emit) async {
    emit(LoanLoading());
    try {
      debugPrint('[LOAN] Cancelling: ${event.loanId}');
      await ConnectivityService.instance.guard(() => _supabase
          .from('loans')
          .update({
            'status': 'rejected',
            'rejected_reason': 'Cancelled by member'
          })
          .eq('id', event.loanId)
          .eq('member_id', event.memberId)
          .eq('status', 'pending'));
      emit(LoanCancelSuccess());
    } catch (e) {
      debugPrint('[LOAN] Cancel error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onScheduleRequested(
      LoanScheduleRequested event, Emitter<LoanState> emit) async {
    emit(LoanLoading());
    try {
      final token = await _freshToken();
      if (token == null) { emit(LoanError('Session expired.')); return; }
      debugPrint('[LOAN] Fetching schedule for: ${event.loanId}');
      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'process-loan',
            body: {'action': 'schedule', 'loan_id': event.loanId},
            headers: {'Authorization': 'Bearer $token'},
          ));

      final data = response.data as Map<String, dynamic>;
      final schedule = (data['schedule'] as List? ?? [])
          .map((e) => AmortizationEntry.fromMap(e as Map<String, dynamic>))
          .toList();
      debugPrint('[LOAN] Schedule loaded: ${schedule.length} entries');
      emit(LoanScheduleLoaded(schedule));
    } on FunctionException catch (e) {
      debugPrint('[LOAN] Schedule FunctionException: ${e.details}');
      emit(LoanError('Could not load schedule.'));
    } catch (e) {
      debugPrint('[LOAN] Schedule error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRepaymentSubmitted(
      LoanRepaymentSubmitted event, Emitter<LoanState> emit) async {
    emit(LoanLoading());
    try {
      final token = await _freshToken();
      if (token == null) { emit(LoanError('Session expired.')); return; }

      debugPrint('[LOAN] Repaying ${event.amount} on loan ${event.loanId}');
      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'process-loan',
            body: {'action': 'repay', 'loan_id': event.loanId, 'amount': event.amount},
            headers: {'Authorization': 'Bearer $token'},
          ));

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        debugPrint('[LOAN] Repayment success, balance: ${data['balance_after']}');
        emit(LoanRepaymentSuccess(
          amountPaid: (data['amount_paid'] as num).toDouble(),
          balanceAfter: (data['balance_after'] as num).toDouble(),
        ));
      } else {
        emit(LoanError(data['error'] ?? 'Repayment failed'));
      }
    } on FunctionException catch (e) {
      debugPrint('[LOAN] Repayment FunctionException: ${e.details}');
      emit(LoanError('Service error. Please try again.'));
    } catch (e) {
      debugPrint('[LOAN] Repayment error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
