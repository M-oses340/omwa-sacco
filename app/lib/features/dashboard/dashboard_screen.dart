import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/bloc/auth_bloc.dart';
// FIX: Using the filename 'deposit_screen.dart' to match your directory
import '../transactions/screens/deposit_screen.dart'; 
import '../transactions/screens/withdraw_screen.dart';
import '../transactions/screens/transfer_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/connectivity_service.dart';
import '../loans/screens/loans_screen.dart';

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
  bool _balanceVisible = false;

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
                .limit(20),
          ]));

      if (mounted) {
        setState(() {
          _bosa = results[0] as Map<String, dynamic>?;
          _fosa = results[1] as Map<String, dynamic>?;
          _transactions = (results[2] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.member['full_name'] ?? 'Member';
    final memberNumber = widget.member['member_number'] ?? '';
    final firstName = name.split(' ').first;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs, firstName, memberNumber, name),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _AccountCard(
                          title: 'BOSA',
                          subtitle: 'Savings & Shares',
                          balance: _bosa?['savings_balance'],
                          shares: _bosa?['shares_balance'],
                          accountNumber: _bosa?['account_number'],
                          color: AppColors.primary,
                          balanceVisible: _balanceVisible,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AccountCard(
                          title: 'FOSA',
                          subtitle: 'Current Account',
                          balance: _fosa?['balance'],
                          accountNumber: _fosa?['account_number'],
                          color: AppColors.fosaGreen,
                          balanceVisible: _balanceVisible,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickAction(
                          icon: Icons.arrow_downward,
                          label: 'Deposit',
                          color: Colors.green,
                          onTap: () async {
                            final refreshed = await showDepositSheet(context, widget.member);
                            if (refreshed == true) {
                              await Future.delayed(const Duration(seconds: 2));
                              _loadData();
                            }
                          }),
                      _QuickAction(
                          icon: Icons.arrow_upward,
                          label: 'Withdraw',
                          color: Colors.orange,
                          onTap: () async {
                            final refreshed = await showWithdrawSheet(context, widget.member);
                            if (mounted && refreshed == true) _loadData();
                          }),
                      _QuickAction(
                          icon: Icons.swap_horiz,
                          label: 'Transfer',
                          color: Colors.blue,
                          onTap: () async {
                            final refreshed = await showTransferSheet(context, widget.member);
                            if (refreshed == true) _loadData();
                          }),
                      _QuickAction(
                          icon: Icons.account_balance_wallet,
                          label: 'Loans',
                          color: Colors.purple,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoansScreen(member: widget.member)))),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _transactions.isEmpty
                        ? _buildEmptyState(cs)
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) => _TransactionTile(tx: _transactions[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, String firstName, String memberNumber, String fullName) {
    return Container(
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance, color: cs.onPrimary, size: 22),
                      const SizedBox(width: 8),
                      Text('Omwa Sacco', style: TextStyle(color: cs.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: cs.onPrimary),
                        onPressed: () => setState(() => _balanceVisible = !_balanceVisible),
                      ),
                      IconButton(
                        icon: Icon(Icons.logout, color: cs.onPrimary),
                        onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _GravatarAvatar(
                    photoUrl: widget.member['profile_photo_url'] as String?,
                    email: widget.member['email'] as String? ?? '',
                    fallback: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'M',
                    radius: 28,
                    onPrimaryColor: cs.onPrimary,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, $firstName 👋', style: TextStyle(color: cs.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Member #$memberNumber', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.6), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text('No transactions yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 120, cs: cs)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 120, cs: cs)),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _SkeletonBox(height: 64, cs: cs))),
        ],
      ),
    );
  }
}

// Support Widgets 
class _SkeletonBox extends StatelessWidget {
  final double height;
  final ColorScheme cs;
  const _SkeletonBox({required this.height, required this.cs});
  @override
  Widget build(BuildContext context) {
    return Container(height: height, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)));
  }
}

class _AccountCard extends StatelessWidget {
  final String title, subtitle;
  final dynamic balance, shares;
  final String? accountNumber;
  final Color color;
  final bool balanceVisible;
  const _AccountCard({required this.title, required this.subtitle, this.balance, this.shares, this.accountNumber, required this.color, this.balanceVisible = true});
  @override
  Widget build(BuildContext context) {
    String fmt(dynamic val) => double.tryParse(val.toString())?.toStringAsFixed(2) ?? '0.00';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          if (balance != null) ...[
            const Text('Balance', style: TextStyle(color: Colors.white60, fontSize: 11)),
            Text(balanceVisible ? 'KES ${fmt(balance)}' : 'KES ••••••', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
          if (shares != null) ...[
            const SizedBox(height: 4),
            Text(balanceVisible ? 'Shares: KES ${fmt(shares)}' : 'Shares: KES ••••', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
          if (accountNumber != null) ...[
            const SizedBox(height: 6),
            Text(accountNumber!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 26)),
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
    final status = tx['status'] ?? 'completed';
    final isCredit = ['deposit', 'loan_disbursement', 'dividend'].contains(type);
    final date = DateTime.tryParse(tx['created_at'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (date != null) Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isCredit ? '+' : '-'} KES ${amount.toStringAsFixed(2)}', style: TextStyle(color: isCredit ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
              if (status != 'completed')
                Text(status.toUpperCase(), style: TextStyle(fontSize: 9, color: status == 'pending' ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GravatarAvatar extends StatefulWidget {
  final String? photoUrl;
  final String email;
  final String fallback;
  final double radius;
  final Color onPrimaryColor;
  const _GravatarAvatar({this.photoUrl, required this.email, required this.fallback, required this.radius, required this.onPrimaryColor});
  @override
  State<_GravatarAvatar> createState() => _GravatarAvatarState();
}

class _GravatarAvatarState extends State<_GravatarAvatar> {
  bool _imageError = false;
  String _gravatarUrl(String email) {
    final hash = md5.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return 'https://www.gravatar.com/avatar/$hash?s=200&d=identicon';
  }
  @override
  Widget build(BuildContext context) {
    final imageUrl = !_imageError ? (widget.photoUrl ?? _gravatarUrl(widget.email)) : null;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.onPrimaryColor.withValues(alpha: 0.2),
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
      onBackgroundImageError: imageUrl != null ? (_, __) => setState(() => _imageError = true) : null,
      child: (imageUrl == null || _imageError) ? Text(widget.fallback, style: TextStyle(color: widget.onPrimaryColor, fontWeight: FontWeight.bold)) : null,
    );
  }
}