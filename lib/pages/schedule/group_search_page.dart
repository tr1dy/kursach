import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../design/colors.dart';

class GroupSearchPage extends StatefulWidget {
  const GroupSearchPage({super.key});

  @override
  State<GroupSearchPage> createState() => _GroupSearchPageState();
}

class _GroupSearchPageState extends State<GroupSearchPage> {
  final DatabaseService _db = DatabaseService();
  final SettingsService _settings = SettingsService();
  
  List<String> _allGroups = [];
  List<String> _filteredGroups = [];
  bool _isLoading = true;
  String _searchQuery = "";
  int _selectedSubgroup = 1;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    // Теперь загружаем список групп из Firestore
    final groups = await _db.getGroupsList();
    final currentSubgroup = await _settings.getSubgroup();
    setState(() {
      _allGroups = groups;
      _filteredGroups = groups;
      _selectedSubgroup = currentSubgroup;
      _isLoading = false;
    });
  }

  void _filterGroups(String query) {
    setState(() {
      _searchQuery = query;
      _filteredGroups = _allGroups
          .where((g) => g.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _selectGroup(String groupName) async {
    await _settings.saveGroup(groupName);
    await _settings.saveSubgroup(_selectedSubgroup);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Выбор группы', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterGroups,
              decoration: InputDecoration(
                hintText: 'Поиск группы (например, 09-332)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allGroups.isEmpty 
                  ? const Center(child: Text("Список групп пуст.\nЗагрузите его в профиле (Admin)", textAlign: TextAlign.center))
                  : ListView.builder(
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = _filteredGroups[index];
                      return ListTile(
                        title: Text(group),
                        onTap: () => _selectGroup(group),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
