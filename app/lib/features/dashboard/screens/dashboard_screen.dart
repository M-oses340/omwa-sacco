import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../fosa/deposit/screens/deposit_screen.dart';
import '../../fosa/withdraw/screens/withdraw_screen.dart';
import '../../fosa/transfer/screens/transfer_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../bosa/loans/screens/loans_screen.dart';
import '../../fosa/pay_bills/screens/pay_bills_screen.dart';
import '../../fosa/airtime/screens/airtime_screen.dart';
import '../../fosa/ratiba/screens/ratiba_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/services/notification_service.dart';
import '../../transactions/screens/transactions_screen.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../../transactions/bloc/transactions_bloc.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const DashboardScreen({super.key, required this.member});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _balanceVisible = false;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationService.instance.getUnreadCount(widget.member['id']);
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {}
  }

  void _refresh(BuildContext context) {
    context.read<DashboardBloc>().add(DashboardDataLoaded(memberId: widget.member['id']));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.member['full_name'] ?? 'Member';
    final memberNumber = widget.member['member_number'] ?? '';
    final firstName = name.split(' ').first;

    return BlocProvider(
      create: (_) => DashboardBloc()..add(DashboardDataLoaded(memberId: widget.member['id'])),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(cs, firstName, memberNumber, name),
            Expanded(
              child: BlocConsumer<DashboardBloc, DashboardState>(
                listener: (context, state) {
                  if (state is DashboardError) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.message),
                      backgroundColor: cs.error,
                    ));
                  }
                },
                builder: (context, state) {
                  if (state is DashboardLoading || state is DashboardInitial) {
                    return _buildSkeleton(cs);
                  }

                  final bosa = state is DashboardSuccess ? state.bosa : null;
                  final fosa = state is DashboardSuccess ? state.fosa : null;
                  final txs = state is DashboardSuccess ? state.recentTransactions : <Map<String, dynamic>>[];

                  return RefreshIndicator(
                    onRefresh: () async => _refresh(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: _AccountCard(
                                    title: 'BOSA',
                                    subtitle: 'Savings & Shares',
                                    balance: bosa?['savings_balance'],
                                    shares: bosa?['shares_balance'],
                                    accountNumber: bosa?['account_number'],
                                    color: AppColors.primary,
                                    balanceVisible: _balanceVisible,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _AccountCard(
                                    title: 'FOSA',
                                    subtitle: 'Current Account',
                                    balance: fosa?['balance'],
                                    accountNumber: fosa?['account_number'],
                                    color: AppColors.fosaGreen,
                                    balanceVisible: _balanceVisible,
                                  ),
                                ),
                              ]),
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
                                      final bloc = context.read<DashboardBloc>();
                                      final refreshed = await showDepositSheet(context, widget.member);
                                      if (refreshed == true && mounted) {
                                        await Future.delayed(const Duration(seconds: 2));
                                        bloc.add(DashboardDataLoaded(memberId: widget.member['id']));
                                      }
                                    },
                                  ),
                                  _QuickAction(
                                    icon: Icons.arrow_upward,
                                    label: 'Withdraw',
                                    color: Colors.orange,
                                    onTap: () async {
                                      final bloc = context.read<DashboardBloc>();
                                      final refreshed = await showWithdrawSheet(context, widget.member);
                                      if (refreshed == true && mounted) bloc.add(DashboardDataLoaded(memberId: widget.member['id']));
                                    },
                                  ),
                                  _QuickAction(
                                    icon: Icons.swap_horiz,
                                    label: 'Transfer',
                                    color: Colors.blue,
                                    onTap: () async {
                                      final bloc = context.read<DashboardBloc>();
                                      final refreshed = await showTransferSheet(context, widget.member);
                                      if (refreshed == true && mounted) bloc.add(DashboardDataLoaded(memberId: widget.member['id']));
                                    },
                                  ),
                                  _QuickAction(
                                    icon: Icons.account_balance_wallet,
                                    label: 'Loans',
                                    color: Colors.purple,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoansScreen(member: widget.member))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _QuickAction(
                                    icon: Icons.receipt_long,
                                    label: 'Pay Bills',
                                    color: Colors.teal,
                                    onTap: () async {
                                      final bloc = context.read<DashboardBloc>();
                                      final refreshed = await showPayBillsSheet(context, widget.member);
                                      if (refreshed == true && mounted) bloc.add(DashboardDataLoaded(memberId: widget.member['id']));
                                    },
                                  ),
                                  _QuickAction(
                                    icon: Icons.schedule,
                                    label: 'Ratiba',
                                    color: Colors.indigo,
                                    onTap: () => showRatibaSheet(context, widget.member),
                                  ),
                                  _QuickAction(
                                    icon: Icons.sim_card,
                                    label: 'Airtime',
                                    color: Colors.red,
                                    onTap: () async {
                                      final bloc = context.read<DashboardBloc>();
                                      final refreshed = await showBuyAirtimeSheet(context, widget.member);
                                      if (refreshed == true && mounted) bloc.add(DashboardDataLoaded(memberId: widget.member['id']));
                                    },
                                  ),
                                  _QuickAction(
                                    icon: Icons.bar_chart,
                                    label: 'Reports',
                                    color: Colors.brown,
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(member: widget.member))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => TransactionsBloc()
                                        ..add(TransactionsLoaded(memberId: widget.member['id'])),
                                      child: TransactionsScreen(member: widget.member),
                                    ),
                                  ),
                                ),
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                        ),
                        ...txs.map((tx) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TransactionTile(tx: tx),
                        )),
                        if (txs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Column(children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                                const SizedBox(height: 8),
                                Text('No transactions yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
                  Row(children: [
                    Icon(Icons.account_balance, color: cs.onPrimary, size: 22),
                    const SizedBox(width: 8),
                    Text('Omwa Sacco', style: TextStyle(color: cs.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  Row(children: [
                    IconButton(
                      icon: Icon(_balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: cs.onPrimary),
                      onPressed: () => setState(() => _balanceVisible = !_balanceVisible),
                    ),
                    Stack(children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined, color: cs.onPrimary),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(member: widget.member)));
                          _loadUnreadCount();
                        },
                      ),
                      if (_unreadNotifications > 0)
                        Positioned(
                          right: 8, top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
                            child: Text('$_unreadNotifications', style: TextStyle(color: cs.onError, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ]),
                    IconButton(
                      icon: Icon(Icons.logout, color: cs.onPrimary),
                      onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 20),
              Row(children: [
                _GravatarAvatar(
                  photoUrl: widget.member['profile_photo_url'] as String?,
                  email: widget.member['email'] as String? ?? '',
                  fallback: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'M',
                  radius: 28,
                  onPrimaryColor: cs.onPrimary,
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, $firstName 👋', style: TextStyle(color: cs.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Member #$memberNumber', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.6), fontSize: 12)),
                ]),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _SkeletonBox(height: 120, cs: cs)),
            const SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 120, cs: cs)),
          ]),
          const SizedBox(height: 20),
          ...List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _SkeletonBox(height: 64, cs: cs))),
        ],
      ),
    );
  }
}

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
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]),
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
