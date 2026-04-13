import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/connectivity_service.dart';

part 'reports_event.dart';
part 'reports_state.dart';

const _adminRoles = ['admin', 'treasurer', 'chairman'];
const _pageSize = 50;

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final SupabaseClient _db = Supabase.instance.client;

  ReportsBloc() : super(ReportsInitial()) {
    on<ReportsLoaded>(_onLoaded);
    on<ReportViewRequested>(_onViewRequested);
    on<ReportsFilterChanged>(_onFilterChanged);
    on<ReportsDateRangeCleared>(_onDateRangeCleared);
    on<ReportsSearchChanged>(_onSearchChanged);
    on<ReportsLoadMoreRequested>(_onLoadMore);
    on<ReportsDatePresetApplied>(_onPresetApplied);
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
      final all = await _fetchReport(event.reportId, event.memberId, event.params);
      final page = all.take(_pageSize).toList();
      emit(ReportViewData(
        reportId: event.reportId,
        allRows: all,
        rows: page,
        selectedType: 'all',
        hasMore: all.length > _pageSize,
      ));
    } catch (e) {
      emit(ReportsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReport(
    String reportId,
    String memberId,
    Map<String, dynamic>? params,
  ) async {
    return ConnectivityService.instance.guard(() async {
      // Use same session-refresh pattern as other blocs
      var session = _db.auth.currentSession;
      try {
        final refreshed = await _db.auth.refreshSession();
        if (refreshed.session != null) session = refreshed.session!;
      } catch (e) {
        debugPrint('[REPORTS] refresh failed: $e');
        session = _db.auth.currentSession ?? session;
      }

      if (session == null) throw Exception('Session expired. Please log in again.');

      final token = session.accessToken;
      final url = Uri.parse('${SupabaseConstants.url}/functions/v1/reports');

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseConstants.anonKey,
        },
        body: jsonEncode({
          'report': reportId,
          'member_id': memberId,
          'params': params ?? {},
          'jwt': token,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to load report');
      }
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    });
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  void _onFilterChanged(ReportsFilterChanged event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData) return;
    final newType = event.type ?? current.selectedType;
    final newRange = event.dateRange ?? current.dateRange;
    final newSearch = event.search ?? current.searchQuery;
    final filtered = _applyFilters(current.allRows, newType, newRange, newSearch);
    emit(current.copyWith(
      selectedType: newType,
      dateRange: newRange,
      searchQuery: newSearch,
      rows: filtered.take(_pageSize).toList(),
      page: 0,
      hasMore: filtered.length > _pageSize,
    ));
  }

  void _onDateRangeCleared(ReportsDateRangeCleared event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData) return;
    final filtered = _applyFilters(current.allRows, current.selectedType, null, current.searchQuery);
    emit(current.copyWith(
      clearDateRange: true,
      rows: filtered.take(_pageSize).toList(),
      page: 0,
      hasMore: filtered.length > _pageSize,
    ));
  }

  void _onSearchChanged(ReportsSearchChanged event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData) return;
    final filtered = _applyFilters(current.allRows, current.selectedType, current.dateRange, event.query);
    emit(current.copyWith(
      searchQuery: event.query,
      rows: filtered.take(_pageSize).toList(),
      page: 0,
      hasMore: filtered.length > _pageSize,
    ));
  }

  void _onLoadMore(ReportsLoadMoreRequested event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData || !current.hasMore) return;
    final filtered = _applyFilters(current.allRows, current.selectedType, current.dateRange, current.searchQuery);
    final nextPage = current.page + 1;
    final end = (nextPage + 1) * _pageSize;
    emit(current.copyWith(
      rows: filtered.take(end).toList(),
      page: nextPage,
      hasMore: filtered.length > end,
    ));
  }

  void _onPresetApplied(ReportsDatePresetApplied event, Emitter<ReportsState> emit) {
    final current = state;
    if (current is! ReportViewData) return;
    final range = event.preset.range;
    final filtered = _applyFilters(current.allRows, current.selectedType, range, current.searchQuery);
    emit(current.copyWith(
      dateRange: range,
      rows: filtered.take(_pageSize).toList(),
      page: 0,
      hasMore: filtered.length > _pageSize,
    ));
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> all,
    String type,
    DateTimeRange? range,
    String search,
  ) {
    final q = search.toLowerCase().trim();
    return all.where((row) {
      final txType = row['transaction_type'] as String?;
      final typeMatch = type == 'all' || txType == null || txType == type;

      final dateStr = row['created_at'] as String? ??
          row['disbursed_at'] as String? ??
          row['due_date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
      final dateMatch = range == null ||
          (date != null && !date.isBefore(range.start) && !date.isAfter(range.end));

      final searchMatch = q.isEmpty ||
          row.values.any((v) => v?.toString().toLowerCase().contains(q) == true) ||
          _nestedSearch(row, q);

      return typeMatch && dateMatch && searchMatch;
    }).toList();
  }

  bool _nestedSearch(Map<String, dynamic> row, String q) {
    for (final v in row.values) {
      if (v is Map) {
        if (v.values.any((nv) => nv?.toString().toLowerCase().contains(q) == true)) {
          return true;
        }
      }
    }
    return false;
  }
}
