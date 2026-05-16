import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/pages/admin/admin_panel_page.dart';
import '../../services/database_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _db.getUserData(user.uid);
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'admin': return 'Администратор';
      case 'teacher': return 'Преподаватель';
      case 'student': return 'Студент';
      default: return 'Пользователь';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Мой профиль', 
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: user == null ? _buildGuestView() : _buildUserView(user),
            ),
          ),
    );
  }

  Widget _buildGuestView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        const Icon(Icons.account_circle_outlined, size: 100, color: textColor),
        const SizedBox(height: 20),
        const Text('Вы не авторизованы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/login').then((_) => _loadUserData()),
            child: const Text('Войти в систему'),
          ),
        ),
      ],
    );
  }

  Widget _buildUserView(User user) {
    final role = _userData?['role'] ?? 'student';
    final isAdmin = role == 'admin' || (_userData?['isAdmin'] ?? false);
    final fullName = _userData?['name'] ?? 'ФИО не указано';

    return Column(
      children: [
        // АВАТАРКА (Заглушка)
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 70, color: currentIcon.withOpacity(0.8)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // ОСНОВНАЯ ИНФО
        Text(
          fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: currentIcon.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getRoleName(role),
            style: const TextStyle(color: currentIcon, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        
        const SizedBox(height: 30),

        // КАРТОЧКИ С ДАННЫМИ
        _buildDetailItem("Электронная почта", user.email ?? '', Icons.email_outlined),
        
        if (role == 'student')
          _buildDetailItem("Группа", _userData?['group'] ?? "Не привязана", Icons.group_outlined),
        
        if (role == 'teacher')
          _buildDetailItem("Связанный профиль", _userData?['teacherName'] ?? "Не выбран", Icons.school_outlined),

        const SizedBox(height: 24),

        // КНОПКИ ДЕЙСТВИЙ
        if (isAdmin) ...[
          _buildAdminButton(),
          const SizedBox(height: 12),
        ],

        _buildMenuButton(
          title: "Выйти из аккаунта",
          icon: Icons.logout,
          color: Colors.redAccent,
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            _loadUserData();
          },
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(subtitle, style: const TextStyle(color: Colors.orange, fontSize: 10)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
        title: const Text("Панель администратора", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right, color: Colors.red),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminPanelPage())),
      ),
    );
  }

  Widget _buildMenuButton({required String title, required IconData icon, required VoidCallback onTap, Color color = Colors.black}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
