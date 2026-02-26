import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';

final FirebaseDatabase _db = FirebaseDatabase.instance;

class ChatService {
  static void updateContactHistory(
    String senderId,
    String recieverId,
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
          final sender = value['senderId'] ?? '';
          final receiver = value['receiverId'] ?? '';
          if ((sender == senderId && receiver == recieverId) ||
              (sender == recieverId && receiver == senderId)) {
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
        'receiverId': recieverId,
        'lastMessage': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('Contact updated: $contactKey');
    } else {
      // Create a new contact
      await contactsRef.push().set({
        'senderId': senderId,
        'receiverId': recieverId,
        'lastMessage': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('Contact created for ${senderId} and ${recieverId}');
    }
  }

  static Future<void> sendMessage(
    BuildContext ctx,
    Map<String, dynamic> messageData,
  ) async {
    try {
      print('Sending message with data: $messageData');
      // Send the message
      await _db.ref('messages').push().set(messageData);
    } catch (e, stackTrace) {
      debugPrint('Error sending message: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  static Future<void> addCallRecord(String callId) async {
    final callSnapshot = await _db.ref('calls/$callId').get();
    if (!callSnapshot.exists) {
      debugPrint('Call record not found for callId: $callId');
      return;
    }

    final callData = callSnapshot.value as Map<dynamic, dynamic>;
    final callerId = callData['callerId'] ?? '';
    final calleeId = callData['calleeId'] ?? '';
    final callerUser = await AuthService.getUserProfile(callerId);
    final groupId = callData['groupId'] ?? '';
    final type = callData['type'] ?? 'unknown';
    final timestamp = _readMillis(callData['timestamp']);
    final endAt = _readMillis(callData['endedAt']);
    final duration = (timestamp > 0 && endAt > timestamp)
        ? endAt - timestamp
        : 0;

    await _db.ref('messages').push().set({
      'callId': callId,
      'senderId': callerId,
      'receiverId': calleeId,
      'groupId': groupId,
      'senderName': callerUser?['username'] ?? 'Unknown',
      'senderImage': callerUser?['profileImage'] ?? '',
      'type': type,
      'timestamp': timestamp,
      'duration': duration,
    });

    // update contact history for caller and callee
    if (callerId.isNotEmpty && calleeId.isNotEmpty) {
      updateContactHistory(
        callerId,
        calleeId,
        type == 'video' ? 'VIDEO_CALL' : 'AUDIO_CALL',
      );
    }
  }

  static int _readMillis(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.floor();
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    if (raw is Map && raw['.sv'] != null) {
      return 0; // placeholder until server timestamp resolves
    }
    return 0;
  }

  // Blocking helpers --------------------------------------------------------
  static DatabaseReference _blockRef(String blockerId, String blockedId) =>
      _db.ref('blocks/$blockerId/$blockedId');

  static Future<void> blockUser(String blockerId, String blockedId) async {
    await _blockRef(blockerId, blockedId).set(true);
  }

  static Future<void> unblockUser(String blockerId, String blockedId) async {
    await _blockRef(blockerId, blockedId).remove();
  }

  static Future<bool> isUserBlocked(String blockerId, String blockedId) async {
    final snapshot = await _blockRef(blockerId, blockedId).get();
    return snapshot.exists;
  }
}
