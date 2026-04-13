import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedFilter {
  final String id;
  final String reportId;
  final String name;
  final String? type;
  final DateTime? startDate;
  final DateTime? endDate;

  SavedFilter({
    required this.id,
    required this.reportId,
    required this.name,
    this.type,
    this.startDate,
    this.endDate,
  });

  DateTimeRange? get dateRange =>
      startDate != null && endDate != null ? DateTimeRange(start: startDate!, end: endDate!) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'reportId': reportId,
        'name': name,
        'type': type,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };

  factory SavedFilter.fromJson(Map<String, dynamic> j) => SavedFilter(
        id: j['id'],
        reportId: j['reportId'],
        name: j['name'],
        type: j['type'],
        startDate: j['startDate'] != null ? DateTime.parse(j['startDate']) : null,
        endDate: j['endDate'] != null ? DateTime.parse(j['endDate']) : null,
      );
}

class SavedFiltersService {
  static const _key = 'report_saved_filters';

  static Future<List<SavedFilter>> load(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => SavedFilter.fromJson(jsonDecode(s)))
        .where((f) => f.reportId == reportId)
        .toList();
  }

  static Future<void> save(SavedFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final all = raw.map((s) => SavedFilter.fromJson(jsonDecode(s))).toList();
    all.removeWhere((f) => f.id == filter.id);
    all.add(filter);
    await prefs.setStringList(_key, all.map((f) => jsonEncode(f.toJson())).toList());
  }

  static Future<void> delete(String filterId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final all = raw
        .map((s) => SavedFilter.fromJson(jsonDecode(s)))
        .where((f) => f.id != filterId)
        .toList();
    await prefs.setStringList(_key, all.map((f) => jsonEncode(f.toJson())).toList());
  }
}
