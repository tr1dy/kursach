import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/pages/main_page.dart';
import 'package:flutter_project/pages/auth/login_page.dart';
import 'package:flutter_project/pages/auth/signup_page.dart';
import 'package:flutter_project/pages/auth/verify_email_screen.dart';
import 'package:flutter_project/pages/profile/account_screen.dart';
import 'package:flutter_project/pages/auth/reset_password_screen.dart';
import 'package:flutter_project/services/firebase_streem.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KFU App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/': (context) => const FirebaseStream(),
        '/home': (context) => const MainPage(),
        '/account': (context) => const AccountScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/verify_email': (context) => const VerifyEmailScreen(),
      },
      initialRoute: '/',
    );
  }
}
