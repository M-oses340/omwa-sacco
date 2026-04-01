import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/loan_bloc.dart';
import '../models/loan_product.dart';
import 'loan_apply_sheet.dart';
import 'loan_product_card.dart';

class BosaLoansScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final double bosaSavings;
  const BosaLoansScreen(
      {super.key, required this.member, required this.bosaSavings});

  @override
  Widget build(BuildContext context) {
    final products = LoanProduct.all
        .where((p) => p.category == LoanCategory.bosa)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('BOSA Loans')),
      body: Column(
        children: [
          // Eligibility banner
          if (bosaSavings > 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your BOSA deposits: KES ${bosaSavings.toStringAsFixed(0)}\n'
                      'Max loan (5×): KES ${(bosaSavings * 5).toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: products.length,
              itemBuilder: (_, i) => LoanProductCard(
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
