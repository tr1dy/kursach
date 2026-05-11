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
  TextEditingController nameTextInputController = TextEditingController(); 
  TextEditingController passwordTextInputController = TextEditingController();
  TextEditingController passwordTextRepeatInputController = TextEditingController();
  
  String? selectedGroup;
  List<String> groups = [];
  bool isLoadingGroups = true;

  final formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final list = await _databaseService.getGroupsList();
      if (mounted) {
        setState(() {
          groups = list;
          isLoadingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingGroups = false);
    }
  }

  @override
  void dispose() {
    emailTextInputController.dispose();
    nameTextInputController.dispose();
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

    if (selectedGroup == null) {
      SnackBarService.showSnackBar(context, 'Пожалуйста, выберите группу из списка', true);
      return;
    }

    if (passwordTextInputController.text != passwordTextRepeatInputController.text) {
      SnackBarService.showSnackBar(context, 'Пароли должны совпадать', true);
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTextInputController.text.trim(),
        password: passwordTextInputController.text.trim(),
      );

      if (userCredential.user != null) {
        await _databaseService.createUserProfile(
          userCredential.user!.uid,
          userCredential.user!.email!,
          nameTextInputController.text.trim(),
          role: 'student',
          group: selectedGroup,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameTextInputController,
                validator: (value) =>
                    value != null && value.length < 2 ? 'Введите ваше ФИО' : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'ФИО',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
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
              
              if (isLoadingGroups)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ))
              else if (groups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    "Список групп еще не загружен администратором. Пожалуйста, зайдите позже.",
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  isExpanded: true, // Позволяет контенту занимать всю ширину
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Выберите вашу группу',
                  ),
                  value: selectedGroup,
                  items: groups.map((g) => DropdownMenuItem(
                    value: g, 
                    child: Text(
                      g, 
                      overflow: TextOverflow.ellipsis, // Предотвращает overflow
                    )
                  )).toList(),
                  onChanged: (val) => setState(() => selectedGroup = val),
                  validator: (val) => val == null ? 'Обязательное поле' : null,
                ),
              
              const SizedBox(height: 10),
              const Text(
                "ℹ️ Роль преподавателя назначается администратором после регистрации.",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
              
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordTextInputController,
                obscureText: isHiddenPassword,
                validator: (value) => value != null && value.length < 6 ? 'Минимум 6 символов' : null,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(), 
                  hintText: 'Пароль',
                  suffixIcon: IconButton(
                    icon: Icon(isHiddenPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: togglePasswordView,
                  )
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordTextRepeatInputController,
                obscureText: isHiddenPassword,
                validator: (value) => value != null && value.length < 6 ? 'Минимум 6 символов' : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(), 
                  hintText: 'Повторите пароль',
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: groups.isEmpty ? null : signUp,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
