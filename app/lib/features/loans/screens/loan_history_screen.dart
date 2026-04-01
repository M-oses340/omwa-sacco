import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_model.dart';
import '../models/loan_product.dart';
import 'loan_detail_screen.dart';

class LoanHistoryScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final List<LoanModel> loans;
  const LoanHistoryScreen(
      {super.key, required this.member, required this.loans});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<LoanBloc>()
                .add(LoanHistoryRequested(member['id'] as String)),
          ),
        ],
      ),
      body: BlocBuilder<LoanBloc, LoanState>(
        builder: (context, state) {
          final list = state is LoanHistoryLoaded ? state.loans : loans;

          if (state is LoanLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 64,
                      color: cs.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No loan history yet',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 16)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context
                .read<LoanBloc>()
                .add(LoanHistoryRequested(member['id'] as String)),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _LoanHistoryTile(
                  loan: list[i], member: member),
            ),
          );
        },
      ),
    );
  }
}

class _LoanHistoryTile extends StatelessWidget {
  final LoanModel loan;
  final Map<String, dynamic> member;
  const _LoanHistoryTile({required this.loan, required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = LoanProduct.find(loan.loanType);
    final progress = loan.totalRepayable > 0
        ? (loan.amountRepaid / loan.totalRepayable).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<LoanBloc>(),
            child: LoanDetailScreen(loan: loan, member: member),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(product?.displayName ?? loan.loanType,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                _StatusChip(status: loan.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('KES ${loan.principal.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(loan.loanNumber,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${loan.durationMonths} months · '
              '${loan.createdAt.day}/${loan.createdAt.month}/${loan.createdAt.year}',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            if (loan.status == 'disbursed' && loan.totalRepayable > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% repaid · '
                'KES ${loan.outstandingBalance.toStringAsFixed(0)} remaining',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() => switch (status) {
        'approved' => Colors.blue,
        'disbursed' => Colors.green,
        'rejected' => Colors.red,
        'repaid' => Colors.teal,
        'defaulted' => Colors.deepOrange,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                color: _color(),
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      );
}
