import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/design/colors.dart';
import '../../services/database_service.dart';
import '../../services/excel_parser.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  String _status = "";

  Future<void> _uploadAllSchedules() async {
    setState(() {
      _isUploading = true;
      _status = "Начинаю загрузку...";
    });

    try {
      final parser = ExcelParser();
      final db = DatabaseService();

      final groups = await parser.getGroups();
      await db.saveGroupsList(groups);
      
      int count = 0;
      for (String group in groups) {
        setState(() => _status = "Загрузка (${count + 1}/${groups.length}): $group");

        final lessons = await parser.parseSchedule(group, subgroup: 1, clearCache: true);
        await db.saveSchedule(group, lessons);
        
        count++;
      }

      setState(() => _status = "Все расписания ($count шт.) загружены успешно!");
    } catch (e) {
      setState(() => _status = "Ошибка: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Профиль', 
          style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)
        ),
      ),
      body: Center(
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
        const Icon(Icons.account_circle_outlined, size: 100, color: textColor),
        const SizedBox(height: 20),
        const Text('Вы не авторизованы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pushNamed('/login').then((_) => setState(() {})),
          child: const Text('Войти'),
        ),
      ],
    );
  }

  Widget _buildUserView(User user) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: primaryColor,
          child: Icon(Icons.person, size: 50, color: currentIcon),
        ),
        const SizedBox(height: 20),
        Text(
          user.email ?? '', 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        
        if (_isUploading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 10),
          Text(_status, textAlign: TextAlign.center),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadAllSchedules,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Обновить всё расписание в БД"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_status.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(_status, style: const TextStyle(color: Colors.green), textAlign: TextAlign.center),
          ),
        ],

        const SizedBox(height: 20),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            setState(() {});
          },
          child: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}
