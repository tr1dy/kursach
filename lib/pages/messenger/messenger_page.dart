import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/services/database_service.dart';
import 'package:flutter_project/services/chat_service.dart';
import 'package:flutter_project/models/chat_message.dart';
import 'chat_screen.dart';

class MessengerPage extends StatefulWidget {
  const MessengerPage({super.key});

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> {
  final DatabaseService _databaseService = DatabaseService();
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  late Stream<List<Map<String, dynamic>>> _activeChatsStream;
  final Map<String, Stream<List<ChatMessage>>> _chatStreams = {};

  @override
  void initState() {
    super.initState();
    _loadAllUsersForSearch();
    if (currentUser != null) {
      _activeChatsStream = _databaseService.getActiveChats(currentUser!.uid);
    }
  }

  Future<void> _loadAllUsersForSearch() async {
    final users = await _databaseService.getAllUsers();
    if (mounted) {
      setState(() {
        _allUsers = users;
      });
    }
  }

  Stream<List<ChatMessage>> _getChatStream(String chatId) {
    return _chatStreams.putIfAbsent(chatId, () => _chatService.getMessages(chatId));
  }

  void _filterUsers(String query) {
    setState(() {
      _searchResults = _allUsers
          .where((user) {
            final name = user['name']?.toString().toLowerCase() ?? "";
            final email = user['email']?.toString().toLowerCase() ?? "";
            return (name.contains(query.toLowerCase()) || email.contains(query.toLowerCase())) &&
                   user['uid'] != currentUser?.uid;
          })
          .toList();
    });
  }

  String _formatLastMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    if (timestamp.day == now.day && timestamp.month == now.month && timestamp.year == now.year) {
      return "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
    }
    return "${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return _buildUnauthorized();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _filterUsers,
                decoration: const InputDecoration(
                  hintText: 'Поиск...',
                  border: InputBorder.none,
                ),
              )
            : const Text('Сообщения', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isSearching 
                ? const Icon(Icons.close, color: textColor) 
                : SvgPicture.asset(AppIcons.search, height: 24),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isSearching ? _buildSearchResults() : _buildActiveChats(),
    );
  }

  Widget _buildActiveChats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _activeChatsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text("У вас пока нет активных чатов", style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => setState(() => _isSearching = true),
                  child: const Text("Найти студента"),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) => _buildUserTile(users[index]),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return const Center(child: Text("Введите имя для поиска", style: TextStyle(color: Colors.grey)));
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text("Никто не найден"));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _buildUserTile(_searchResults[index]),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> userData) {
    final String chatId = _chatService.getChatRoomId(currentUser!.uid, userData['uid']);
    final name = userData['name'] ?? userData['email']?.split('@')[0] ?? 'Студент';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: currentIcon.withOpacity(0.1),
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(color: currentIcon, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: StreamBuilder<List<ChatMessage>>(
        stream: _getChatStream(chatId),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final lastMsg = snapshot.data!.first;
            return Text(
              lastMsg.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            );
          }
          return Text(
            userData['email'] ?? "",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          );
        },
      ),
      trailing: StreamBuilder<List<ChatMessage>>(
        stream: _getChatStream(chatId),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return Text(
              _formatLastMessageTime(snapshot.data!.first.timestamp),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverId: userData['uid'],
              receiverName: name,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnauthorized() {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor, 
        elevation: 0, 
        centerTitle: true,
        title: const Text('Сообщения', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold))
      ),
      body: const Center(child: Text('Для просмотра требуется пройти авторизацию :)')),
    );
  }
}
