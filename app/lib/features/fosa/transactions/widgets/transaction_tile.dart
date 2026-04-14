import 'package:flutter/material.dart';

class TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const TransactionTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = tx['transaction_type'] ?? '';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0;
    final status = tx['status'] ?? 'completed';
    final isCredit = ['deposit', 'loan_disbursement', 'dividend'].contains(type);
    final isScheduled = type == 'scheduled_payment';
    final date = DateTime.tryParse(tx['created_at'] ?? '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isScheduled ? Colors.indigo : isCredit ? Colors.green : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isScheduled ? Icons.schedule : isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isScheduled ? Colors.indigo : isCredit ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                if (date != null)
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'} KES ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isScheduled ? Colors.indigo : isCredit ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (status != 'completed')
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: status == 'pending' ? Colors.blue : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
