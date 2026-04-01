import 'package:flutter/material.dart';
import '../models/loan_product.dart';
import 'bosa_loans_screen.dart' show _ProductCard;
import 'loan_apply_sheet.dart';

class SpecialProductsScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final double bosaSavings;
  const SpecialProductsScreen(
      {super.key, required this.member, required this.bosaSavings});

  @override
  Widget build(BuildContext context) {
    final products = LoanProduct.all
        .where((p) => p.category == LoanCategory.special)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Special Products')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
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
    );
  }
}
