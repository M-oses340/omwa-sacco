import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';
import '../models/loan_model.dart';

part 'loan_event.dart';
part 'loan_state.dart';

class LoanBloc extends Bloc<LoanEvent, LoanState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  LoanBloc() : super(LoanInitial()) {
    on<LoanHistoryRequested>(_onHistoryRequested);
    on<LoanApplicationSubmitted>(_onApplicationSubmitted);
    on<LoanCancellationRequested>(_onCancellationRequested);
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

      debugPrint('[LOAN] Loaded ${loans.length} loan(s), '
          'BOSA savings: $bosaSavings, FOSA balance: $fosaBalance');

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
      final session = _supabase.auth.currentSession;
      if (session == null) {
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
      debugPrint('[LOAN] Submitting application: $payload');

      final response = await ConnectivityService.instance.guard(() =>
          _supabase.functions.invoke(
            'process-loan',
            body: payload,
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          ));

      debugPrint('[LOAN] Response status: ${response.status}');
      debugPrint('[LOAN] Response data: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final loan = LoanModel.fromMap(data['loan'] as Map<String, dynamic>);
        debugPrint('[LOAN] Application success — loan #${loan.loanNumber}');
        emit(LoanApplicationSuccess(loan));
      } else {
        debugPrint('[LOAN] Application rejected: ${data['error']}');
        emit(LoanError(data['error'] ?? 'Failed to submit application'));
      }
    } on FunctionException catch (e) {
      debugPrint('[LOAN] FunctionException status: ${e.status}');
      debugPrint('[LOAN] FunctionException details: ${e.details}');
      emit(LoanError('Service error. Please try again.'));
    } catch (e) {
      debugPrint('[LOAN] Unexpected error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCancellationRequested(
      LoanCancellationRequested event, Emitter<LoanState> emit) async {
    emit(LoanLoading());
    try {
      debugPrint('[LOAN] Cancelling loan: ${event.loanId}');
      await ConnectivityService.instance.guard(() => _supabase
          .from('loans')
          .update({'status': 'rejected', 'rejected_reason': 'Cancelled by member'})
          .eq('id', event.loanId)
          .eq('member_id', event.memberId)
          .eq('status', 'pending')); // only pending loans can be cancelled

      debugPrint('[LOAN] Loan cancelled');
      emit(LoanCancelSuccess());
    } catch (e) {
      debugPrint('[LOAN] Cancel error: $e');
      emit(LoanError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
