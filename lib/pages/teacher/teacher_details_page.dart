import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/models/teacher.dart';
import 'package:flutter_project/models/teacher_review.dart';
import 'package:flutter_project/pages/teacher/teacher_schedule_page.dart';
import 'package:flutter_project/services/database_service.dart';

class TeacherDetailsPage extends StatefulWidget {
  final Teacher teacher;

  const TeacherDetailsPage({super.key, required this.teacher});

  @override
  State<TeacherDetailsPage> createState() => _TeacherDetailsPageState();
}

class _TeacherDetailsPageState extends State<TeacherDetailsPage> {
  final DatabaseService _db = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _hasReviewed = false;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (currentUser != null) {
      final hasReviewed = await _db.hasUserReviewedTeacher(widget.teacher.id, currentUser!.uid);
      final userData = await _db.getUserData(currentUser!.uid);
      if (mounted) {
        setState(() {
          _hasReviewed = hasReviewed;
          _isAdmin = userData?['isAdmin'] ?? false;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkReviewStatus() async {
    if (currentUser != null) {
      final hasReviewed = await _db.hasUserReviewedTeacher(widget.teacher.id, currentUser!.uid);
      if (mounted) {
        setState(() {
          _hasReviewed = hasReviewed;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  void _showAddReviewSheet() {
    double selectedRating = 5;
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ваш отзыв", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setSheetState(() => selectedRating = index + 1.0),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Напишите честный отзыв...",
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (textController.text.trim().isEmpty) return;
                    
                    final review = TeacherReview(
                      id: '',
                      teacherId: widget.teacher.id,
                      userId: currentUser!.uid,
                      userName: currentUser!.email?.split('@')[0] ?? "Студент",
                      rating: selectedRating,
                      text: textController.text.trim(),
                      timestamp: DateTime.now(),
                    );

                    await _db.saveTeacherReview(widget.teacher.id, review);
                    if (mounted) {
                      Navigator.pop(context); // Закрываем окно отзыва
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Отзыв успешно опубликован")),
                      );
                      _checkReviewStatus();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentIcon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Опубликовать"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        centerTitle: true,
        title: Text(widget.teacher.shortName, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                _buildReviewsList(),
              ],
            ),
          ),
      floatingActionButton: (!_hasReviewed && currentUser != null && !_isLoading) 
          ? FloatingActionButton.extended(
              onPressed: _showAddReviewSheet,
              backgroundColor: currentIcon,
              label: const Text("Оставить отзыв", style: TextStyle(color: Colors.white)),
              icon: const Icon(Icons.rate_review, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: currentIcon.withOpacity(0.1),
            child: Text(
              widget.teacher.fullName.isNotEmpty ? widget.teacher.fullName[0].toUpperCase() : "?",
              style: const TextStyle(color: currentIcon, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            widget.teacher.fullName.isNotEmpty ? widget.teacher.fullName : widget.teacher.shortName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (widget.teacher.department.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(widget.teacher.department, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                widget.teacher.rating > 0 ? widget.teacher.rating.toStringAsFixed(1) : "Нет рейтинга",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeacherSchedulePage(teacher: widget.teacher),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text("Посмотреть расписание"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<List<TeacherReview>>(
      stream: _db.getTeacherReviews(widget.teacher.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                Icon(Icons.message_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text("Отзывов пока нет. Будьте первым!", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final reviews = snapshot.data!;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ...List.generate(5, (i) => Icon(
                            Icons.star,
                            size: 14,
                            color: i < review.rating ? Colors.amber : Colors.grey.shade300,
                          )),
                          if (_isAdmin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDeleteReview(review.id),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(review.text),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(review.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteReview(String reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить отзыв?"),
        content: const Text("Это действие нельзя будет отменить."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          TextButton(
            onPressed: () async {
              await _db.deleteTeacherReview(widget.teacher.id, reviewId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Отзыв удален")));
              }
            },
            child: const Text("Удалить", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
