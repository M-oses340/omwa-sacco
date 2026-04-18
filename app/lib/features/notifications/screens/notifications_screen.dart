import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const NotificationsScreen({super.key, required this.member});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await NotificationService.instance.getInbox(widget.member['id']);
      if (mounted) setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await NotificationService.instance.markRead(widget.member['id'], all: true);
    await _load();
  }

  Future<void> _markOneRead(String id) async {
    await NotificationService.instance.markRead(widget.member['id'], notificationId: id);
    setState(() {
      final i = _notifications.indexWhere((n) => n['id'] == id);
      if (i != -1) _notifications[i] = {..._notifications[i], 'read_at': DateTime.now().toIso8601String()};
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = _notifications.where((n) => n['read_at'] == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Flexible(child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(10)),
              child: Text('$unread', style: TextStyle(color: cs.onError, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          if (unread > 0)
            TextButton(onPressed: _markAllRead, child: const Text('Mark all', style: TextStyle(fontSize: 12))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => NotificationPreferencesScreen(member: widget.member),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notifications_none_outlined, size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No notifications yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => _NotificationTile(
                      notification: _notifications[i],
                      onTap: () {
                        if (_notifications[i]['read_at'] == null) {
                          _markOneRead(_notifications[i]['id']);
                        }
                      },
                    ),
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = notification['read_at'] == null;
    final date = DateTime.tryParse(notification['created_at'] ?? '');
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final type = data['type'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: isUnread
              ? Border.all(color: _iconColor(type).withValues(alpha: 0.4), width: 1)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _iconColor(type).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(type), color: _iconColor(type), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    notification['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (date != null)
                  Text(
                    _timeAgo(date),
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                  ),
                if (isUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: _iconColor(type), shape: BoxShape.circle),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                notification['body'] ?? '',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.65)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'deposit' => Icons.arrow_downward,
        'withdrawal' || 'withdrawal_failed' => Icons.arrow_upward,
        'loan_applied' || 'loan_approved' || 'loan_disbursed' => Icons.account_balance_wallet_outlined,
        'repayment_reminder' => Icons.schedule_outlined,
        'dividend' => Icons.card_giftcard_outlined,
        _ => Icons.notifications_outlined,
      };

  Color _iconColor(String type) => switch (type) {
        'deposit' => Colors.green,
        'withdrawal' => Colors.orange,
        'withdrawal_failed' => Colors.red,
        'loan_approved' || 'loan_disbursed' => const Color(0xFF1565C0),
        'loan_applied' => Colors.purple,
        'repayment_reminder' => Colors.amber,
        'dividend' => const Color(0xFF00695C),
        _ => Colors.blueGrey,
      };

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Preferences screen ────────────────────────────────────────────────────────

class NotificationPreferencesScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  const NotificationPreferencesScreen({super.key, required this.member});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  Map<String, bool> _prefs = {};
  bool _loading = true;
  bool _saving = false;

  static const _prefLabels = {
    'deposits': ('Deposits', 'Notify when a deposit is confirmed', Icons.arrow_downward),
    'withdrawals': ('Withdrawals', 'Notify when a withdrawal is processed', Icons.arrow_upward),
    'loan_updates': ('Loan Updates', 'Application received, approved, disbursed', Icons.account_balance_wallet_outlined),
    'repayment_reminders': ('Repayment Reminders', 'Upcoming loan repayment due dates', Icons.schedule_outlined),
    'dividends': ('Dividends', 'Dividend payments and announcements', Icons.card_giftcard_outlined),
    'system_alerts': ('System Alerts', 'Important account and security alerts', Icons.security_outlined),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await NotificationService.instance.getPreferences(widget.member['id']);
    if (mounted) {
      setState(() {
        _prefs = {for (final k in _prefLabels.keys) k: raw[k] as bool? ?? true};
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await NotificationService.instance.setPreferences(widget.member['id'], _prefs);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Choose which notifications you receive.',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
                ),
                ..._prefLabels.entries.map((e) {
                  final (label, subtitle, icon) = e.value;
                  return SwitchListTile(
                    secondary: Icon(icon, color: cs.primary),
                    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
                    value: _prefs[e.key] ?? true,
                    onChanged: (v) => setState(() => _prefs[e.key] = v),
                  );
                }),
              ],
            ),
    );
  }
}
