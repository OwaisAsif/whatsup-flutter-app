import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsup/firebase/auth_service.dart';
import 'package:whatsup/firebase/calling_service.dart';
import 'package:whatsup/firebase/chat_service.dart';
import 'package:whatsup/firebase/group_chat_service.dart';
import 'package:whatsup/helpers/image_picker_helper.dart';
import 'package:whatsup/helpers/image_uploader.dart';
import 'package:whatsup/screens/chat_details_screen.dart';
import 'package:whatsup/screens/call_screen.dart';
import 'package:whatsup/widgets/chat_messages_list.dart';
import 'package:whatsup/widgets/send_image_screen.dart';
import 'package:whatsup/widgets/ui/colors.dart';

final FirebaseDatabase _db = FirebaseDatabase.instance;

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.id,
    required this.contactId,
    required this.isGroup,
  });

  final String id;
  final String contactId;
  final bool isGroup;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Map<dynamic, dynamic>? data = {};
  final TextEditingController _messageController = TextEditingController();
  File? SelectedMedia;
  bool _loadingAttachment = false;
  bool isLoading = true;
  final loggedUserId = FirebaseAuth.instance.currentUser!.uid;
  @override
  void initState() {
    super.initState();
    getUserInfo();
    print(
      "ChatScreen initialized with id: ${widget.id}, contactId: ${widget.contactId}, isGroup: ${widget.isGroup}",
    );
  }

  /// Fetch user info safely
  void getUserInfo() async {
    try {
      var responseData;
      if (widget.isGroup) {
        responseData = await GroupChatService.getGroupData(widget.contactId);
      } else {
        responseData = await AuthService.getUserProfile(widget.contactId);
      }

      setState(() {
        data = responseData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching info: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching user info: $e')));
      Navigator.pop(context);
    }
  }

  /// Handle image
  void _handlePhotoSelection() async {
    final selectedImage = await pickImage(context);
    if (selectedImage != null) {
      setState(() {
        SelectedMedia = selectedImage;
      });
      try {
        final randomId = Uuid().v4();
        final imageUrl = await uploadImage(
          selectedImage.readAsBytesSync(),
          randomId,
        );
        if (imageUrl == null) {
          throw Exception("Image Not Uploaded");
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SendImageScreen(
              imageUrl: imageUrl,
              senderId: loggedUserId,
              recieverId: widget.contactId,
              isGroup: widget.isGroup,
            ),
          ),
        );
      } catch (e) {
        print(e);
      }
    }
  }

  /// Handle Location
  void _handleLocationSelection() async {
    try {
      setState(() {
        _loadingAttachment = true;
      });
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled");
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permanently denied");
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final user = await AuthService.getUserProfile(loggedUserId);

      double lat = position.latitude;
      double lng = position.longitude;

      final messageData = {
        'senderId': widget.id,
        'receiverId': widget.contactId,
        'senderName': user?['username'] ?? "Unknown",
        'senderImage': user?['image_url'] ?? "",
        'lat': lat,
        'lng': lng,
        'type': 'location',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      ChatService.updateContactHistory(
        widget.id,
        widget.contactId,
        "LOCATION_SENDED",
      );
      await ChatService.sendMessage(context, messageData);
      setState(() {
        _loadingAttachment = false;
      });
    } catch (e) {
      print("Location error: $e");
      setState(() {
        _loadingAttachment = false;
      });
    }
  }

  /// Send a message safely
  void sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final user = await AuthService.getUserProfile(loggedUserId);

    final messageData = {
      'senderId': loggedUserId,
      '${widget.isGroup ? "groupId" : "receiverId"}': widget.contactId,
      'text': text,
      'type': 'text',
      'senderName': user?['username'] ?? "Unknown",
      'senderImage': user?['image_url'] ?? "",
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (widget.isGroup) {
      GroupChatService.updateGroupsHistory(widget.id, widget.contactId, text);
    } else {
      ChatService.updateContactHistory(widget.id, widget.contactId, text);
    }
    await ChatService.sendMessage(context, messageData);
    _messageController.clear();
  }

  void _openDetails() {
    if (isLoading) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailsScreen(
          contactId: widget.contactId,
          isGroup: widget.isGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leadingWidth: 90,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              radius: 20,
              backgroundImage: !widget.isGroup
                  ? (data?['image_url'] != null &&
                            data?['image_url'] is String &&
                            data?['image_url'].isNotEmpty)
                        ? NetworkImage(data?['image_url'])
                        : const AssetImage('assets/images/default_avatar.png')
                              as ImageProvider
                  : const AssetImage('assets/images/default_group_avatar.png')
                        as ImageProvider,
            ),
          ],
        ),
        title: GestureDetector(
          onTap: _openDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoading
                    ? 'Loading...'
                    : widget.isGroup
                    ? data!['name'] ?? 'Unknown Group'
                    : data?['username'] ?? 'Unknown User',
              ),
              if (!widget.isGroup)
                Text(
                  isLoading ? 'Loading...' : (data?['email'] ?? ''),
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),

        // 👇 ADD THIS PART (CALL ICONS)
        actions: [
          if (!widget.isGroup) ...[
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () async {
                final callId = await CallingService.startAudioCall(
                  calleeId: widget.contactId,
                );
                if (callId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to start the call')),
                  );
                  return;
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallScreen(
                      callId: callId,
                      callType: 'audio',
                      calleeId: widget.contactId,
                      callerId: loggedUserId,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () async {
                final callId = await CallingService.startVideoCall(
                  calleeId: widget.contactId,
                );
                if (callId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to start the call')),
                  );
                  return;
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CallScreen(
                      callId: callId,
                      callType: 'video',
                      calleeId: widget.contactId,
                      callerId: loggedUserId,
                    ),
                  ),
                );
              },
            ),
          ],
        ],

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: 80,
      ),
      body: Column(
        children: [
          StreamBuilder(
            stream: _db.ref('messages').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Expanded(
                  child: Center(child: Text("No messages yet")),
                );
              }

              final data =
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

              final messages =
                  data.values
                      .whereType<Map<dynamic, dynamic>>()
                      .where(
                        (msg) => !widget.isGroup
                            ? (msg['senderId'] == widget.id &&
                                      msg['receiverId'] == widget.contactId) ||
                                  (msg['senderId'] == widget.contactId &&
                                      msg['receiverId'] == widget.id)
                            : msg['groupId'] == widget.contactId,
                      )
                      .toList()
                    ..sort(
                      (a, b) => (a['timestamp'] as int).compareTo(
                        b['timestamp'] as int,
                      ),
                    );
              print(messages);
              return ChatMessagesList(
                messages: messages.reversed.toList(),
                isGroup: widget.isGroup,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 8,
              left: 8,
              right: 8,
              bottom: 26,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                _loadingAttachment
                    ? SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, // optional: makes it thinner
                        ),
                      )
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.attach_file),
                        offset: Offset(0, widget.isGroup ? -70 : -150),
                        onSelected: (value) => {
                          if (value == 'photos')
                            {_handlePhotoSelection()}
                          else if (value == 'location')
                            {_handleLocationSelection()},
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'photos',
                            child: Row(
                              children: [
                                Icon(Icons.photo, size: 18, color: kblackColor),
                                SizedBox(width: 8),
                                Text('Photos'),
                              ],
                            ),
                          ),
                          if (!widget.isGroup)
                            PopupMenuItem(
                              value: 'location',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: kblackColor,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Location'),
                                ],
                              ),
                            ),
                        ],
                      ),
                SizedBox(width: 10),
                IconButton(
                  onPressed: sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
