import 'package:flutter/material.dart';
import 'package:whatsup/firebase/auth_service.dart';
import 'package:whatsup/firebase/chat_service.dart';
import 'package:whatsup/firebase/group_chat_service.dart';

class SendImageScreen extends StatefulWidget {
  final String imageUrl;
  final String senderId;
  final String recieverId;
  final bool isGroup;

  const SendImageScreen({
    super.key,
    required this.imageUrl,
    required this.senderId,
    required this.recieverId,
    required this.isGroup,
  });

  @override
  State<SendImageScreen> createState() => _SendImageScreenState();
}

class _SendImageScreenState extends State<SendImageScreen> {
  bool isLoading = false;

  void _sendImageMessage() async {
    setState(() {
      isLoading = true;
    });
    final user = await AuthService.getUserProfile(widget.senderId);
    final messageData = {
      'senderId': widget.senderId,
      '${widget.isGroup ? "groupId" : "receiverId"}': widget.recieverId,
      'url': widget.imageUrl,
      'senderName': user?['username'] ?? "Unknown",
      'senderImage': user?['image_url'] ?? "",
      'type': 'photo',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (!widget.isGroup) {
      ChatService.updateContactHistory(
        widget.senderId,
        widget.recieverId,
        "PHOTO_SENDED",
      );
    } else {
      GroupChatService.updateGroupsHistory(
        widget.senderId,
        widget.recieverId,
        "PHOTO_SENDED",
      );
    }

    await ChatService.sendMessage(context, messageData);
    Navigator.pop(context);
  }

  String cleanUrl(String url) {
    return url
        .replaceAll('NetworkImage("', '')
        .replaceAll('")', '')
        .replaceAll(', scale: 1.0', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background like WhatsApp
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: isLoading ? null : _sendImageMessage,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check, color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: widget.imageUrl, // Optional: for smooth transition
          child: InteractiveViewer(
            panEnabled: true, // drag to move
            minScale: 1,
            maxScale: 4, // pinch to zoom
            child: Image.network(
              cleanUrl(widget.imageUrl),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
