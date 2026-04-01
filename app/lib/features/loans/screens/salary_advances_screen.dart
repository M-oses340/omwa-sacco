import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_product.dart';
import 'bosa_loans_screen.dart' show _ProductCard;
import 'loan_apply_sheet.dart';

class SalaryAdvancesScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final double bosaSavings;
  const SalaryAdvancesScreen(
      {super.key, required this.member, required this.bosaSavings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final products = LoanProduct.all
        .where((p) => p.category == LoanCategory.fosaAdvance)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Salary Advances')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.teal, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Salary advances are available to members whose salary is processed through FOSA (POFOSA).',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: products.length,
              itemBuilder: (_, i) => _ProductCard(
                product: products[i],
                bosaSavings: bosaSavings,
                onApply: () => LoanApplySheet.show(context,
                    product: products[i],
                    member: member,
                    bosaSavings: bosaSavings),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
