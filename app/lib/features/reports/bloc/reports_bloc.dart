import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

part 'reports_event.dart';
part 'reports_state.dart';

const _adminRoles = ['admin', 'treasurer', 'chairman'];

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final SupabaseClient _db = Supabase.instance.client;

  ReportsBloc() : super(ReportsInitial()) {
    on<ReportsLoaded>(_onLoaded);
    on<ReportViewRequested>(_onViewRequested);
    on<ReportsFilterChanged>(_onFilterChanged);
    on<ReportsDateRangeCleared>(_onDateRangeCleared);
  }

  // ── Hub ───────────────────────────────────────────────────────────────────

  Future<void> _onLoaded(ReportsLoaded event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final results = await ConnectivityService.instance.guard(() => Future.wait([
            _db.from('bosa_accounts').select().eq('member_id', event.memberId).maybeSingle(),
            _db.from('fosa_accounts').select().eq('member_id', event.memberId).maybeSingle(),
            _db.from('transactions').select().eq('member_id', event.memberId).order('created_at', ascending: false).limit(5),
            _db.from('members').select('role').eq('id', event.memberId).maybeSingle(),
          ]));

      final member = results[3] as Map<String, dynamic>?;
      final role = member?['role'] as String? ?? '';

      emit(ReportsHubData(
        bosa: results[0] as Map<String, dynamic>?,
        fosa: results[1] as Map<String, dynamic>?,
        recentTransactions: (results[2] as List).cast<Map<String, dynamic>>(),
        isAdmin: _adminRoles.contains(role),
      ));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Report viewer ─────────────────────────────────────────────────────────

  Future<void> _onViewRequested(ReportViewRequested event, Emitter<ReportsState> emit) async {
    emit(ReportsLoading());
    try {
      final rows = await _fetchReport(event.reportId, event.memberId);
      emit(ReportViewData(
        reportId: event.reportId,
        rows: rows,
        allRows: rows,
        selectedType: 'all',
      ));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReport(String reportId, String memberId) async {
    return ConnectivityService.instance.guard(() async {
      switch (reportId) {
        case 'my_transactions':
        case 'member_statement':
          return (await _db.from('transactions').select().eq('member_id', memberId).order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'my_savings':
          final results = await Future.wait([
            _db.from('bosa_accounts').select().eq('member_id', memberId).maybeSingle(),
            _db.from('fosa_accounts').select().eq('member_id', memberId).maybeSingle(),
          ]);
          final rows = <Map<String, dynamic>>[];
          if (results[0] != null) {
            final b = results[0] as Map<String, dynamic>;
            rows.add({'account': 'BOSA Savings', 'balance': b['savings_balance'], 'status': b['status']});
            rows.add({'account': 'BOSA Shares', 'balance': b['shares_balance'], 'status': b['status']});
          }
          if (results[1] != null) {
            final f = results[1] as Map<String, dynamic>;
            rows.add({'account': 'FOSA', 'balance': f['balance'], 'status': f['status']});
          }
          return rows;

        case 'loan_repayments':
          return (await _db.from('loan_repayments').select('*, loans(loan_type, principal_amount)').eq('member_id', memberId).order('due_date', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'member_register':
          return (await _db.from('members').select('member_number, full_name, phone_number, status, bosa_accounts(savings_balance, shares_balance), fosa_accounts(balance)').order('member_number'))
              .cast<Map<String, dynamic>>();

        case 'new_members':
          return (await _db.from('members').select('member_number, full_name, phone_number, created_at, status').order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'dormant_members':
          final cutoff = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
          return (await _db.from('members').select('member_number, full_name, bosa_accounts(savings_balance), fosa_accounts(balance)').lt('last_activity_at', cutoff))
              .cast<Map<String, dynamic>>();

        case 'savings_summary':
          return (await _db.from('bosa_accounts').select('members(member_number, full_name), savings_balance, shares_balance, status').order('savings_balance', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'deposit_collection':
          return (await _db.from('transactions').select('created_at, members(full_name, member_number), amount, payment_method, status').eq('transaction_type', 'deposit').order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'fosa_balances':
          return (await _db.from('fosa_accounts').select('account_number, members(full_name, member_number), balance, status').order('balance', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'loan_book':
          return (await _db.from('loans').select('members(full_name, member_number), loan_type, principal_amount, outstanding_balance, due_date, status').inFilter('status', ['disbursed', 'active']).order('outstanding_balance', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'loan_disbursements':
          return (await _db.from('loans').select('disbursed_at, members(full_name, member_number), loan_type, principal_amount, status').eq('status', 'disbursed').order('disbursed_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'arrears':
          return (await _db.from('loans').select('members(full_name, member_number), loan_type, outstanding_balance, due_date, status').eq('status', 'defaulted').order('due_date'))
              .cast<Map<String, dynamic>>();

        case 'npl':
          return (await _db.from('loans').select('members(full_name, member_number), loan_type, principal_amount, outstanding_balance, due_date').eq('status', 'defaulted'))
              .cast<Map<String, dynamic>>();

        case 'withdrawal_report':
          return (await _db.from('transactions').select('created_at, members(full_name, member_number), amount, payment_method, status').inFilter('transaction_type', ['withdrawal', 'fosa_withdrawal']).order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'daily_summary':
          return (await _db.from('transactions').select('created_at, transaction_type, amount, status').order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'mpesa_reconciliation':
          return (await _db.from('transactions').select('created_at, reference, members(full_name), amount, status').eq('payment_method', 'mpesa').order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'share_capital':
          return (await _db.from('bosa_accounts').select('members(member_number, full_name), shares_balance, status').order('shares_balance', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'dividend_report':
          return (await _db.from('transactions').select('created_at, members(member_number, full_name), amount').eq('transaction_type', 'dividend').order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'pending_approvals':
          return (await _db.from('loans').select('loan_type, members(full_name, member_number), principal_amount, created_at, status').eq('status', 'pending').order('created_at', ascending: false))
              .cast<Map<String, dynamic>>();

        case 'audit_trail':
          return (await _db.from('audit_logs').select().order('created_at', ascending: false).limit(200))
              .cast<Map<String, dynamic>>();

        default:
          return [];
      }
    });
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  void _onFilterChanged(ReportsFilterChanged event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData) return;
    final newType = event.type ?? current.selectedType;
    final newRange = event.dateRange ?? current.dateRange;
    emit(current.copyWith(
      selectedType: newType,
      dateRange: newRange,
      rows: _applyFilter(current.allRows, newType, newRange),
    ));
  }

  void _onDateRangeCleared(ReportsDateRangeCleared event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData) return;
    emit(current.copyWith(
      clearDateRange: true,
      rows: _applyFilter(current.allRows, current.selectedType, null),
    ));
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> all,
    String type,
    DateTimeRange? range,
  ) {
    return all.where((row) {
      final txType = row['transaction_type'] as String?;
      final typeMatch = type == 'all' || txType == null || txType == type;
      final dateStr = row['created_at'] as String? ?? row['disbursed_at'] as String? ?? row['due_date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
      final dateMatch = range == null || (date != null && !date.isBefore(range.start) && !date.isAfter(range.end));
      return typeMatch && dateMatch;
    }).toList();
  }
}
