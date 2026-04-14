import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transactions_bloc.dart';

class TransactionsScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const TransactionsScreen({super.key, required this.member});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _activeFilter;

  static const _filters = [
    {'label': 'All', 'value': null},
    {'label': 'Deposits', 'value': 'deposit'},
    {'label': 'Withdrawals', 'value': 'withdrawal'},
    {'label': 'Transfers', 'value': 'transfer'},
    {'label': 'Loans', 'value': 'loan_disbursement'},
    {'label': 'Scheduled', 'value': 'scheduled_payment'},
  ];

  void _applyFilter(String? type) {
    setState(() => _activeFilter = type);
    context.read<TransactionsBloc>().add(
          TransactionsLoaded(memberId: widget.member['id'], type: type),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
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
                  label: Text(f['label'] as String),
                  selected: selected,
                  onSelected: (_) => _applyFilter(f['value'] as String?),
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
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 8),
                Text(state.message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _applyFilter(_activeFilter),
                  child: const Text('Retry'),
                ),
              ]),
            );
          }
          if (state is TransactionsLoaded_) {
            final txs = state.transactions;
            if (txs.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No transactions found', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                ]),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => TransactionTile(tx: txs[i]),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
