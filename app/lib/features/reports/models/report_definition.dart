import 'package:flutter/material.dart';

enum ReportCategory {
  members,
  savings,
  loans,
  financial,
  transactions,
  compliance,
  operational,
}

extension ReportCategoryX on ReportCategory {
  String get label => switch (this) {
        ReportCategory.members => 'Members',
        ReportCategory.savings => 'Savings & Deposits',
        ReportCategory.loans => 'Loans',
        ReportCategory.financial => 'Financial',
        ReportCategory.transactions => 'Transactions',
        ReportCategory.compliance => 'Compliance',
        ReportCategory.operational => 'Operational',
      };

  IconData get icon => switch (this) {
        ReportCategory.members => Icons.people_outline,
        ReportCategory.savings => Icons.savings_outlined,
        ReportCategory.loans => Icons.account_balance_wallet_outlined,
        ReportCategory.financial => Icons.bar_chart_outlined,
        ReportCategory.transactions => Icons.receipt_long_outlined,
        ReportCategory.compliance => Icons.verified_outlined,
        ReportCategory.operational => Icons.settings_outlined,
      };

  Color get color => switch (this) {
        ReportCategory.members => const Color(0xFF1565C0),
        ReportCategory.savings => const Color(0xFF00695C),
        ReportCategory.loans => const Color(0xFF6A1B9A),
        ReportCategory.financial => const Color(0xFFE65100),
        ReportCategory.transactions => const Color(0xFF0277BD),
        ReportCategory.compliance => const Color(0xFF2E7D32),
        ReportCategory.operational => const Color(0xFF4E342E),
      };
}

class ReportDefinition {
  final String id;
  final String title;
  final String description;
  final ReportCategory category;
  final bool adminOnly;
  final List<String> columns;
  final String query; // logical identifier used by bloc

  const ReportDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.columns,
    required this.query,
    this.adminOnly = false,
  });
}

// ── Report catalogue ──────────────────────────────────────────────────────────

