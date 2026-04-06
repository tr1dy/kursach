import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/design/colors.dart';

class MessengerPage extends StatelessWidget {
  const MessengerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Мессенджер',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: SvgPicture.asset(AppIcons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(AppIcons.menu),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: backgroundColor,
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 16),
          ),
          Expanded(
            child: Center(
              child: (user == null)
                  ? const Text('Для просмотра требуется пройти авторизацию :)')
                  : const Text('Супер, ты авторизовался!\nНо мессенджера все равно пока нет :)'),
            ),
          ),
        ],
      ),
    );
  }
}
