import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/connectivity_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _db = Supabase.instance.client;

  // ── Token registration ──────────────────────────────────────────────────────
  Future<void> registerToken(String memberId, String token, {String platform = 'android'}) async {
    try {
      await ConnectivityService.instance.guard(() =>
          _db.from('device_tokens').upsert({
            'member_id': memberId,
            'token': token,
            'platform': platform,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'token'));
    } catch (e) {
      debugPrint('[NOTIFICATIONS] registerToken error: $e');
    }
  }

  // ── Inbox ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getInbox(String memberId, {int limit = 30}) async {
    final data = await ConnectivityService.instance.guard(() =>
        _db.from('notifications')
            .select()
            .eq('member_id', memberId)
            .order('created_at', ascending: false)
            .limit(limit));
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<int> getUnreadCount(String memberId) async {
    final data = await ConnectivityService.instance.guard(() =>
        _db.from('notifications')
            .select()
            .eq('member_id', memberId)
            .isFilter('read_at', null));
    return (data as List).length;
  }

  Future<void> markRead(String memberId, {String? notificationId, bool all = false}) async {
    if (all) {
      await _db.from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('member_id', memberId)
          .isFilter('read_at', null);
    } else if (notificationId != null) {
      await _db.from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId)
          .eq('member_id', memberId);
    }
  }

  // ── Preferences ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPreferences(String memberId) async {
    final data = await ConnectivityService.instance.guard(() =>
        _db.from('notification_preferences')
            .select()
            .eq('member_id', memberId)
            .maybeSingle());
    return (data as Map<String, dynamic>?) ?? {
      'deposits': true,
      'withdrawals': true,
      'loan_updates': true,
      'repayment_reminders': true,
      'dividends': true,
      'system_alerts': true,
    };
  }

  Future<void> setPreferences(String memberId, Map<String, bool> prefs) async {
    await ConnectivityService.instance.guard(() =>
        _db.from('notification_preferences').upsert({
          'member_id': memberId,
          ...prefs,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'member_id'));
  }
}
