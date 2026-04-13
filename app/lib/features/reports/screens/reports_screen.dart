import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/reports_bloc.dart';
import '../models/report_definition.dart';
import 'report_viewer_screen.dart';

class ReportsScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  const ReportsScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsBloc()..add(ReportsLoaded(member['id'])),
      child: _ReportsHub(member: member),
    );
  }
}

class _ReportsHub extends StatelessWidget {
  final Map<String, dynamic> member;
  const _ReportsHub({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            builder: (ctx, state) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ctx.read<ReportsBloc>().add(ReportsLoaded(member['id'])),
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
                  onPressed: () => ctx.read<ReportsBloc>().add(ReportsLoaded(member['id'])),
                  child: const Text('Retry'),
                ),
              ]),
            );
          }
          if (state is ReportsHubData) {
            return _HubBody(member: member, state: state);
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _HubBody extends StatelessWidget {
  final Map<String, dynamic> member;
  final ReportsHubData state;
  const _HubBody({required this.member, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const categories = ReportCategory.values;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Quick stats banner
        _QuickStatsBanner(bosa: state.bosa, fosa: state.fosa),
        const SizedBox(height: 20),
        Text('Report Categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final cat = categories[i];
            final reports = kReports.where((r) {
              if (r.category != cat) return false;
              if (r.adminOnly && !state.isAdmin) return false;
              return true;
            }).toList();
            if (reports.isEmpty) return const SizedBox();
            return _CategoryCard(
              category: cat,
              reportCount: reports.length,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ReportsBloc>(),
                    child: ReportCategoryScreen(
                      member: member,
                      category: cat,
                      reports: reports,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (state.recentTransactions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Recent Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...state.recentTransactions.map((tx) => _RecentTxTile(tx: tx, cs: cs)),
        ],
      ],
    );
  }
}

class _QuickStatsBanner extends StatelessWidget {
  final Map<String, dynamic>? bosa;
  final Map<String, dynamic>? fosa;
  const _QuickStatsBanner({this.bosa, this.fosa});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String fmt(dynamic v) =>
        'KES ${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BannerStat(
              label: 'BOSA Savings',
              value: fmt(bosa?['savings_balance']),
              icon: Icons.savings_outlined,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: _BannerStat(
              label: 'FOSA Balance',
              value: fmt(fosa?['balance']),
              icon: Icons.account_balance_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _BannerStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

class _CategoryCard extends StatelessWidget {
  final ReportCategory category;
  final int reportCount;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.reportCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: category.color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: category.color, size: 20),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$reportCount', style: TextStyle(fontSize: 11, color: category.color, fontWeight: FontWeight.bold)),
            ),
          ]),
          const Spacer(),
          Text(category.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('$reportCount report${reportCount == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final ColorScheme cs;
  const _RecentTxTile({required this.tx, required this.cs});

  @override
  Widget build(BuildContext context) {
    final type = tx['transaction_type'] ?? '';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0;
    final isCredit = ['deposit', 'loan_disbursement', 'dividend'].contains(type);
    final date = DateTime.tryParse(tx['created_at'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? Colors.green : Colors.orange, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(type.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isCredit ? '+' : '-'} KES ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: isCredit ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          if (date != null)
            Text('${date.day}/${date.month}/${date.year}',
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
        ]),
      ]),
    );
  }
}

// ── Category Screen ───────────────────────────────────────────────────────────

class ReportCategoryScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final ReportCategory category;
  final List<ReportDefinition> reports;
  const ReportCategoryScreen({
    super.key,
    required this.member,
    required this.category,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: const BackButton(),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ReportCard(report: reports[i], member: member),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportDefinition report;
  final Map<String, dynamic> member;
  const _ReportCard({required this.report, required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = report.category.color;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<ReportsBloc>(),
            child: ReportViewerScreen(report: report, member: member),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(report.category.icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(report.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 3),
              Text(report.description,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
            ]),
          ),
          Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}
