import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/services/snack_bar.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter_project/services/database_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreen();
}

class _SignUpScreen extends State<SignUpScreen> {
  bool isHiddenPassword = true;
  TextEditingController emailTextInputController = TextEditingController();
  TextEditingController passwordTextInputController = TextEditingController();
  TextEditingController passwordTextRepeatInputController =
  TextEditingController();
  final formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void dispose() {
    emailTextInputController.dispose();
    passwordTextInputController.dispose();
    passwordTextRepeatInputController.dispose();
    super.dispose();
  }

  void togglePasswordView() {
    setState(() {
      isHiddenPassword = !isHiddenPassword;
    });
  }

  Future<void> signUp() async {
    final isValid = formKey.currentState!.validate();
    if (!isValid) return;

    if (passwordTextInputController.text != passwordTextRepeatInputController.text) {
      SnackBarService.showSnackBar(context, 'Пароли должны совпадать', true);
      return;
    }

    try {
      // 1. Создаем пользователя в Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextInputController.text.trim(),
        password: passwordTextInputController.text.trim(),
      );

      // 2. Создаем профиль в Firestore
      if (userCredential.user != null) {
        await _databaseService.createUserProfile(
          userCredential.user!.uid,
          userCredential.user!.email!,
        );
      }

      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on FirebaseAuthException catch (e) {
      String message = 'Произошла ошибка';
      if (e.code == 'email-already-in-use') message = 'Email уже занят';
      SnackBarService.showSnackBar(context, message, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailTextInputController,
                validator: (value) =>
                    value != null && !EmailValidator.validate(value)
                        ? 'Введите корректный Email'
                        : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Email',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordTextInputController,
                obscureText: isHiddenPassword,
                validator: (value) => value != null && value.length < 6 ? 'Минимум 6 символов' : null,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Пароль'),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordTextRepeatInputController,
                obscureText: isHiddenPassword,
                validator: (value) => value != null && value.length < 6 ? 'Минимум 6 символов' : null,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Повторите пароль'),
              ),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: signUp, child: const Text('Зарегистрироваться')),
            ],
          ),
        ),
      ),
    );
  }
}
