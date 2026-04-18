import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transactions_bloc.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const TransactionsScreen({super.key, required this.member});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _activeFilter;
  int _page = 1;
  static const _pageSize = 10;

  static const _filters = <Map<String, String?>>[
    {'label': 'All',        'value': null},
    {'label': 'Deposits',   'value': 'deposit'},
    {'label': 'Withdrawals','value': 'withdrawal'},
    {'label': 'Transfers',  'value': 'transfer'},
    {'label': 'Loans',      'value': 'loan_disbursement'},
    {'label': 'Scheduled',  'value': 'scheduled_payment'},
  ];

  void _applyFilter(String? type) {
    setState(() { _activeFilter = type; _page = 1; });
    context.read<TransactionsBloc>().add(
      TransactionsLoaded(memberId: widget.member['id'], type: type),
    );
  }

  void _goToPage(int page, List<Map<String, dynamic>> all) {
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _activeFilter == f['value'];
                return FilterChip(
                  label: Text(f['label']!),
                  selected: selected,
                  onSelected: (_) => _applyFilter(f['value']),
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.onPrimaryContainer,
                );
              },
            ),
          ),
        ),
      ),
      body: BlocBuilder<TransactionsBloc, TransactionsState>(
        builder: (context, state) {
          if (state is TransactionsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TransactionsError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 8),
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => _applyFilter(_activeFilter), child: const Text('Retry')),
            ]));
          }
          if (state is TransactionsSuccess) {
            final all = state.transactions;
            if (all.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No transactions found', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
              ]));
            }

            final totalPages = (all.length / _pageSize).ceil();
            final start = (_page - 1) * _pageSize;
            final end = (start + _pageSize).clamp(0, all.length);
            final pageTxs = all.sublist(start, end);

            return Column(children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: pageTxs.length,
                  itemBuilder: (_, i) => TransactionTile(tx: pageTxs[i]),
                ),
              ),
              if (totalPages > 1)
                _Pagination(
                  current: _page,
                  total: totalPages,
                  onPage: (p) => _goToPage(p, all),
                ),
            ]);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int current;
  final int total;
  final void Function(int) onPage;
  const _Pagination({required this.current, required this.total, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Show at most 3 page numbers around current
    final pages = <int>[];
    for (int i = 1; i <= total; i++) {
      if (i == 1 || i == total || (i >= current - 1 && i <= current + 1)) {
        pages.add(i);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PageBtn(
          label: '< Previous',
          enabled: current > 1,
          active: false,
          onTap: () => onPage(current - 1),
          cs: cs,
        ),
        const SizedBox(width: 6),
        ...pages.map((p) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _PageBtn(
            label: '$p',
            enabled: true,
            active: p == current,
            onTap: () => onPage(p),
            cs: cs,
          ),
        )),
        const SizedBox(width: 6),
        _PageBtn(
          label: 'Next >',
          enabled: current < total,
          active: false,
          onTap: () => onPage(current + 1),
          cs: cs,
        ),
      ]),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _PageBtn({required this.label, required this.enabled, required this.active, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? cs.onPrimary : enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
