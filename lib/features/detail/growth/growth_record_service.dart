import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'growth_record.dart';

/// Local-only storage for growth profile and records (no backend endpoint exists yet).
class GrowthRecordService {
  static const _profileKey = 'growth_profile';
  static const _recordsKey = 'growth_records';

  static Future<GrowthProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    return GrowthProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> saveProfile(GrowthProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  static Future<List<GrowthRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final records = list.map((e) => GrowthRecord.fromJson(e as Map<String, dynamic>)).toList();
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  static Future<void> addRecord(GrowthRecord record) async {
    final records = await loadRecords();
    records.add(record);
    await _saveRecords(records);
  }

  static Future<void> deleteRecord(String id) async {
    final records = await loadRecords();
    records.removeWhere((r) => r.id == id);
    await _saveRecords(records);
  }

  static Future<void> _saveRecords(List<GrowthRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }
}
