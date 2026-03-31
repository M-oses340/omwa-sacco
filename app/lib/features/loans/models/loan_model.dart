class LoanModel {
  final String id;
  final String loanNumber;
  final String loanType;
  final double principal;
  final double commissionAmount;
  final double interestRate;
  final int durationMonths;
  final double monthlyRepayment;
  final double totalRepayable;
  final double amountRepaid;
  final double outstandingBalance;
  final String status;
  final String? purpose;
  final DateTime? disbursedAt;
  final DateTime? dueDate;
  final DateTime createdAt;

  const LoanModel({
    required this.id,
    required this.loanNumber,
    required this.loanType,
    required this.principal,
    this.commissionAmount = 0,
    required this.interestRate,
    required this.durationMonths,
    required this.monthlyRepayment,
    required this.totalRepayable,
    required this.amountRepaid,
    required this.outstandingBalance,
    required this.status,
    this.purpose,
    this.disbursedAt,
    this.dueDate,
    required this.createdAt,
  });

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
    return LoanModel(
      id: map['id'] as String,
      loanNumber: map['loan_number'] as String,
      loanType: map['loan_type'] as String? ?? 'normal',
      principal: toDouble(map['principal']),
      commissionAmount: toDouble(map['commission_amount']),
      interestRate: toDouble(map['interest_rate']),
      durationMonths: (map['duration_months'] as num).toInt(),
      monthlyRepayment: toDouble(map['monthly_repayment']),
      totalRepayable: toDouble(map['total_repayable']),
      amountRepaid: toDouble(map['amount_repaid']),
      outstandingBalance: toDouble(map['outstanding_balance']),
      status: map['status'] as String? ?? 'pending',
      purpose: map['purpose'] as String?,
      disbursedAt: map['disbursed_at'] != null
          ? DateTime.tryParse(map['disbursed_at'] as String)
          : null,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
