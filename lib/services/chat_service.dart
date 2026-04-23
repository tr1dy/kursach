import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Генерируем уникальный ID комнаты для двух пользователей
  String getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort(); // Сортируем по алфавиту, чтобы порядок всегда был одинаковым
    return ids.join('_');
  }

  // Получаем поток сообщений для конкретного чата
  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // Свежие сверху для ListView
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data()))
        .toList());
  }

  // Отправка сообщения
  Future<void> sendMessage(String chatId, ChatMessage message) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());
  }
}