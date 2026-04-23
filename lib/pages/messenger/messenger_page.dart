import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/services/database_service.dart';
import 'chat_screen.dart'; // Подключаем наш новый экран чата

class MessengerPage extends StatefulWidget {
  const MessengerPage({super.key});

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> {
  final DatabaseService _databaseService = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          title: const Text('Мессенджер', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: Text('Для просмотра требуется пройти авторизацию :)'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        title: const Text('Мессенджер', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      // FutureBuilder загружает список всех пользователей из БД один раз при открытии
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _databaseService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Пока нет других зарегистрированных студентов"));
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index];

              // Прячем самого себя из списка контактов
              if (userData['uid'] == currentUser!.uid) {
                return const SizedBox.shrink();
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: currentIcon,
                  child: Text(userData['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(userData['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(userData['email']),
                onTap: () {
                  // По клику открываем личный чат и передаем ID и Имя собеседника
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        receiverId: userData['uid'],
                        receiverName: userData['name'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}