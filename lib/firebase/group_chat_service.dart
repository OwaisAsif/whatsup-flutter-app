import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';

final firebase = FirebaseAuth.instance;
final _db = FirebaseDatabase.instance;

class GroupChatService {
  static void updateGroupsHistory(
    String senderId,
    String groupId,
    String text,
  ) async {
    final contactsRef = _db.ref('contacts');

    // Fetch all contacts and filter manually
    final contactsSnapshot = await contactsRef.get();
    Map<dynamic, dynamic> existingContact = {};

    if (contactsSnapshot.exists && contactsSnapshot.value is Map) {
      final contactMap = contactsSnapshot.value as Map;

      contactMap.forEach((key, value) {
        if (value is Map) {
          final group = value['groupId'] ?? '';
          if ((group == groupId)) {
            existingContact[key] = value;
          }
        }
      });
    }

    if (existingContact.isNotEmpty) {
      // Update the first existing contact
      final contactKey = existingContact.keys.first;
      await contactsRef.child(contactKey).update({
        'senderId': senderId,
        'groupId': groupId,
        'lastMessage': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('Contact updated: $contactKey');
    } else {
      // Create a new contact
      await contactsRef.push().set({
        'senderId': senderId,
        'groupId': groupId,
        'lastMessage': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('Contact created for ${senderId} and ${groupId}');
    }
  }

  static Future<void> sendMessage(Map<String, dynamic> messageData) async {
    try {
      // Send the message
      await _db.ref('messages').push().set(messageData);
    } catch (e, stackTrace) {
      debugPrint('Error sending message: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<Map<dynamic, dynamic>?> getGroupData(String groupId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('groups/$groupId')
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

  static Future<bool> createGroup(Map<String, Object?> groupData) async {
    try {
      // Send the message
      final groupRef = _db.ref('groups').push();
      final groupId = groupRef.key;
      final senderId = groupData['creatorId'].toString();
      groupData['groupId'] = groupId;
      final firstMessage = "Hello Everyone i Created a new Group";
      final user = await AuthService.getUserProfile(senderId);
      final firstMessageData = {
        'senderId': senderId,
        'groupId': groupId!,
        'text': firstMessage,
        'senderName': user?['username'] ?? "Unknown",
        'senderImage': user?['image_url'] ?? "",
        'type': 'text',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await GroupChatService.sendMessage(firstMessageData);
      GroupChatService.updateGroupsHistory(senderId, groupId, firstMessage);

      await groupRef.set(groupData);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error sending message: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> addMembers(String groupId, List<String> userIds) async {
    if (userIds.isEmpty) return false;
    final memberRef = _db.ref('groups/$groupId/memberIds');
    final snapshot = await memberRef.get();
    final existing = snapshot.exists && snapshot.value is List
        ? (snapshot.value as List)
              .whereType<dynamic>()
              .map((e) => e?.toString())
              .whereType<String>()
              .toList()
        : <String>[];
    final updated = {
      ...existing,
      ...userIds,
    }.where((id) => id.isNotEmpty).toList();
    await memberRef.set(updated);
    return true;
  }

  static Future<bool> removeMember(String groupId, String userId) async {
    final memberRef = _db.ref('groups/$groupId/memberIds');
    final snapshot = await memberRef.get();
    if (!snapshot.exists || snapshot.value is! List) {
      return false;
    }
    final members = (snapshot.value as List)
        .whereType<dynamic>()
        .map((e) => e?.toString())
        .whereType<String>()
        .toList();
    members.removeWhere((id) => id == userId);
    if (members.isEmpty) {
      await _db.ref('groups/$groupId').remove();
    } else {
      await memberRef.set(members);
    }
    return true;
  }

  static Future<void> updateGroupImageUrl(
    String groupId,
    String imageUrl,
  ) async {
    await _db.ref('groups/$groupId').update({'image_url': imageUrl});
  }
}
