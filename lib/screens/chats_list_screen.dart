import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/firebase/group_chat_service.dart';
import 'package:whatsup/firebase/messaging_service.dart';
import 'package:whatsup/screens/seach_screen.dart';
import 'package:whatsup/widgets/chat_list_item.dart';
import 'package:whatsup/widgets/settings_menu_icon.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key, required this.contacts});

  final List<Map<dynamic, dynamic>> contacts;

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  bool loading = false;
  final Map<String, Map<dynamic, dynamic>?> _entityCache = {};
  final Map<String, Future<Map<dynamic, dynamic>?>> _entityFutureCache = {};
  @override
  void initState() {
    super.initState();
    MessagingService.initializeMesseging(context);
  }

  Future<Map<dynamic, dynamic>?> _getEntity(String id, bool isGroup) {
    if (_entityCache.containsKey(id)) {
      return Future.value(_entityCache[id]);
    }
    if (_entityFutureCache.containsKey(id)) {
      return _entityFutureCache[id]!;
    }

    final future = isGroup
        ? GroupChatService.getGroupData(id)
        : getContactUser(id);

    _entityFutureCache[id] = future.then((value) {
      _entityCache[id] = value;
      return value;
    });

    return _entityFutureCache[id]!;
  }

  Future<Map<dynamic, dynamic>?> getContactUser(String contactId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$contactId')
          .get();
      if (snapshot.exists && snapshot.value is Map) {
        return snapshot.value as Map;
      } else {
        debugPrint('User data invalid or not found: ${snapshot.value}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text("WhatsUp"),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: 80,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            icon: const Icon(Icons.search),
          ),
          SettingsMenuIcon(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: widget.contacts.length,
          itemBuilder: (context, index) {
            final contact = widget.contacts[index];
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final isGroupChat = contact['isGroupChat'];

            // Determine the contact's ID (the "other" user)
            final idToUse;
            if (isGroupChat) {
              idToUse = contact['groupId'];
            } else {
              idToUse = contact['senderId'] != uid
                  ? contact['senderId']
                  : contact['receiverId'];
              ;
            }

            final initialData = _entityCache[idToUse];

            return FutureBuilder<Map<dynamic, dynamic>?>(
              future: _getEntity(idToUse, isGroupChat),
              initialData: initialData,
              builder: (context, snapshot) {
                final entity = snapshot.data ?? initialData;
                final lastMessage = contact['lastMessage']?.toString() ?? '';

                final String title = isGroupChat
                    ? (entity?['name']?.toString() ?? 'Unknown Group')
                    : (entity?['username']?.toString() ?? 'Unknown User');

                final imageUrl = entity?['image_url']?.toString();
                final ImageProvider sideImage =
                    (imageUrl != null && imageUrl.isNotEmpty)
                    ? NetworkImage(imageUrl)
                    : AssetImage(
                        isGroupChat
                            ? 'assets/images/default_group_avatar.png'
                            : 'assets/images/default_avatar.png',
                      );

                if (entity == null &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: SizedBox(
                      height: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black12),
                      ),
                    ),
                    subtitle: SizedBox(
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black12),
                      ),
                    ),
                  );
                }

                return ChatListItem(
                  id: uid,
                  contactId: idToUse,
                  title: title,
                  lastMessage: lastMessage,
                  timestamp: contact['timestamp']?.toString() ?? '',
                  sideImage: sideImage,
                  isGroup: isGroupChat,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
