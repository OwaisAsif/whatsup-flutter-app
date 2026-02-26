import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsup/firebase/auth_service.dart';

class CallingService {
  static final _db = FirebaseDatabase.instance;
  static final _uuid = const Uuid();

  static Future<String?> startVideoCall({
    required String calleeId,
    String? groupId,
  }) {
    return _startCall(type: 'video', calleeId: calleeId, groupId: groupId);
  }

  static Future<String?> startAudioCall({
    required String calleeId,
    String? groupId,
  }) {
    return _startCall(type: 'audio', calleeId: calleeId, groupId: groupId);
  }

  static Future<void> acceptCall(String callId) async {
    await _db.ref('calls/$callId').update({'status': 'accepted'});
  }

  static Future<void> rejectCall(String callId) async {
    await _db.ref('calls/$callId').update({'status': 'rejected'});
  }

  static Future<void> endCall(String callId) async {
    final callRef = _db.ref('calls/$callId');
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await callRef.update({
      'status': 'ended',
      'endedBy': userId ?? '',
      'endedAt': ServerValue.timestamp,
    });
  }

  static Future<String?> _startCall({
    required String type,
    required String calleeId,
    String? groupId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final callId = _uuid.v4();
    final callRef = _db.ref('calls/$callId');
    final callerProfile = await AuthService.getUserProfile(user.uid);
    await callRef.set({
      'callId': callId,
      'callerId': user.uid,
      'callerName': callerProfile?['username'] ?? user.email ?? 'Someone',
      'callerImage': callerProfile?['profileImage'] ?? '',
      'calleeId': calleeId,
      'groupId': groupId ?? '',
      'type': type,
      'timestamp': ServerValue.timestamp,
      'status': 'ringing',
    });

    return callId;
  }
}
