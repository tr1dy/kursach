import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/pages/main_page.dart';
import 'package:flutter_project/pages/auth/verify_email_screen.dart';

class FirebaseStream extends StatelessWidget {
  const FirebaseStream({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasError) {
          return const Scaffold(
              body: Center(child: Text('Что-то пошло не так!')));
        }
        
        if (snapshot.hasData) {
          // временно отключаем проверку подтверждения почты для тестов
          /*
          final user = snapshot.data!;
          if (!user.emailVerified) {
            return const VerifyEmailScreen();
          }
          */
          return const MainPage();
        }

        return const MainPage();
      },
    );
  }
}
