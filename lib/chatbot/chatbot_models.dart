class ChatMessage {
  ChatMessage({
    required this.text,
    required this.sender,
    required this.lang,
    required this.timestamp,
  });

  final String text;
  final MessageSender sender;
  final String lang;
  final DateTime timestamp;
}

enum MessageSender { user, bot }
