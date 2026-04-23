import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _isAdmin = false;
  bool _isLoadingAdminStatus = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isAdmin = await _db.isUserAdmin(user.uid);
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isLoadingAdminStatus = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingAdminStatus = false);
      }
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
          'Профиль', 
          style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)
        ),
      ),
      body: SingleChildScrollView( // Чтобы на маленьких экранах не обрезалось
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
            onPressed: () => Navigator.of(context).pushNamed('/login').then((_) {
              _checkAdminStatus();
              setState(() {});
            }),
            child: const Text('Войти'),
          ),
        ),
      ],
    );
  }

  Widget _buildUserView(User user) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, size: 50, color: currentIcon),
        ),
        const SizedBox(height: 20),
        Text(
          user.email ?? '', 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // СЕКЦИЯ ДЛЯ АДМИНА
        if (!_isLoadingAdminStatus && _isAdmin) ...[
          _buildAdminButton(),
          const SizedBox(height: 12),
        ],

        // ОБЫЧНЫЕ КНОПКИ (можно будет добавить настройки, смену группы и т.д.)
        _buildMenuButton(
          title: "Настройки аккаунта",
          icon: Icons.settings_outlined,
          onTap: () {},
        ),
        const SizedBox(height: 12),

        _buildMenuButton(
          title: "Выйти из аккаунта",
          icon: Icons.logout,
          color: Colors.redAccent,
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            _checkAdminStatus();
            setState(() {});
          },
        ),
      ],
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
        title: const Text(
          "Панель администратора", 
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.red),
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (c) => const AdminPanelPage())
        ),
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
