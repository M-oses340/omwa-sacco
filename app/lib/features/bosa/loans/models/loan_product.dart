enum LoanCategory { bosa, fosaAdvance, special }

enum InterestType { reducingBalance, flatMonthly, flatDisbursement, none }

class LoanProduct {
  final String loanType;
  final String displayName;
  final LoanCategory category;
  final int maxMonths;
  final double depositMultiplier; // 0 = not deposit-based
  final double interestRatePa;    // annual %; 0 for Muslim/Q-Cash
  final double? monthlyRate;      // FOSA advances
  final InterestType interestType;
  final double commissionPct;     // Muslim loans one-off
  final double? maxAmount;        // Q-Cash cap
  final bool salaryRequired;
  final bool noDividends;
  final String? notes;

  const LoanProduct({
    required this.loanType,
    required this.displayName,
    required this.category,
    required this.maxMonths,
    required this.depositMultiplier,
    required this.interestRatePa,
    this.monthlyRate,
    required this.interestType,
    this.commissionPct = 0,
    this.maxAmount,
    this.salaryRequired = false,
    this.noDividends = false,
    this.notes,
  });

  String get categoryLabel {
    switch (category) {
      case LoanCategory.bosa:
        return 'BOSA Loan';
      case LoanCategory.fosaAdvance:
        return 'Salary Advance';
      case LoanCategory.special:
        return 'Special Product';
    }
  }

  String get rateLabel {
    switch (interestType) {
      case InterestType.reducingBalance:
        if (monthlyRate != null) return '$monthlyRate% p.m. reducing';
        return '$interestRatePa% p.a. reducing';
      case InterestType.flatMonthly:
        return '${monthlyRate ?? interestRatePa}% p.m. flat';
      case InterestType.flatDisbursement:
        if (loanType == 'qcash') return '5% at disbursement';
        if (loanType == 'dividend_advance') return '10% flat charge';
        return 'Flat at disbursement';
      case InterestType.none:
        return commissionPct > 0
            ? '0% interest + ${commissionPct.toStringAsFixed(0)}% commission'
            : 'No interest';
    }
  }

  /// Compute monthly repayment and total repayable for a given principal & months.
  ({double monthly, double total, double commission}) calculate(
      double principal, int months) {
    switch (interestType) {
      case InterestType.reducingBalance:
        final mr = monthlyRate != null
            ? monthlyRate! / 100
            : interestRatePa / 100 / 12;
        final monthly = (principal * mr * _pow(1 + mr, months)) /
            (_pow(1 + mr, months) - 1);
        return (
          monthly: _r(monthly),
          total: _r(monthly * months),
          commission: 0,
        );

      case InterestType.flatMonthly:
        final mr = (monthlyRate ?? interestRatePa) / 100;
        final interest = principal * mr * months;
        return (
          monthly: _r((principal + interest) / months),
          total: _r(principal + interest),
          commission: 0,
        );

      case InterestType.flatDisbursement:
        if (loanType == 'qcash') {
          final charge = principal * 0.05;
          return (
            monthly: _r((principal + charge) / 2),
            total: _r(principal + charge),
            commission: _r(charge),
          );
        }
        if (loanType == 'dividend_advance') {
          final charge = principal * 0.10;
          return (
            monthly: _r(principal + charge),
            total: _r(principal + charge),
            commission: _r(charge),
          );
        }
        return (monthly: _r(principal / months), total: principal, commission: 0);

      case InterestType.none:
        final commission = principal * (commissionPct / 100);
        return (
          monthly: _r(principal / months),
          total: principal,
          commission: _r(commission),
        );
    }
  }

  double _r(double v) => double.parse(v.toStringAsFixed(2));
  double _pow(double base, int exp) {
    double r = 1;
    for (int i = 0; i < exp; i++) { r *= base; }
    return r;
  }

