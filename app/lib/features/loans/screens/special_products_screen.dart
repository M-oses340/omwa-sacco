import 'package:flutter/material.dart';
import '../models/loan_product.dart';
import 'loan_apply_sheet.dart';
import 'loan_product_card.dart';

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
        itemBuilder: (_, i) => LoanProductCard(
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