const List<ReportDefinition> kReports = [
  // Members
  ReportDefinition(
    id: 'member_register',
    title: 'Member Register',
    description: 'Full list of members with status and balances',
    category: ReportCategory.members,
    adminOnly: true,
    columns: ['Member No.', 'Name', 'Phone', 'Status', 'BOSA Balance', 'FOSA Balance'],
    query: 'member_register',
  ),
  ReportDefinition(
    id: 'member_statement',
    title: 'Member Statement',
    description: 'Individual transaction history for a member',
    category: ReportCategory.members,
    columns: ['Date', 'Type', 'Amount', 'Balance', 'Status'],
    query: 'member_statement',
  ),
  ReportDefinition(
    id: 'new_members',
    title: 'New Registrations',
    description: 'Members registered within a date range',
    category: ReportCategory.members,
    adminOnly: true,
    columns: ['Member No.', 'Name', 'Phone', 'Joined', 'Status'],
    query: 'new_members',
  ),
  ReportDefinition(
    id: 'dormant_members',
    title: 'Dormant Members',
    description: 'Members with no activity in 90+ days',
    category: ReportCategory.members,
    adminOnly: true,
    columns: ['Member No.', 'Name', 'Last Activity', 'BOSA Balance', 'FOSA Balance'],
    query: 'dormant_members',
  ),

  // Savings
  ReportDefinition(
    id: 'savings_summary',
    title: 'Savings Summary',
    description: 'Savings balance per member',
    category: ReportCategory.savings,
    adminOnly: true,
    columns: ['Name', 'Savings Balance', 'Shares Balance', 'Status'],
    query: 'savings_summary',
  ),
  ReportDefinition(
    id: 'deposit_collection',
    title: 'Deposit Collection',
    description: 'Deposits collected within a period',
    category: ReportCategory.savings,
    adminOnly: true,
    columns: ['Date', 'Member', 'Amount', 'Method', 'Status'],
    query: 'deposit_collection',
  ),
  ReportDefinition(
    id: 'fosa_balances',
    title: 'FOSA Balances',
    description: 'Current FOSA account balances',
    category: ReportCategory.savings,
    adminOnly: true,
    columns: ['Account No.', 'Member', 'Balance', 'Status'],
    query: 'fosa_balances',
  ),
  ReportDefinition(
    id: 'my_savings',
    title: 'My Savings',
    description: 'Your BOSA & FOSA account details',
    category: ReportCategory.savings,
    columns: ['Account', 'Balance', 'Status'],
    query: 'my_savings',
  ),

  // Loans
  ReportDefinition(
    id: 'loan_book',
    title: 'Loan Book',
    description: 'All active loans with outstanding balances',
    category: ReportCategory.loans,
    adminOnly: true,
    columns: ['Member', 'Loan Type', 'Principal', 'Outstanding', 'Due Date', 'Status'],
    query: 'loan_book',
  ),
  ReportDefinition(
    id: 'loan_disbursements',
    title: 'Loan Disbursements',
    description: 'Loans disbursed within a period',
    category: ReportCategory.loans,
    adminOnly: true,
    columns: ['Date', 'Member', 'Loan Type', 'Amount', 'Status'],
    query: 'loan_disbursements',
  ),
  ReportDefinition(
    id: 'loan_repayments',
    title: 'Repayment Schedule',
    description: 'Scheduled vs actual repayments',
    category: ReportCategory.loans,
    columns: ['Due Date', 'Loan Type', 'Amount', 'Paid', 'Balance After', 'Method'],
    query: 'loan_repayments',
  ),
  ReportDefinition(
    id: 'arrears',
    title: 'Arrears Report',
    description: 'Overdue loans by 30/60/90+ days',
    category: ReportCategory.loans,
    adminOnly: true,
    columns: ['Member', 'Loan Type', 'Overdue Amount', 'Days Overdue', 'Status'],
    query: 'arrears',
  ),
  ReportDefinition(
    id: 'npl',
    title: 'Non-Performing Loans',
    description: 'Loans classified as non-performing',
    category: ReportCategory.loans,
    adminOnly: true,
    columns: ['Member', 'Loan Type', 'Principal', 'Outstanding', 'Days Overdue'],
    query: 'npl',
  ),
  ReportDefinition(
    id: 'par',
    title: 'Portfolio at Risk (PAR)',
    description: 'Loan portfolio at risk summary',
    category: ReportCategory.loans,
    adminOnly: true,
    columns: ['Loan Type', 'Total Portfolio', 'At Risk', 'PAR %'],
    query: 'par',
  ),

  // Financial
  ReportDefinition(
    id: 'income_statement',
    title: 'Income Statement',
    description: 'Interest income, fees and expenses',
    category: ReportCategory.financial,
    adminOnly: true,
    columns: ['Category', 'Description', 'Amount'],
    query: 'income_statement',
  ),
  ReportDefinition(
    id: 'balance_sheet',
    title: 'Balance Sheet',
    description: 'Assets, liabilities and equity',
    category: ReportCategory.financial,
    adminOnly: true,
    columns: ['Category', 'Item', 'Amount'],
    query: 'balance_sheet',
  ),
  ReportDefinition(
    id: 'cash_flow',
    title: 'Cash Flow Statement',
    description: 'Cash inflows and outflows',
    category: ReportCategory.financial,
    adminOnly: true,
    columns: ['Category', 'Description', 'Amount'],
    query: 'cash_flow',
  ),
  ReportDefinition(
    id: 'trial_balance',
    title: 'Trial Balance',
    description: 'Debit and credit balances',
    category: ReportCategory.financial,
    adminOnly: true,
    columns: ['Account', 'Debit', 'Credit'],
    query: 'trial_balance',
  ),

  // Transactions
  ReportDefinition(
    id: 'my_transactions',
    title: 'My Transactions',
    description: 'Your full transaction history with filters',
    category: ReportCategory.transactions,
    columns: ['Date', 'Type', 'Amount', 'Balance', 'Status'],
    query: 'my_transactions',
  ),
  ReportDefinition(
    id: 'withdrawal_report',
    title: 'Withdrawal Report',
    description: 'FOSA & BOSA withdrawals',
    category: ReportCategory.transactions,
    adminOnly: true,
    columns: ['Date', 'Member', 'Amount', 'Method', 'Status'],
    query: 'withdrawal_report',
  ),
  ReportDefinition(
    id: 'daily_summary',
    title: 'Daily Transaction Summary',
    description: 'Aggregated transactions by day',
    category: ReportCategory.transactions,
    adminOnly: true,
    columns: ['Date', 'Deposits', 'Withdrawals', 'Loan Disb.', 'Repayments', 'Net'],
    query: 'daily_summary',
  ),
  ReportDefinition(
    id: 'mpesa_reconciliation',
    title: 'M-Pesa Reconciliation',
    description: 'Mobile money transaction reconciliation',
    category: ReportCategory.transactions,
    adminOnly: true,
    columns: ['Date', 'Reference', 'Member', 'Amount', 'Status'],
    query: 'mpesa_reconciliation',
  ),

  // Compliance
  ReportDefinition(
    id: 'sasra_report',
    title: 'SASRA Compliance',
    description: 'Regulatory compliance report',
    category: ReportCategory.compliance,
    adminOnly: true,
    columns: ['Metric', 'Required', 'Actual', 'Status'],
    query: 'sasra_report',
  ),
  ReportDefinition(
    id: 'share_capital',
    title: 'Share Capital Report',
    description: 'Member share capital summary',
    category: ReportCategory.compliance,
    adminOnly: true,
    columns: ['Member No.', 'Name', 'Shares', 'Value', 'Status'],
    query: 'share_capital',
  ),
  ReportDefinition(
    id: 'dividend_report',
    title: 'Dividend Distribution',
    description: 'Dividend payments per member',
    category: ReportCategory.compliance,
    adminOnly: true,
    columns: ['Member No.', 'Name', 'Shares', 'Dividend Amount', 'Date'],
    query: 'dividend_report',
  ),

  // Operational
  ReportDefinition(
    id: 'teller_reconciliation',
    title: 'Teller Reconciliation',
    description: 'Cashier daily reconciliation',
    category: ReportCategory.operational,
    adminOnly: true,
    columns: ['Teller', 'Opening', 'Cash In', 'Cash Out', 'Closing', 'Variance'],
    query: 'teller_reconciliation',
  ),
  ReportDefinition(
    id: 'pending_approvals',
    title: 'Pending Approvals',
    description: 'Items awaiting approval',
    category: ReportCategory.operational,
    adminOnly: true,
    columns: ['Type', 'Member', 'Amount', 'Submitted', 'Status'],
    query: 'pending_approvals',
  ),
  ReportDefinition(
    id: 'audit_trail',
    title: 'Audit Trail',
    description: 'System activity log',
    category: ReportCategory.operational,
    adminOnly: true,
    columns: ['Timestamp', 'User', 'Action', 'Details'],
    query: 'audit_trail',
  ),
];
