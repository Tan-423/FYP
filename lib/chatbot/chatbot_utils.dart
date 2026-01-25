String formatChatTime(DateTime time) {
  final hours = time.hour.toString().padLeft(2, '0');
  final minutes = time.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

String inputHintForLanguage(String language) {
  switch (language) {
    case 'bm':
      return 'Taip atau cakap...';
    case 'cn':
      return '打字或语音...';
    case 'en':
    default:
      return 'Type or speak...';
  }
}
