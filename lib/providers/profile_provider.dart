import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_profile_model.dart';

class ProfileProvider extends ChangeNotifier {
  static const _activeIdKey = 'active_profile_id';
  static const _customKey = 'custom_profiles';

  String _activeId = ShiftProfileModel.standard.id;
  List<ShiftProfileModel> _custom = [];

  List<ShiftProfileModel> get allProfiles => [
        ShiftProfileModel.standard,
        ShiftProfileModel.halfDay,
        ..._custom,
      ];

  ShiftProfileModel get activeProfile => allProfiles.firstWhere(
        (p) => p.id == _activeId,
        orElse: () => ShiftProfileModel.standard,
      );

  Future<void> initialize() async {
    final p = await SharedPreferences.getInstance();
    _activeId = p.getString(_activeIdKey) ?? ShiftProfileModel.standard.id;
    final raw = p.getStringList(_customKey) ?? [];
    _custom = raw
        .map((s) =>
            ShiftProfileModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> setActiveProfile(String id) async {
    _activeId = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(_activeIdKey, id);
    notifyListeners();
  }

  Future<void> addProfile(ShiftProfileModel profile) async {
    _custom.add(profile);
    await _persist();
    notifyListeners();
  }

  Future<void> updateProfile(ShiftProfileModel profile) async {
    final idx = _custom.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _custom[idx] = profile;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    _custom.removeWhere((p) => p.id == id);
    if (_activeId == id) {
      _activeId = ShiftProfileModel.standard.id;
      final p = await SharedPreferences.getInstance();
      await p.setString(_activeIdKey, _activeId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _customKey,
      _custom.map((pr) => jsonEncode(pr.toJson())).toList(),
    );
  }
}
