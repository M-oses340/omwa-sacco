import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/bloc/auth_bloc.dart';
import '../transactions/bloc/transaction_bloc.dart';
import '../transactions/screens/deposit_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/connectivity_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const DashboardScreen({super.key, required this.member});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _bosa;
  Map<String, dynamic>? _fosa;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      final memberId = widget.member['id'];

      final results = await ConnectivityService.instance.guard(() => Future.wait([
            supabase.from('bosa_accounts').select().eq('member_id', memberId).maybeSingle(),
            supabase.from('fosa_accounts').select().eq('member_id', memberId).maybeSingle(),
            supabase
                .from('transactions')
                .select()
                .eq('member_id', memberId)
                .order('created_at', ascending: false)
                .limit(5),
          ]));

      setState(() {
        _bosa = results[0] as Map<String, dynamic>?;
        _fosa = results[1] as Map<String, dynamic>?;
        _transactions = (results[2] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.member['full_name'] ?? 'Member';
    final memberNumber = widget.member['member_number'] ?? '';

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 8),
                            const Text('Omwa Sacco',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white),
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(AuthLogoutRequested()),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'M',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, ${name.split(' ').first}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text('Member #$memberNumber',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          // Account cards
                          Row(
                            children: [
                              Expanded(
                                child: _AccountCard(
                                  title: 'BOSA',
                                  subtitle: 'Savings & Shares',
                                  savings: _bosa?['savings_balance'],
                                  shares: _bosa?['shares_balance'],
                                  accountNumber: _bosa?['account_number'],
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AccountCard(
                                  title: 'FOSA',
                                  subtitle: 'Current Account',
                                  savings: _fosa?['balance'],
                                  accountNumber: _fosa?['account_number'],
                                  color: const Color(0xFF00695C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Quick actions
                          const Text('Quick Actions',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _QuickAction(
                                  icon: Icons.arrow_downward,
                                  label: 'Deposit',
                                  color: Colors.green,
                                  onTap: () async {
                                    final refreshed = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider(
                                          create: (_) => TransactionBloc(),
                                          child: DepositScreen(
                                              member: widget.member),
                                        ),
                                      ),
                                    );
                                    if (refreshed == true) _loadData();
                                  }),
                              _QuickAction(
                                  icon: Icons.arrow_upward,
                                  label: 'Withdraw',
                                  color: Colors.orange,
                                  onTap: () {}),
                              _QuickAction(
                                  icon: Icons.swap_horiz,
                                  label: 'Transfer',
                                  color: Colors.blue,
                                  onTap: () {}),
                              _QuickAction(
                                  icon: Icons.account_balance_wallet,
                                  label: 'Loans',
                                  color: Colors.purple,
                                  onTap: () {}),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Recent transactions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recent Transactions',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              TextButton(
                                onPressed: () {},
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_transactions.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No transactions yet',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ..._transactions.map((tx) => _TransactionTile(tx: tx)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic savings;
  final dynamic shares;
  final String? accountNumber;
  final Color color;

  const _AccountCard({
    required this.title,
    required this.subtitle,
    this.savings,
    this.shares,
    this.accountNumber,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          if (savings != null) ...[
            const Text('Balance', style: TextStyle(color: Colors.white60, fontSize: 11)),
            Text(
              'KES ${_fmt(savings)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ] else
            const Text('No account',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          if (shares != null) ...[
            const SizedBox(height: 4),
            Text('Shares: KES ${_fmt(shares)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          if (accountNumber != null) ...[
            const SizedBox(height: 6),
            Text(accountNumber!,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0.00';
    return double.tryParse(val.toString())?.toStringAsFixed(2) ?? '0.00';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = tx['transaction_type'] ?? '';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0;
    final isCredit = ['deposit', 'loan_disbursement', 'dividend'].contains(type);
    final date = DateTime.tryParse(tx['created_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Colors.green : Colors.red,
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
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (date != null)
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'} KES ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isCredit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
