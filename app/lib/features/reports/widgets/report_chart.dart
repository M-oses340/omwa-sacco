import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/report_definition.dart';

class ReportChart extends StatelessWidget {
  final ReportDefinition report;
  final List<Map<String, dynamic>> rows;
  final Color color;

  const ReportChart({
    super.key,
    required this.report,
    required this.rows,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = _buildChartData();
    if (chartData == null) return const SizedBox();

    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chartData.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: chartData.isBar
                ? _BarChart(data: chartData, color: color)
                : _LineChart(data: chartData, color: color),
          ),
        ],
      ),
    );
  }

  _ChartData? _buildChartData() {
    if (rows.isEmpty) return null;

    switch (report.id) {
      case 'my_transactions':
      case 'member_statement':
      case 'deposit_collection':
      case 'withdrawal_report':
        return _buildDailyAmountChart();

      case 'loan_book':
      case 'loan_disbursements':
        return _buildLoanTypeChart();

      case 'savings_summary':
      case 'fosa_balances':
        return _buildBalanceDistributionChart();

      case 'daily_summary':
        return _buildDailySummaryChart();

      default:
        return null;
    }
  }

  _ChartData? _buildDailyAmountChart() {
    final Map<String, double> byDay = {};
    for (final row in rows) {
      final d = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (d == null) continue;
      final key = '${d.day}/${d.month}';
      final amt = double.tryParse(row['amount']?.toString() ?? '') ?? 0;
      byDay[key] = (byDay[key] ?? 0) + amt;
    }
    if (byDay.isEmpty) return null;
    final entries = byDay.entries.toList().reversed.take(7).toList().reversed.toList();
    return _ChartData(
      title: 'Amount by Day (last 7 days)',
      labels: entries.map((e) => e.key).toList(),
      values: entries.map((e) => e.value).toList(),
      isBar: true,
    );
  }

  _ChartData? _buildLoanTypeChart() {
    final Map<String, double> byType = {};
    for (final row in rows) {
      final type = (row['loan_type'] as String? ?? 'other').replaceAll('_', ' ');
      final amt = double.tryParse(
              (row['outstanding_balance'] ?? row['principal_amount'])?.toString() ?? '') ??
          0;
      byType[type] = (byType[type] ?? 0) + amt;
    }
    if (byType.isEmpty) return null;
    final sorted = byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    return _ChartData(
      title: 'Portfolio by Loan Type',
      labels: top.map((e) => e.key).toList(),
      values: top.map((e) => e.value).toList(),
      isBar: true,
    );
  }

  _ChartData? _buildBalanceDistributionChart() {
    final Map<String, double> buckets = {'0-10K': 0, '10K-50K': 0, '50K-100K': 0, '100K+': 0};
    for (final row in rows) {
      final bal = double.tryParse(
              (row['savings_balance'] ?? row['balance'])?.toString() ?? '') ??
          0;
      if (bal < 10000) {
        buckets['0-10K'] = buckets['0-10K']! + 1;
      } else if (bal < 50000) {
        buckets['10K-50K'] = buckets['10K-50K']! + 1;
      } else if (bal < 100000) {
        buckets['50K-100K'] = buckets['50K-100K']! + 1;
      } else {
        buckets['100K+'] = buckets['100K+']! + 1;
      }
    }
    return _ChartData(
      title: 'Balance Distribution (members)',
      labels: buckets.keys.toList(),
      values: buckets.values.toList(),
      isBar: true,
    );
  }

  _ChartData? _buildDailySummaryChart() {
    final Map<String, double> deposits = {};
    final Map<String, double> withdrawals = {};
    for (final row in rows) {
      final d = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (d == null) continue;
      final key = '${d.day}/${d.month}';
      final amt = double.tryParse(row['amount']?.toString() ?? '') ?? 0;
      final type = row['transaction_type'] as String? ?? '';
      if (type == 'deposit') {
        deposits[key] = (deposits[key] ?? 0) + amt;
      } else if (type.contains('withdrawal')) {
        withdrawals[key] = (withdrawals[key] ?? 0) + amt;
      }
    }
    final keys = {...deposits.keys, ...withdrawals.keys}.toList()
      ..sort()
      ..take(7);
    if (keys.isEmpty) return null;
    final last7 = keys.reversed.take(7).toList().reversed.toList();
    return _ChartData(
      title: 'Deposits vs Withdrawals',
      labels: last7,
      values: last7.map((k) => deposits[k] ?? 0).toList(),
      secondaryValues: last7.map((k) => withdrawals[k] ?? 0).toList(),
      isBar: true,
    );
  }
}

class _ChartData {
  final String title;
  final List<String> labels;
  final List<double> values;
  final List<double>? secondaryValues;
  final bool isBar;

  _ChartData({
    required this.title,
    required this.labels,
    required this.values,
    this.secondaryValues,
    required this.isBar,
  });
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final _ChartData data;
  final Color color;
  const _BarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxY = [...data.values, ...(data.secondaryValues ?? [])].fold(0.0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${data.labels[group.x]}\n${_k(rod.toY)}',
              TextStyle(color: cs.onInverseSurface, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= data.labels.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(data.labels[i],
                      style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.6))),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(_k(v),
                  style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.5))),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.labels.length, (i) {
          final hasSecondary = data.secondaryValues != null;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data.values[i],
                color: color,
                width: hasSecondary ? 8 : 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              if (hasSecondary)
                BarChartRodData(
                  toY: data.secondaryValues![i],
                  color: Colors.orange,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
            ],
          );
        }),
      ),
    );
  }

  String _k(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Line chart ────────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final _ChartData data;
  final Color color;
  const _LineChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: data.values
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= data.labels.length) return const SizedBox();
                return Text(data.labels[i],
                    style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.6)));
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
