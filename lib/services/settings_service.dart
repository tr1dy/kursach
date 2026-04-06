import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _groupKey = 'selected_group';
  static const String _subgroupKey = 'selected_subgroup';

  Future<void> saveGroup(String groupName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupKey, groupName);
  }

  Future<String?> getGroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_groupKey);
  }

  Future<void> saveSubgroup(int subgroup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_subgroupKey, subgroup);
  }

  Future<int> getSubgroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_subgroupKey) ?? 1;
  }
}
