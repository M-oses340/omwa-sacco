import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/reports_bloc.dart';
import '../models/report_definition.dart';
import '../services/report_export_service.dart';
import '../services/saved_filters_service.dart';
import '../widgets/report_chart.dart';

class ReportViewerScreen extends StatefulWidget {
  final ReportDefinition report;
  final Map<String, dynamic> member;
  const ReportViewerScreen({super.key, required this.report, required this.member});

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  late final ReportsBloc _bloc;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<SavedFilter> _savedFilters = [];

  @override
  void initState() {
    super.initState();
    _bloc = ReportsBloc()
      ..add(ReportViewRequested(
          reportId: widget.report.id, memberId: widget.member['id']));
    _loadSavedFilters();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _bloc.close();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<ReportsBloc>().add(ReportsLoadMoreRequested());
    }
  }

  Future<void> _loadSavedFilters() async {
    final filters = await SavedFiltersService.load(widget.report.id);
    if (mounted) setState(() => _savedFilters = filters);
  }

  Future<void> _saveCurrentFilter(ReportViewData state) async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Filter'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Filter name', hintText: 'e.g. Last month deposits'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;
    final filter = SavedFilter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reportId: widget.report.id,
      name: nameCtrl.text.trim(),
      type: state.selectedType == 'all' ? null : state.selectedType,
      startDate: state.dateRange?.start,
      endDate: state.dateRange?.end,
    );
    await SavedFiltersService.save(filter);
    await _loadSavedFilters();
  }

  void _applySavedFilter(SavedFilter filter) {
    if (filter.type != null) {
      _bloc.add(ReportsFilterChanged(type: filter.type));
    }
    if (filter.dateRange != null) {
      _bloc.add(ReportsFilterChanged(dateRange: filter.dateRange));
    }
  }

  Future<void> _deleteSavedFilter(String id) async {
    await SavedFiltersService.delete(id);
    await _loadSavedFilters();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.report.category.color;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            builder: (ctx, state) {
              if (state is! ReportViewData) return const SizedBox();
              return Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.bookmark_outline),
                  tooltip: 'Save filter',
                  onPressed: () => _saveCurrentFilter(state),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Export',
                  onSelected: (v) async {
                    if (v == 'pdf') {
                      await ReportExportService.exportPdf(
                        context: context,
                        report: widget.report,
                        rows: state.rows,
                        cellBuilder: (row) => _buildCells(row, widget.report.id),
                        dateRange: state.dateRange,
                      );
                    } else {
                      await ReportExportService.exportCsv(
                        report: widget.report,
                        rows: state.rows,
                        cellBuilder: (row) => _buildCells(row, widget.report.id),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18), SizedBox(width: 8), Text('Export PDF / Print')])),
                    PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart_outlined, size: 18), SizedBox(width: 8), Text('Export CSV')])),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _searchCtrl.clear();
                    ctx.read<ReportsBloc>().add(
                          ReportViewRequested(reportId: widget.report.id, memberId: widget.member['id']),
                        );
                  },
                ),
              ]);
            },
          ),
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (ctx, state) {
          if (state is ReportsLoading || state is ReportsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ReportsError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(state.message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ctx.read<ReportsBloc>().add(
                        ReportViewRequested(reportId: widget.report.id, memberId: widget.member['id']),
                      ),
                  child: const Text('Retry'),
                ),
              ]),
            );
          }
          if (state is ReportViewData && state.reportId == widget.report.id) {
            return _ViewerBody(
              report: widget.report,
              state: state,
              color: color,
              searchCtrl: _searchCtrl,
              scrollCtrl: _scrollCtrl,
              savedFilters: _savedFilters,
              onApplySavedFilter: _applySavedFilter,
              onDeleteSavedFilter: _deleteSavedFilter,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    ), // Scaffold
    ); // BlocProvider.value
  }
}

// ── Viewer body ───────────────────────────────────────────────────────────────

class _ViewerBody extends StatelessWidget {
  final ReportDefinition report;
  final ReportViewData state;
  final Color color;
  final TextEditingController searchCtrl;
  final ScrollController scrollCtrl;
  final List<SavedFilter> savedFilters;
  final void Function(SavedFilter) onApplySavedFilter;
  final void Function(String) onDeleteSavedFilter;

  const _ViewerBody({
    required this.report,
    required this.state,
    required this.color,
    required this.searchCtrl,
    required this.scrollCtrl,
    required this.savedFilters,
    required this.onApplySavedFilter,
    required this.onDeleteSavedFilter,
  });

