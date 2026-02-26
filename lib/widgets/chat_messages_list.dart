import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/helpers/chat_calls_helper.dart';
import 'package:whatsup/helpers/location_helper.dart';
import 'package:whatsup/helpers/text_helper.dart';
import 'package:whatsup/widgets/image_viewer.dart';
import 'package:whatsup/widgets/ui/colors.dart';

class ChatMessagesList extends StatelessWidget {
  const ChatMessagesList({
    super.key,
    required this.messages,
    required this.isGroup,
  });

  final List<Map<dynamic, dynamic>> messages;
  final bool isGroup;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return "Today";
    }
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return "Yesterday";
    }
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final loggedInUserId = FirebaseAuth.instance.currentUser!.uid;
    return Expanded(
      child: ListView.builder(
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final messageDate = DateTime.fromMillisecondsSinceEpoch(
            message['timestamp'] ?? 0,
          );
          bool isNext = false;

          if (index < messages.length - 1) {
            final nextMsg = messages[index + 1];
            isNext = nextMsg['senderId'] == message['senderId'];
          }
          // Check next message (because list is reversed)
          bool showDateBadge = false;

          if (index == messages.length - 1) {
            // First message in chat (top)
            showDateBadge = true;
          } else {
            final nextMessage = messages[index + 1];
            final nextDate = DateTime.fromMillisecondsSinceEpoch(
              nextMessage['timestamp'] ?? 0,
            );

            if (!_isSameDay(messageDate, nextDate)) {
              showDateBadge = true;
            }
          }

          var valueToUse = {"text": message['text']};
          if (message['type'] == 'photo') {
            valueToUse = {"url": message['url']};
          } else if (message['type'] == 'location') {
            print([message['lat'], message['lng']]);
            valueToUse = {"lat": message['lat'], "lng": message['lng']};
          } else if (message['type'] == 'audio' || message['type'] == 'video') {
            valueToUse = {
              "type": message['type'],
              'duration': message['duration'] ?? 0,
            };
          }
          return Column(
            children: [
              if (showDateBadge)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDate(messageDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              Message(
                isNext: isNext,
                value: valueToUse,
                isMe: message['senderId'] == loggedInUserId,
                type: message['type'],
                senderName: message['senderName'],
                senderImage: message['senderImage'],
                isInGroup: isGroup,
              ),
            ],
          );
        },
      ),
    );
  }
}

class Message extends StatelessWidget {
  const Message({
    super.key,
    required this.isNext,
    required this.value,
    required this.isMe,
    required this.type,
    required this.senderName,
    required this.senderImage,
    required this.isInGroup,
  });

  final bool isNext;
  final Map<String, dynamic> value;
  final String type;
  final String senderName;
  final String senderImage;
  final bool isMe;
  final bool isInGroup;

  @override
  Widget build(BuildContext context) {
    final isEmoji = isSingleEmoji(value['text'] ?? '');
    Widget widgetToShow = Text(
      value['text'] ?? "ERROR LOADING MESSAGE...",
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black87,
        fontSize: isEmoji ? 35 : 15,
      ),
    );
    if (type == "photo") {
      widgetToShow = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageViewer(imageUrl: value['url'].toString()),
            ),
          );
        },
        child: Image.network(value['url']),
      );
    } else if (type == 'location') {
      print("Rendering location with value: $value");
      widgetToShow = Text("data");
      final lat = value['lat'];
      final lng = value['lng'];
      widgetToShow = buildLocationMessage(lat, lng);
    } else if (type == 'audio' || type == 'video') {
      widgetToShow = buildMediaMessage(
        type: value['type'],
        duration: value['duration'] ?? 0,
        isMe: isMe,
      );
    }

    final messagingUserData = CircleAvatar(
      backgroundImage: senderImage.isNotEmpty
          ? NetworkImage(senderImage)
          : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider,
    );
    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        children: [
          if (isInGroup && !isNext && !isMe) ...{
            messagingUserData,
            SizedBox(width: 10),
          } else if (isInGroup) ...{
            SizedBox(width: 50),
          },
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isInGroup && !isNext && !isMe) ...{
                Text(senderName),
                SizedBox(height: 5),
              },
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: EdgeInsets.all(isEmoji ? 6 : 12),
                decoration: BoxDecoration(
                  color: isEmoji
                      ? ktransparentColor
                      : isMe
                      ? kprimaryColor
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widgetToShow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
