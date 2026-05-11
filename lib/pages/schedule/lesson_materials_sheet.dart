import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/lesson_material.dart';
import 'package:flutter_project/models/user_note.dart';
import 'package:flutter_project/services/database_service.dart';

class LessonMaterialsSheet extends StatefulWidget {
  final String lessonKey;
  final String lessonName;
  final bool canEdit; // true для преподавателей (правка материалов)

  const LessonMaterialsSheet({
    super.key,
    required this.lessonKey,
    required this.lessonName,
    required this.canEdit,
  });

  @override
  State<LessonMaterialsSheet> createState() => _LessonMaterialsSheetState();
}

class _LessonMaterialsSheetState extends State<LessonMaterialsSheet> {
  final DatabaseService _db = DatabaseService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  LessonMaterial? _material;
  UserNote? _note;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Загружаем материалы от преподавателя
    final material = await _db.getLessonMaterial(widget.lessonKey);
    
    // Загружаем личную заметку студента
    UserNote? note;
    if (_currentUser != null) {
      note = await _db.getNote(_currentUser!.uid, widget.lessonKey);
    }

    if (mounted) {
      setState(() {
        _material = material;
        _materialController.text = material?.text ?? "";
        _note = note;
        _noteController.text = note?.text ?? "";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMaterial() async {
    final newMaterial = LessonMaterial(
      id: widget.lessonKey,
      lessonKey: widget.lessonKey,
      text: _materialController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await _db.saveLessonMaterial(newMaterial);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Материалы пары обновлены")),
      );
    }
  }

  Future<void> _saveNote() async {
    if (_currentUser == null) return;
    
    await _db.saveNote(
      _currentUser!.uid,
      widget.lessonKey,
      _noteController.text.trim(),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Личная заметка сохранена")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.lessonName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 15),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ))
            else ...[
              // РАЗДЕЛ: МАТЕРИАЛЫ ПРЕПОДАВАТЕЛЯ
              const Text("Материалы и задания:", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (widget.canEdit)
                Column(
                  children: [
                    TextField(
                      controller: _materialController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Введите задание для студентов...",
                        filled: true,
                        fillColor: backgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveMaterial,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text("Обновить для всех"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentIcon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _material?.text.isEmpty ?? true ? "Преподаватель пока не добавил материалы" : _material!.text,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 10),

              // РАЗДЕЛ: ЛИЧНЫЕ ЗАМЕТКИ СТУДЕНТА (не видны преподавателю в режиме правки)
              if (!widget.canEdit) ...[
                const Text("Мои личные заметки:", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "например, 'взять тетрадь'...",
                    filled: true,
                    fillColor: Colors.amber.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15), 
                      borderSide: const BorderSide(color: Colors.amber, width: 0.5)
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saveNote,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Сохранить для себя"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown,
                      side: const BorderSide(color: Colors.brown),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
