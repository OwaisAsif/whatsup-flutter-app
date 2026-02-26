bool isSingleEmoji(String text) {
  if (text.trim().isEmpty) return false;

  final emojiRegex = RegExp(r'^\p{Extended_Pictographic}$', unicode: true);

  return emojiRegex.hasMatch(text.trim());
}

String ucFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
