import 'package:flutter/material.dart';
import 'package:whatsup/helpers/date_helper.dart';
import 'package:whatsup/screens/chat_screen.dart';
import 'package:whatsup/widgets/image_viewer.dart';

class ChatListItem extends StatelessWidget {
  final String id;
  final String contactId;
  final String title;
  final String lastMessage;
  final String timestamp;
  final ImageProvider? sideImage;
  final bool isGroup;

  Widget _getLastMessageWidget(String text) {
    if (text == "PHOTO_SENDED") {
      return Row(
        children: [
          Icon(Icons.photo),
          SizedBox(width: 10),
          Text("Photo", style: const TextStyle(color: Colors.grey)),
        ],
      );
    } else if (text == "LOCATION_SENDED") {
      return Row(
        children: [
          Icon(Icons.location_on),
          SizedBox(width: 10),
          Text("Location", style: const TextStyle(color: Colors.grey)),
        ],
      );
    } else if (text == "AUDIO_CALL") {
      return Row(
        children: [
          Icon(Icons.audiotrack),
          SizedBox(width: 10),
          Text("Audio", style: const TextStyle(color: Colors.grey)),
        ],
      );
    } else if (text == "VIDEO_CALL") {
      return Row(
        children: [
          Icon(Icons.videocam),
          SizedBox(width: 10),
          Text("Video", style: const TextStyle(color: Colors.grey)),
        ],
      );
    }
    return Text(addEllipsis(text), style: const TextStyle(color: Colors.grey));
  }

  String addEllipsis(String text, {int maxLength = 20}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
  }

  ChatListItem({
    super.key,
    required this.id,
    required this.contactId,
    required this.title,
    required this.lastMessage,
    required this.timestamp,
    this.sideImage,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(id: id, contactId: contactId, isGroup: isGroup),
          ),
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ImageViewer(imageUrl: sideImage.toString()),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: sideImage, // or AssetImage
                  ),
                ),
                // CircleAvatar(radius: 24, backgroundImage: userImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addEllipsis(title),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _getLastMessageWidget(lastMessage),
                    ],
                  ),
                ),
                Text(
                  DateHelper.formatTimestamp(int.tryParse(timestamp) ?? 0),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
