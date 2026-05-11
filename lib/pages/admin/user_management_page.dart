import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/teacher.dart';
import 'package:flutter_project/services/database_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Teacher> _teachers = [];
  List<String> _groups = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await _db.getAllUsers();
    final teachers = await _db.getTeachers();
    final groups = await _db.getGroupsList();
    if (mounted) {
      setState(() {
        _users = users;
        _filteredUsers = users;
        _teachers = teachers;
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _editUserRole(Map<String, dynamic> user) {
    String currentRole = user['role'] ?? 'student';
    String? selectedGroup = user['group'];
    String? selectedTeacherName = user['teacherName'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Роль: ${user['name']}", overflow: TextOverflow.ellipsis),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: currentRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text("Студент")),
                    DropdownMenuItem(value: 'teacher', child: Text("Преподаватель")),
                    DropdownMenuItem(value: 'admin', child: Text("Администратор")),
                  ],
                  onChanged: (val) {
                    setDialogState(() => currentRole = val!);
                  },
                  decoration: const InputDecoration(labelText: "Роль"),
                ),
                if (currentRole == 'student')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _groups.contains(selectedGroup) ? selectedGroup : null,
                    items: _groups.map((g) => DropdownMenuItem(
                      value: g, 
                      child: Text(g, overflow: TextOverflow.ellipsis)
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedGroup = val),
                    decoration: const InputDecoration(labelText: "Группа"),
                  ),
                if (currentRole == 'teacher')
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _teachers.any((t) => t.shortName == selectedTeacherName) ? selectedTeacherName : null,
                    items: _teachers.map((t) => DropdownMenuItem(
                      value: t.shortName, 
                      child: Text(
                        t.fullName.isNotEmpty ? t.fullName : t.shortName,
                        overflow: TextOverflow.ellipsis,
                      )
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedTeacherName = val),
                    decoration: const InputDecoration(labelText: "ФИО в расписании"),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
            ElevatedButton(
              onPressed: () async {
                showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                try {
                  await _db.updateUserRole(
                    user['uid'], 
                    role: currentRole,
                    group: currentRole == 'student' ? selectedGroup : null,
                    teacherName: currentRole == 'teacher' ? selectedTeacherName : null,
                  );
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    Navigator.pop(context); // Close dialog
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
                  }
                }
              },
              child: const Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Управление пользователями"),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: "Поиск пользователя...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final role = user['role'] ?? 'student';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(user['name'] ?? 'Без имени', overflow: TextOverflow.ellipsis),
                        subtitle: Text("${user['email']}\nРоль: $role"),
                        isThreeLine: true,
                        trailing: const Icon(Icons.manage_accounts),
                        onTap: () => _editUserRole(user),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
