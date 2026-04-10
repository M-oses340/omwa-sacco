import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/reports_bloc.dart';

class ReportsScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  const ReportsScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportsBloc()..add(ReportsLoaded(member['id'])),
      child: _ReportsView(member: member),
    );
  }
}

class _ReportsView extends StatefulWidget {
  final Map<String, dynamic> member;
  const _ReportsView({required this.member});
  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Summary'), Tab(text: 'Transactions'), Tab(text: 'Accounts')],
        ),
        actions: [
          BlocBuilder<ReportsBloc, ReportsState>(
            builder: (ctx, state) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ctx.read<ReportsBloc>().add(ReportsLoaded(widget.member['id'])),
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
            return Center(child: Text(state.message));
          }
          if (state is ReportsData) {
            return TabBarView(
              controller: _tabCtrl,
              children: [
                _SummaryTab(transactions: state.allTransactions, bosa: state.bosa, fosa: state.fosa),
                _TransactionsTab(state: state),
                _AccountsTab(bosa: state.bosa, fosa: state.fosa),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}

// ── Summary Tab ───────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic>? bosa;
  final Map<String, dynamic>? fosa;
  const _SummaryTab({required this.transactions, this.bosa, this.fosa});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const creditTypes = ['deposit', 'loan_disbursement', 'dividend'];
    double totalIn = 0, totalOut = 0;
    final Map<String, double> byType = {};
    for (final tx in transactions) {
      final type = tx['transaction_type'] ?? 'other';
      final amount = double.tryParse(tx['amount'].toString()) ?? 0;
      if (creditTypes.contains(type)) totalIn += amount; else totalOut += amount;
      byType[type] = (byType[type] ?? 0) + amount;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _StatCard(label: 'Total In', amount: totalIn, color: Colors.green, icon: Icons.arrow_downward)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Total Out', amount: totalOut, color: Colors.orange, icon: Icons.arrow_upward)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(label: 'Net Flow', amount: totalIn - totalOut, color: cs.primary, icon: Icons.trending_up)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Transactions', amount: transactions.length.toDouble(), color: Colors.purple, icon: Icons.receipt_long, isCount: true)),
        ]),
        const SizedBox(height: 20),
        Text('By Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...byType.entries.map((e) {
          final pct = (totalIn + totalOut) > 0 ? e.value / (totalIn + totalOut) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                Text('KES ${e.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: cs.surfaceContainerHighest),
              ),
            ]),
          );
        }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isCount;
  const _StatCard({required this.label, required this.amount, required this.color, required this.icon, this.isCount = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(isCount ? amount.toInt().toString() : 'KES ${amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
      ]),
    );
  }
}

// ── Transactions Tab ──────────────────────────────────────────────────────────

class _TransactionsTab extends StatelessWidget {
  final ReportsData state;
  const _TransactionsTab({required this.state});

  static const _types = ['all', 'deposit', 'withdrawal', 'transfer', 'loan_disbursement', 'loan_repayment'];

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
    const creditTypes = ['deposit', 'loan_disbursement', 'dividend'];
    double totalIn = 0, totalOut = 0;
    for (final tx in state.filtered) {
      final type = tx['transaction_type'] ?? '';
      final amount = double.tryParse(tx['amount'].toString()) ?? 0;
      if (creditTypes.contains(type)) totalIn += amount; else totalOut += amount;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _types.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(t == 'all' ? 'All' : t.replaceAll('_', ' ')),
                      selected: state.selectedType == t,
                      onSelected: (_) => context.read<ReportsBloc>().add(ReportsFilterChanged(type: t)),
                    ),
                  )).toList(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.date_range, color: state.dateRange != null ? cs.primary : null),
              onPressed: () => _pickDateRange(context),
            ),
            if (state.dateRange != null)
              IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => context.read<ReportsBloc>().add(ReportsDateRangeCleared())),
          ]),
        ),
        if (state.dateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                '${state.dateRange!.start.day}/${state.dateRange!.start.month}/${state.dateRange!.start.year} – ${state.dateRange!.end.day}/${state.dateRange!.end.month}/${state.dateRange!.end.year}',
                style: TextStyle(fontSize: 12, color: cs.primary),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _MiniStat(label: 'In', amount: totalIn, color: Colors.green),
            const SizedBox(width: 12),
            _MiniStat(label: 'Out', amount: totalOut, color: Colors.orange),
            const Spacer(),
            Text('${state.filtered.length} records', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
          ]),
        ),
        Expanded(
          child: state.filtered.isEmpty
              ? Center(child: Text('No transactions found', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: state.filtered.length,
                  itemBuilder: (_, i) => _TxRow(tx: state.filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _MiniStat({required this.label, required this.amount, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(label == 'In' ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 14),
      const SizedBox(width: 4),
      Text('$label: KES ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxRow({required this.tx});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = tx['transaction_type'] ?? '';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0;
    final status = tx['status'] ?? 'completed';
    final isCredit = ['deposit', 'loan_disbursement', 'dividend'].contains(type);
    final date = DateTime.tryParse(tx['created_at'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.orange, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (date != null) Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isCredit ? '+' : '-'} KES ${amount.toStringAsFixed(2)}',
              style: TextStyle(color: isCredit ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
          if (status != 'completed')
            Text(status.toUpperCase(), style: TextStyle(fontSize: 9, color: status == 'pending' ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }
}

// ── Accounts Tab ──────────────────────────────────────────────────────────────

class _AccountsTab extends StatelessWidget {
  final Map<String, dynamic>? bosa;
  final Map<String, dynamic>? fosa;
  const _AccountsTab({this.bosa, this.fosa});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String fmt(dynamic v) => 'KES ${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (bosa != null) ...[
          _AccountSection(
            title: 'BOSA Account',
            color: const Color(0xFF1565C0),
            rows: [
              ('Account No.', bosa!['account_number']?.toString() ?? '-'),
              ('Savings Balance', fmt(bosa!['savings_balance'])),
              ('Shares Balance', fmt(bosa!['shares_balance'])),
              ('Status', bosa!['status']?.toString().toUpperCase() ?? '-'),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (fosa != null)
          _AccountSection(
            title: 'FOSA Account',
            color: const Color(0xFF2E7D32),
            rows: [
              ('Account No.', fosa!['account_number']?.toString() ?? '-'),
              ('Balance', fmt(fosa!['balance'])),
              ('Status', fosa!['status']?.toString().toUpperCase() ?? '-'),
            ],
          ),
        if (bosa == null && fosa == null)
          Center(child: Text('No account data', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)))),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  final String title;
  final Color color;
  final List<(String, String)> rows;
  const _AccountSection({required this.title, required this.color, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(r.$1, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
            Text(r.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        )),
      ]),
    );
  }
}
