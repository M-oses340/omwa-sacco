import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/reports_bloc.dart';
import '../models/report_definition.dart';

class ReportViewerScreen extends StatefulWidget {
  final ReportDefinition report;
  final Map<String, dynamic> member;
  const ReportViewerScreen({super.key, required this.report, required this.member});

  @override
  State<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends State<ReportViewerScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(
          ReportViewRequested(reportId: widget.report.id, memberId: widget.member['id']),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.report.category.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.report.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ReportsBloc>().add(
                  ReportViewRequested(reportId: widget.report.id, memberId: widget.member['id']),
                ),
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
            return _ViewerBody(report: widget.report, state: state, color: color);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _ViewerBody extends StatelessWidget {
  final ReportDefinition report;
  final ReportViewData state;
  final Color color;
  const _ViewerBody({required this.report, required this.state, required this.color});

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
    final rows = state.rows;

    return Column(
      children: [
        // ── Filter bar ──────────────────────────────────────────────────────
        Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Expanded(
              child: state.dateRange != null
                  ? Chip(
                      avatar: Icon(Icons.date_range, size: 16, color: color),
                      label: Text(
                        '${_fmt(state.dateRange!.start)} – ${_fmt(state.dateRange!.end)}',
                        style: TextStyle(fontSize: 12, color: color),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () =>
                          context.read<ReportsBloc>().add(ReportsDateRangeCleared()),
                    )
                  : Text('All dates',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
            ),
            IconButton(
              icon: Icon(Icons.date_range,
                  color: state.dateRange != null ? color : cs.onSurface.withValues(alpha: 0.5)),
              onPressed: () => _pickDateRange(context),
              tooltip: 'Filter by date',
            ),
          ]),
        ),
        Divider(height: 1, color: cs.outlineVariant),

        // ── KPI summary row ─────────────────────────────────────────────────
        _KpiRow(rows: rows, report: report, color: color),
        Divider(height: 1, color: cs.outlineVariant),

        // ── Data table ──────────────────────────────────────────────────────
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text('No data found',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                  ]),
                )
              : _ReportTable(report: report, rows: rows),
        ),
      ],
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
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
    if (kpis.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text('${rows.length} record${rows.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
      );
    }
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: kpis
            .map((k) => Expanded(
                  child: Column(children: [
                    Text(k.$1,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                    Text(k.$2,
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6))),
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
        return [
          ('${rows.length}', 'Loans'),
          ('KES ${_k(total)}', 'Total Value'),
        ];

      case 'savings_summary':
      case 'fosa_balances':
        double total = 0;
        for (final r in rows) {
          total += double.tryParse(
                  (r['savings_balance'] ?? r['balance'])?.toString() ?? '') ??
              0;
        }
        return [
          ('${rows.length}', 'Accounts'),
          ('KES ${_k(total)}', 'Total Balance'),
        ];

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
      child: SingleChildScrollView(
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
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ))
              .toList(),
          rows: rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final cells = _buildCells(row, report.id);
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) =>
                  i.isOdd ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : null),
              cells: cells
                  .map((c) => DataCell(
                        Text(c,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

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
        return [
          member(row),
          fmt(row['savings_balance']),
          fmt(row['shares_balance']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'deposit_collection':
      case 'withdrawal_report':
        return [
          fmtDate(row['created_at']),
          member(row),
          fmt(row['amount']),
          row['payment_method']?.toString() ?? '-',
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'fosa_balances':
        return [
          row['account_number']?.toString() ?? '-',
          member(row),
          fmt(row['balance']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'loan_book':
        return [
          member(row),
          (row['loan_type'] as String? ?? '-').replaceAll('_', ' '),
          fmt(row['principal_amount']),
          fmt(row['outstanding_balance']),
          fmtDate(row['due_date']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'loan_disbursements':
        return [
          fmtDate(row['disbursed_at']),
          member(row),
          (row['loan_type'] as String? ?? '-').replaceAll('_', ' '),
          fmt(row['principal_amount']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'loan_repayments':
        final loan = row['loans'];
        return [
          fmtDate(row['due_date']),
          loan is Map ? (loan['loan_type'] as String? ?? '-').replaceAll('_', ' ') : '-',
          fmt(row['expected_amount']),
          fmt(row['paid_amount']),
          fmt(row['balance']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'arrears':
        return [
          member(row),
          (row['loan_type'] as String? ?? '-').replaceAll('_', ' '),
          fmt(row['outstanding_balance']),
          _daysPast(row['due_date']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'npl':
        return [
          member(row),
          (row['loan_type'] as String? ?? '-').replaceAll('_', ' '),
          fmt(row['principal_amount']),
          fmt(row['outstanding_balance']),
          _daysPast(row['due_date']),
        ];

      case 'mpesa_reconciliation':
        return [
          fmtDate(row['created_at']),
          row['reference']?.toString() ?? '-',
          member(row),
          fmt(row['amount']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'share_capital':
        return [
          (row['members'] is Map ? row['members']['member_number'] : '-')?.toString() ?? '-',
          member(row),
          fmt(row['shares_balance']),
          fmt(row['shares_balance']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'dividend_report':
        final m = row['members'];
        return [
          m is Map ? m['member_number']?.toString() ?? '-' : '-',
          member(row),
          '-',
          fmt(row['amount']),
          fmtDate(row['created_at']),
        ];

      case 'pending_approvals':
        return [
          (row['loan_type'] as String? ?? '-').replaceAll('_', ' '),
          member(row),
          fmt(row['principal_amount']),
          fmtDate(row['created_at']),
          (row['status'] as String? ?? '-').toUpperCase(),
        ];

      case 'audit_trail':
        return [
          fmtDate(row['created_at']),
          row['user_id']?.toString() ?? '-',
          row['action']?.toString() ?? '-',
          row['details']?.toString() ?? '-',
        ];

      default:
        return row.values.map((v) => v?.toString() ?? '-').toList();
    }
  }

  String _daysPast(dynamic dueDateStr) {
    final d = DateTime.tryParse(dueDateStr?.toString() ?? '');
    if (d == null) return '-';
    final days = DateTime.now().difference(d).inDays;
    return days > 0 ? '$days days' : 'Current';
  }
}
