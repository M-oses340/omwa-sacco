class AmortizationEntry {
  final int month;
  final double payment;
  final double principal;
  final double interest;
  final double balance;

  const AmortizationEntry({
    required this.month,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });

  factory AmortizationEntry.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
    return AmortizationEntry(
      month: (m['month'] as num).toInt(),
      payment: d(m['payment']),
      principal: d(m['principal']),
      interest: d(m['interest']),
      balance: d(m['balance']),
    );
  }
}
