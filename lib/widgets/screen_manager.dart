import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:whatsup/firebase/group_chat_service.dart';
import 'package:whatsup/firebase/messaging_Service.dart';
import 'package:whatsup/screens/auth_screen.dart';
import 'package:whatsup/screens/chats_list_screen.dart';
import 'package:whatsup/screens/complete_user_information_screen.dart';
import 'package:whatsup/screens/splash_screen.dart';

class ScreenManager extends StatefulWidget {
  const ScreenManager({super.key});

  @override
  State<ScreenManager> createState() => _ScreenManagerState();
}

class _ScreenManagerState extends State<ScreenManager> {
  Map<dynamic, dynamic>? _userData;

  bool _initialLoadingDone = false;

  // Inline chats repository logic
  final StreamController<List<Map<String, dynamic>>> _contactsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  StreamSubscription<DatabaseEvent>? _contactsSub;
  List<Map<String, dynamic>> _lastContacts = [];
  bool _isProcessingContacts = false;

  Stream<List<Map<String, dynamic>>> _watchContacts(String uid) {
    _contactsSub?.cancel();

    _contactsSub = FirebaseDatabase.instance
        .ref('contacts')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .listen((event) async {
          if (_isProcessingContacts) return;
          _isProcessingContacts = true;

          final raw = event.snapshot.value as Map<dynamic, dynamic>?;
          if (raw == null) {
            _emitContacts(const []);
            _isProcessingContacts = false;
            return;
          }

          final filtered = await _filterContactsAndGroups(raw, uid);
          _emitContacts(filtered);
          _isProcessingContacts = false;
        });

    return _contactsController.stream;
  }

  void _emitContacts(List<Map<String, dynamic>> next) {
    if (_listsEqual(_lastContacts, next)) return;
    _lastContacts = next;
    if (!_contactsController.isClosed) {
      _contactsController.add(next);
    }
  }

  Future<List<Map<String, dynamic>>> _filterContactsAndGroups(
    Map<dynamic, dynamic> data,
    String uid,
  ) async {
    final results = await Future.wait(
      data.entries.map((entry) async {
        final contact = Map<String, dynamic>.from(entry.value);
        final senderId = contact['senderId'];
        final receiverId = contact['receiverId'];
        final groupId = contact['groupId'];

        contact['isGroupChat'] = false;

        final isDirectChat = senderId == uid || receiverId == uid;
        bool isGroupChat = false;

        if (groupId != null) {
          final group = await GroupChatService.getGroupData(groupId);
          final memberIds = group?['memberIds'];
          isGroupChat =
              memberIds != null && memberIds is List && memberIds.contains(uid);
          contact['isGroupChat'] = true;
        }

        return (isDirectChat || isGroupChat) ? contact : null;
      }),
    );

    final filtered = results.whereType<Map<String, dynamic>>().toList();

    // Sort newest first
    filtered.sort(
      (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
    );

    return filtered;
  }

  bool _listsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['timestamp'] != b[i]['timestamp']) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // ⭐ Splash only on FIRST app launch
        if (!_initialLoadingDone &&
            authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (!authSnapshot.hasData) {
          _initialLoadingDone = true;
          return const AuthScreen();
        }

        final uid = authSnapshot.data!.uid;

        // Listen only to current user; keep prior data while waiting
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('users/$uid').onValue,
          builder: (context, userSnapshot) {
            final hasUserData =
                userSnapshot.hasData &&
                userSnapshot.data!.snapshot.value != null;

            if (!_initialLoadingDone &&
                userSnapshot.connectionState == ConnectionState.waiting &&
                _userData == null) {
              return const SplashScreen();
            }

            if (hasUserData) {
              _userData =
                  userSnapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
            }

            if (_userData == null) {
              return ChatsListScreen(contacts: _lastContacts);
            }

            if (_userData?['info_completed'] == null) {
              _initialLoadingDone = true;
              return CompleteUserInformationScreen(uid: uid);
            }

            // Main contacts stream already filtered and cached inline
            final contactsStream = _watchContacts(uid);

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: contactsStream,
              initialData: _lastContacts,
              builder: (context, chatSnapshot) {
                final contacts = chatSnapshot.data ?? _lastContacts;

                // Subscribe once for messaging (safe idempotent)
                MessagingService.subscribeToGroups();

                _initialLoadingDone = true;
                return ChatsListScreen(contacts: contacts);
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _contactsSub?.cancel();
    _contactsController.close();
    super.dispose();
  }
}
