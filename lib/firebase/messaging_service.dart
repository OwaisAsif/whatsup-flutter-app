import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsup/screens/call_screen.dart';
import 'package:whatsup/screens/chat_screen.dart';

final _messaging = FirebaseMessaging.instance;
final uid = FirebaseAuth.instance.currentUser!.uid;
final _db = FirebaseDatabase.instance;

class MessagingService {
  static late BuildContext _ctx; // Changed to static

  static void initializeMesseging(BuildContext ctx) async {
    await _messaging.requestPermission();
    // print(await _messaging.getToken());
    _messaging.subscribeToTopic('user_${uid}');
    _ctx = ctx; // Properly assign the static field
    await MessagingService.subscribeToGroups();

    // Initialize local notifications to handle foreground action button taps
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidInitSettings);
    await FlutterLocalNotificationsPlugin().initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        FlutterRingtonePlayer().stop();
        await FlutterLocalNotificationsPlugin().cancel(id: 999);
        if (response.payload == null) return;
        final callData = jsonDecode(response.payload!) as Map<String, dynamic>;
        if (response.actionId == 'ACCEPT') {
          await FirebaseDatabase.instance
              .ref('calls/${callData['callId']}')
              .update({'status': 'accepted'});
          if (ctx.mounted) {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => CallScreen(
                  callId: callData['callId'] as String,
                  callType: (callData['callType'] as String?) ?? 'audio',
                  calleeId: (callData['calleeId'] as String?) ?? '',
                  callerId: (callData['callerId'] as String?) ?? '',
                ),
              ),
            );
          }
        } else if (response.actionId == 'REJECT') {
          await FirebaseDatabase.instance
              .ref('calls/${callData['callId']}')
              .update({'status': 'rejected'});
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    // Handle call accepted while app was terminated (background action)
    final prefs = await SharedPreferences.getInstance();
    final pendingCallJson = prefs.getString('pending_call');
    if (pendingCallJson != null) {
      await prefs.remove('pending_call');
      final callData = jsonDecode(pendingCallJson) as Map<String, dynamic>;
      if (ctx.mounted) {
        FlutterRingtonePlayer().stop();
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              callId: callData['callId'] as String,
              callType: (callData['callType'] as String?) ?? 'audio',
              calleeId: (callData['calleeId'] as String?) ?? '',
              callerId: (callData['callerId'] as String?) ?? '',
            ),
          ),
        );
      }
    }

    print("Messaging initialized for user: $uid");
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final callId = data['callId'] ?? '';
      print(data);
      if (data['clickEvent'] == 'OPEN_CALL') {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: true,
          volume: 1.0,
        );
        Navigator.push(
          _ctx,
          MaterialPageRoute(
            builder: (context) {
              return CallScreen(
                callId: callId,
                callType: data['callType'] ?? 'audio',
                calleeId: data['calleeId'] ?? data['senderId'],
                callerId: data['callerId'] ?? data['senderId'],
              );
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(_ctx).showSnackBar(
          SnackBar(
            content: Text('Received notification: ${data['clickEvent']}'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                if (data['clickEvent'] == 'OPEN_CHAT')
                  Navigator.push(
                    _ctx,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        id: uid,
                        contactId: data['senderId'],
                        isGroup: false,
                      ),
                    ),
                  );
                else if (data['clickEvent'] == 'OPEN_GROUP_CHAT')
                  Navigator.push(
                    _ctx,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        id: uid,
                        contactId: data['groupId'],
                        isGroup: true,
                      ),
                    ),
                  );
              },
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = message.data;
      final callId = data['callId'] ?? '';
      print(data);
      if (data['clickEvent'] == 'CALL_STATUS') {
        FlutterRingtonePlayer().stop();
        return;
      }
      if (data['clickEvent'] == 'OPEN_CALL') {
        print("Incoming call from ${data['callerId']}");
        return;
      }
      Navigator.push(
        _ctx,
        MaterialPageRoute(
          builder: (context) {
            if (data['clickEvent'] == 'OPEN_CHAT')
              return ChatScreen(
                id: uid,
                contactId: data['senderId'],
                isGroup: false,
              );
            else if (data['clickEvent'] == 'OPEN_GROUP_CHAT')
              return ChatScreen(
                id: uid,
                contactId: data['groupId'],
                isGroup: true,
              );
            else {
              return CallScreen(
                callId: callId,
                callType: data['callType'] ?? 'audio',
                calleeId: data['calleeId'] ?? data['senderId'],
                callerId: data['callerId'] ?? data['senderId'],
              );
            }
          },
        ),
      );
    });
  }

  static Future<void> subscribeToGroups() async {
    final snapshot = await _db.ref('groups').get();

    if (!snapshot.exists) {
      print("No groups found");
      return;
    }

    final data = snapshot.value as Map<dynamic, dynamic>;

    data.forEach((key, value) {
      if (value["memberIds"].contains(uid)) {
        _messaging.subscribeToTopic('group_${key}');
        print("Subscribed to group topic: group_${key}");
      }
    });
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final clickEvent = data['clickEvent'];

  print(data);
  if (clickEvent == 'OPEN_CALL') {
    print("Background: Incoming call from ${data['callerId']}");

    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: true,
      volume: 1.0,
    );

    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'incoming_call_channel',
      'Incoming Calls',
      channelDescription: 'Incoming call notifications',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('ACCEPT', 'Accept', showsUserInterface: true),
        AndroidNotificationAction('REJECT', 'Reject', cancelNotification: true),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await FlutterLocalNotificationsPlugin().show(
      id: 999,
      title: data['callerName'] ?? 'Incoming Call',
      body: '${data['callType'] ?? 'Audio'} call',
      notificationDetails: notificationDetails,
      payload: jsonEncode({
        'callId': data['callId'] ?? '',
        'callType': data['callType'] ?? 'audio',
        'calleeId': data['calleeId'] ?? '',
        'callerId': data['callerId'] ?? '',
      }),
    );

    Future.delayed(const Duration(seconds: 30), () {
      FlutterRingtonePlayer().stop();
    });
  } else if (clickEvent == 'CALL_STATUS') {
    FlutterRingtonePlayer().stop();
    // cancel the incoming call notification if call is ended or rejected
    await FlutterLocalNotificationsPlugin().cancel(id: 999);
  }
}

/// Handles notification action buttons (ACCEPT / REJECT) when the app is in
/// the background or terminated. Must be a top-level function.
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  FlutterRingtonePlayer().stop();
  await FlutterLocalNotificationsPlugin().cancel(id: 999);

  if (response.payload == null) return;
  final callData = jsonDecode(response.payload!) as Map<String, dynamic>;
  final callId = callData['callId'] as String? ?? '';
  if (callId.isEmpty) return;

  await Firebase.initializeApp();

  if (response.actionId == 'ACCEPT') {
    // Accept the call in Firebase
    await FirebaseDatabase.instance.ref('calls/$callId').update({
      'status': 'accepted',
    });
    // Persist call data so the app navigates to CallScreen when it opens
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_call', response.payload!);
  } else if (response.actionId == 'REJECT') {
    await FirebaseDatabase.instance.ref('calls/$callId').update({
      'status': 'rejected',
    });
  }
}
