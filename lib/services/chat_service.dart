import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Генерируем уникальный ID комнаты для двух пользователей
  String getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort(); // Сортируем по алфавиту
    return ids.join('_');
  }

  // Получаем поток сообщений
  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data()))
        .toList());
  }

  // Отправка сообщения с инициализацией чата
  Future<void> sendMessage(String chatId, ChatMessage message, List<String> participants) async {
    // 1. Создаем/обновляем заголовок чата, чтобы он появился в списке активных
    await _db.collection('chats').doc(chatId).set({
      'participants': participants,
      'lastMessage': message.text,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Добавляем само сообщение
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());
  }
}