  static const List<LoanProduct> all = [
    // ── BOSA loans ──────────────────────────────────────────────────────────
    LoanProduct(loanType: 'normal',          displayName: 'Normal Loan',           category: LoanCategory.bosa,         maxMonths: 48,  depositMultiplier: 5, interestRatePa: 12.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'jumbo',           displayName: 'Jumbo Loan',            category: LoanCategory.bosa,         maxMonths: 108, depositMultiplier: 5, interestRatePa: 15.6, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'bima',            displayName: 'Bima Loan',             category: LoanCategory.bosa,         maxMonths: 12,  depositMultiplier: 5, interestRatePa: 10.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'premier',         displayName: 'Premier Loan',          category: LoanCategory.bosa,         maxMonths: 96,  depositMultiplier: 5, interestRatePa: 15.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'super',           displayName: 'Super Loan',            category: LoanCategory.bosa,         maxMonths: 72,  depositMultiplier: 5, interestRatePa: 14.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'mega',            displayName: 'Mega Loan',             category: LoanCategory.bosa,         maxMonths: 84,  depositMultiplier: 5, interestRatePa: 14.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'refinancing',     displayName: 'Refinancing Loan',      category: LoanCategory.bosa,         maxMonths: 60,  depositMultiplier: 5, interestRatePa: 12.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'emergency',       displayName: 'Emergency Loan',        category: LoanCategory.bosa,         maxMonths: 24,  depositMultiplier: 5, interestRatePa: 12.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'school_fees',     displayName: 'School Fees Loan',      category: LoanCategory.bosa,         maxMonths: 12,  depositMultiplier: 5, interestRatePa: 12.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'asset_financing', displayName: 'Asset Financing Loan',  category: LoanCategory.bosa,         maxMonths: 24,  depositMultiplier: 5, interestRatePa: 12.0, interestType: InterestType.reducingBalance),
    LoanProduct(loanType: 'muslim',          displayName: 'Muslim Loan',           category: LoanCategory.bosa,         maxMonths: 60,  depositMultiplier: 4, interestRatePa: 0,    interestType: InterestType.none,             commissionPct: 7, noDividends: true,  notes: 'No interest. 7% one-off commission. No dividends.'),
    LoanProduct(loanType: 'muslim_emergency',displayName: 'Muslim Emergency Loan', category: LoanCategory.bosa,         maxMonths: 24,  depositMultiplier: 4, interestRatePa: 0,    interestType: InterestType.none,             commissionPct: 7, noDividends: true,  notes: 'No interest. 7% one-off commission. No dividends.'),
    // ── FOSA salary advances ─────────────────────────────────────────────────
    LoanProduct(loanType: 'msasa',           displayName: 'M-Sasa',                category: LoanCategory.fosaAdvance,  maxMonths: 3,   depositMultiplier: 0, interestRatePa: 0,    interestType: InterestType.flatMonthly,      monthlyRate: 2.0, salaryRequired: true),
    LoanProduct(loanType: 'fosa_flex',       displayName: 'FOSA Flex',             category: LoanCategory.fosaAdvance,  maxMonths: 6,   depositMultiplier: 0, interestRatePa: 0,    interestType: InterestType.flatMonthly,      monthlyRate: 3.0, salaryRequired: true),
    LoanProduct(loanType: 'fosa_golden',     displayName: 'FOSA Golden',           category: LoanCategory.fosaAdvance,  maxMonths: 9,   depositMultiplier: 0, interestRatePa: 0,    interestType: InterestType.reducingBalance,  monthlyRate: 3.5, salaryRequired: true),
    LoanProduct(loanType: 'fosa_ultra',      displayName: 'FOSA Ultra',            category: LoanCategory.fosaAdvance,  maxMonths: 12,  depositMultiplier: 0, interestRatePa: 0,    interestType: InterestType.flatMonthly,      monthlyRate: 4.0, salaryRequired: true),
    // ── Special products ─────────────────────────────────────────────────────
    LoanProduct(loanType: 'qcash',           displayName: 'Q-Cash',                category: LoanCategory.special,      maxMonths: 2,   depositMultiplier: 0, interestRatePa: 0,    interestType: InterestType.flatDisbursement, maxAmount: 40000, notes: 'Max KES 40,000. 5% at disbursement. 2 equal instalments. 60-day max.'),
    LoanProduct(loanType: 'dividend_advance',displayName: 'Dividend Advance',      category: LoanCategory.special,      maxMonths: 1,   depositMultiplier: 0, interestRatePa: 0,    interestType: InterestType.flatDisbursement, notes: 'Up to 50% of prior-year dividends. 10% flat charge.'),
  ];

  static LoanProduct? find(String type) {
    try {
      return all.firstWhere((p) => p.loanType == type);
    } catch (_) {
      return null;
    }
  }
}
