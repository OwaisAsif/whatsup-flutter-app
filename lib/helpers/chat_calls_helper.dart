import 'package:flutter/material.dart';
import 'package:whatsup/helpers/text_helper.dart';
import 'package:whatsup/widgets/ui/colors.dart';

Widget buildMediaMessage({
  required String type,
  required int duration,
  required bool isMe,
}) {
  final color = isMe ? kwhiteColor : kblackColor;
  return Container(
    padding: const EdgeInsets.all(6),
    child: Row(
      children: [
        Icon(
          type == 'audio' ? Icons.call : Icons.videocam,
          color: color,
          size: 40,
        ),
        SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ucFirst("$type call"),
              style: TextStyle(color: color, fontSize: 25),
            ),
            const SizedBox(height: 8),
            Text(
              "Duration: ${_formatDuration(duration)}",
              style: TextStyle(color: color),
            ),
          ],
        ),
      ],
    ),
  );
}

String _formatDuration(int durationMs) {
  if (durationMs <= 0) {
    return 'Missed';
  }

  final duration = Duration(milliseconds: durationMs);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  final buffer = <String>[];
  if (hours > 0) {
    buffer.add('${hours}h');
  }
  if (minutes > 0 || hours > 0) {
    buffer.add('${minutes}m');
  }
  buffer.add('${seconds}s');

  return buffer.join(' ');
}