  Future<void> _pickDateRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: state.dateRange,
    );
    if (range != null && context.mounted) {
      context.read<ReportsBloc>().add(ReportsFilterChanged(dateRange: range));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: searchCtrl,
            onChanged: (q) => context.read<ReportsBloc>().add(ReportsSearchChanged(q)),
            decoration: InputDecoration(
              hintText: 'Search ${report.title.toLowerCase()}...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        searchCtrl.clear();
                        context.read<ReportsBloc>().add(ReportsSearchChanged(''));
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // ── Date presets ────────────────────────────────────────────────────
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            children: [
              ...DatePreset.values.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 11)),
                      onPressed: () =>
                          context.read<ReportsBloc>().add(ReportsDatePresetApplied(p)),
                      backgroundColor: _isPresetActive(p)
                          ? color.withValues(alpha: 0.15)
                          : null,
                      side: _isPresetActive(p)
                          ? BorderSide(color: color)
                          : null,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  )),
              ActionChip(
                avatar: Icon(Icons.date_range, size: 14, color: state.dateRange != null ? color : null),
                label: Text('Custom', style: TextStyle(fontSize: 11, color: state.dateRange != null ? color : null)),
                onPressed: () => _pickDateRange(context),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              if (state.dateRange != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 11)),
                    onPressed: () => context.read<ReportsBloc>().add(ReportsDateRangeCleared()),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
            ],
          ),
        ),

        // ── Saved filters ───────────────────────────────────────────────────
        if (savedFilters.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              children: savedFilters
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          avatar: Icon(Icons.bookmark, size: 14, color: color),
                          label: Text(f.name, style: const TextStyle(fontSize: 11)),
                          onPressed: () => onApplySavedFilter(f),
                          onDeleted: () => onDeleteSavedFilter(f.id),
                          deleteIconColor: cs.onSurface.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── Active date range label ─────────────────────────────────────────
        if (state.dateRange != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              Icon(Icons.info_outline, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                '${_fmtDate(state.dateRange!.start)} – ${_fmtDate(state.dateRange!.end)}',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ]),
          ),

        Divider(height: 12, color: cs.outlineVariant),

        // ── KPI row ─────────────────────────────────────────────────────────
        _KpiRow(rows: state.rows, report: report, color: color),
        Divider(height: 1, color: cs.outlineVariant),

        // ── Chart + table ───────────────────────────────────────────────────
        Expanded(
          child: state.rows.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text('No data found',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                  ]),
                )
              : ListView(
                  controller: scrollCtrl,
                  children: [
                    ReportChart(report: report, rows: state.allRows, color: color),
                    const SizedBox(height: 8),
                    _ReportTable(report: report, rows: state.rows),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Scroll for more...',
                            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  bool _isPresetActive(DatePreset p) {
    if (state.dateRange == null) return false;
    final r = p.range;
    return state.dateRange!.start.day == r.start.day &&
        state.dateRange!.start.month == r.start.month &&
        state.dateRange!.start.year == r.start.year;
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── KPI summary ───────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final ReportDefinition report;
  final Color color;
  const _KpiRow({required this.rows, required this.report, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kpis = _buildKpis();
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: kpis
            .map((k) => Expanded(
                  child: Column(children: [
                    Text(k.$1,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                    Text(k.$2,
                        style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6))),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  List<(String, String)> _buildKpis() {
    if (rows.isEmpty) return [('0', 'Records')];
    switch (report.id) {
      case 'my_transactions':
      case 'member_statement':
      case 'deposit_collection':
      case 'withdrawal_report':
      case 'mpesa_reconciliation':
        double totalIn = 0, totalOut = 0;
        for (final r in rows) {
          final type = r['transaction_type'] as String? ?? '';
          final amt = double.tryParse(r['amount']?.toString() ?? '') ?? 0;
          if (['deposit', 'loan_disbursement', 'dividend'].contains(type)) {
            totalIn += amt;
          } else {
            totalOut += amt;
          }
        }
        return [
          ('KES ${_k(totalIn)}', 'Total In'),
          ('KES ${_k(totalOut)}', 'Total Out'),
          ('${rows.length}', 'Records'),
        ];
      case 'loan_book':
      case 'loan_disbursements':
      case 'arrears':
      case 'npl':
        double total = 0;
        for (final r in rows) {
          total += double.tryParse(
                  (r['outstanding_balance'] ?? r['principal_amount'])?.toString() ?? '') ??
              0;
        }
        return [('${rows.length}', 'Loans'), ('KES ${_k(total)}', 'Total Value')];
      case 'savings_summary':
      case 'fosa_balances':
        double total = 0;
        for (final r in rows) {
          total += double.tryParse(
                  (r['savings_balance'] ?? r['balance'])?.toString() ?? '') ??
              0;
        }
        return [('${rows.length}', 'Accounts'), ('KES ${_k(total)}', 'Total Balance')];
      default:
        return [('${rows.length}', 'Records')];
    }
  }

  String _k(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }
}

// ── Data table ────────────────────────────────────────────────────────────────

class _ReportTable extends StatelessWidget {
  final ReportDefinition report;
  final List<Map<String, dynamic>> rows;
  const _ReportTable({required this.report, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = report.category.color;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(color.withValues(alpha: 0.08)),
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: 20,
        columns: report.columns
            .map((c) => DataColumn(
                  label: Text(c,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ))
            .toList(),
        rows: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return DataRow(
            color: WidgetStateProperty.resolveWith((states) =>
                i.isOdd ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : null),
            cells: _buildCells(row, report.id)
                .map((c) => DataCell(
                      Text(c,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cell builder (shared with export) ────────────────────────────────────────

List<String> _buildCells(Map<String, dynamic> row, String reportId) {
  String fmt(dynamic v) =>
      'KES ${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';
  String fmtDate(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d != null ? '${d.day}/${d.month}/${d.year}' : '-';
  }
  String member(Map<String, dynamic> r) {
    final m = r['members'];
    if (m is Map) return m['full_name']?.toString() ?? '-';
    return '-';
  }
  String daysPast(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '-';
    final days = DateTime.now().difference(d).inDays;
    return days > 0 ? '$days days' : 'Current';
  }

  switch (reportId) {
    case 'my_transactions':
    case 'member_statement':
      return [
        fmtDate(row['created_at']),
        (row['transaction_type'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
        fmt(row['amount']),
        fmt(row['running_balance'] ?? row['amount']),
        (row['status'] as String? ?? '-').toUpperCase(),
      ];
    case 'my_savings':
      return [
        row['account']?.toString() ?? '-',
        fmt(row['balance']),
        (row['status'] as String? ?? '-').toUpperCase(),
      ];
    case 'member_register':
      final b = row['bosa_accounts'];
      final f = row['fosa_accounts'];
      return [
        row['member_number']?.toString() ?? '-',
        row['full_name']?.toString() ?? '-',
        row['phone_number']?.toString() ?? '-',
        (row['status'] as String? ?? '-').toUpperCase(),
        b is Map ? fmt(b['savings_balance']) : '-',
        f is Map ? fmt(f['balance']) : '-',
      ];
    case 'new_members':
      return [
        row['member_number']?.toString() ?? '-',
        row['full_name']?.toString() ?? '-',
        row['phone_number']?.toString() ?? '-',
        fmtDate(row['created_at']),
        (row['status'] as String? ?? '-').toUpperCase(),
      ];
    case 'dormant_members':
      final b = row['bosa_accounts'];
      final f = row['fosa_accounts'];
      return [
        row['member_number']?.toString() ?? '-',
        row['full_name']?.toString() ?? '-',
        fmtDate(row['last_activity_at']),
        b is Map ? fmt(b['savings_balance']) : '-',
        f is Map ? fmt(f['balance']) : '-',
      ];
    case 'savings_summary':
      return [member(row), fmt(row['savings_balance']), fmt(row['shares_balance']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'deposit_collection':
    case 'withdrawal_report':
      return [fmtDate(row['created_at']), member(row), fmt(row['amount']), row['payment_method']?.toString() ?? '-', (row['status'] as String? ?? '-').toUpperCase()];
    case 'fosa_balances':
      return [row['account_number']?.toString() ?? '-', member(row), fmt(row['balance']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'loan_book':
      return [member(row), (row['loan_type'] as String? ?? '-').replaceAll('_', ' '), fmt(row['principal_amount']), fmt(row['outstanding_balance']), fmtDate(row['due_date']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'loan_disbursements':
      return [fmtDate(row['disbursed_at']), member(row), (row['loan_type'] as String? ?? '-').replaceAll('_', ' '), fmt(row['principal_amount']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'loan_repayments':
      final loan = row['loans'];
      return [
        fmtDate(loan is Map ? loan['due_date'] : null),
        loan is Map ? (loan['loan_type'] as String? ?? '-').replaceAll('_', ' ') : '-',
        fmt(row['expected_amount'] ?? row['amount']),
        fmt(row['amount']),
        fmt(row['balance_after']),
        (row['payment_method'] as String? ?? '-').toUpperCase(),
      ];
    case 'arrears':
      return [member(row), (row['loan_type'] as String? ?? '-').replaceAll('_', ' '), fmt(row['outstanding_balance']), daysPast(row['due_date']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'npl':
      return [member(row), (row['loan_type'] as String? ?? '-').replaceAll('_', ' '), fmt(row['principal_amount']), fmt(row['outstanding_balance']), daysPast(row['due_date'])];
    case 'mpesa_reconciliation':
      return [fmtDate(row['created_at']), row['reference']?.toString() ?? '-', member(row), fmt(row['amount']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'share_capital':
      final m = row['members'];
      return [(m is Map ? m['member_number'] : '-')?.toString() ?? '-', member(row), fmt(row['shares_balance']), fmt(row['shares_balance']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'dividend_report':
      final m = row['members'];
      return [(m is Map ? m['member_number'] : '-')?.toString() ?? '-', member(row), '-', fmt(row['amount']), fmtDate(row['created_at'])];
    case 'pending_approvals':
      return [(row['loan_type'] as String? ?? '-').replaceAll('_', ' '), member(row), fmt(row['principal_amount']), fmtDate(row['created_at']), (row['status'] as String? ?? '-').toUpperCase()];
    case 'audit_trail':
      return [fmtDate(row['created_at']), row['user_id']?.toString() ?? '-', row['action']?.toString() ?? '-', row['details']?.toString() ?? '-'];
    case 'daily_summary':
      return [
        row['date']?.toString() ?? '-',
        fmt(row['deposits']),
        fmt(row['withdrawals']),
        fmt(row['loan_disbursements']),
        fmt(row['loan_repayments']),
        fmt(row['net']),
      ];
    default:
      return row.values.map((v) => v?.toString() ?? '-').toList();
  }
}
