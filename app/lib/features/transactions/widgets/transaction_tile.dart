import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const TransactionTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = tx['transaction_type'] ?? '';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0;
    final status = (tx['status'] ?? 'completed') as String;
    final isCredit = ['deposit', 'loan_disbursement', 'dividend'].contains(type);
    final isScheduled = type == 'scheduled_payment';
    final date = DateTime.tryParse(tx['created_at'] ?? '');
    final color = isScheduled ? Colors.indigo : isCredit ? const Color(0xFF2E7D32) : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(
            isScheduled ? Icons.schedule : isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color, size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _label(type),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (date != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 11,
                    color: Colors.grey.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM, yyyy • h:mm a').format(date.toLocal()),
                  style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${isCredit ? '+' : '-'} KES ${NumberFormat('#,##0.##').format(amount)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          _StatusBadge(status: status),
        ]),
      ]),
    );
  }

  String _label(String type) => switch (type) {
        'deposit' => 'Deposit',
        'withdrawal' => 'Withdrawal',
        'transfer' => 'Transfer',
        'loan_disbursement' => 'Loan',
        'loan_repayment' => 'Loan Repayment',
        'scheduled_payment' => 'Scheduled Payment',
        'dividend' => 'Dividend',
        'airtime' => 'Airtime',
        _ => type.replaceAll('_', ' ').toUpperCase(),
      };
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'completed' => (const Color(0xFF2E7D32), const Color(0xFF1B5E20)),
      'pending'   => (Colors.blue, const Color(0xFF0D47A1)),
      'failed'    => (Colors.red, const Color(0xFFB71C1C)),
      'cancelled' => (Colors.grey, const Color(0xFF424242)),
      _           => (Colors.grey, const Color(0xFF424242)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
