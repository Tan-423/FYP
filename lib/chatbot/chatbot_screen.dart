import 'dart:async';

import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text:
          'Hello! I am your WanderEase assistant. How can I help you today?',
      sender: _MessageSender.bot,
      lang: 'en',
      timestamp: DateTime.now(),
    ),
  ];

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isListening = false;
  String _language = 'en';
  Timer? _typingTimer;
  Timer? _listeningTimer;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _listeningTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _getBotResponse(String input) {
    final text = input.toLowerCase();
    const responses = {
      'weather': {
        'en':
            'The weather in Kuala Lumpur today is sunny with a high of 32°C. '
                'Perfect for sightseeing!',
        'bm':
            'Cuaca di Kuala Lumpur hari ini cerah dengan suhu setinggi 32°C. '
                'Sangat sesuai untuk melawat!',
        'cn': '吉隆坡今天天气晴朗，最高温度 32°C。非常适合观光！',
      },
      'places': {
        'en': 'I suggest visiting the Petronas Twin Towers, Batu Caves, '
            'or Merdeka Square.',
        'bm': 'Saya cadangkan melawat Menara Berkembar Petronas, Gua Batu, '
            'atau Dataran Merdeka.',
        'cn': '我建议参观双子塔、黑风洞或独立广场。',
      },
      'booking': {
        'en': 'You can book hotels through our Accommodation tab. '
            'Would you like to see nearby options?',
        'bm': 'Anda boleh menempah hotel melalui tab Penginapan. '
            'Adakah anda ingin melihat pilihan berdekatan?',
        'cn': '您可以通过“住宿”选项卡预订酒店。您想查看附近的选项吗？',
      },
      'default': {
        'en': "I'm here to help with weather, locations, or bookings. "
            'Feel free to ask!',
        'bm': 'Saya di sini untuk membantu dengan cuaca, lokasi, atau tempahan. '
            'Sila tanya!',
        'cn': '我可以提供天气、景点或预订方面的帮助。请随时提问！',
      },
    };

    var key = 'default';
    if (text.contains('weather') ||
        text.contains('cuaca') ||
        text.contains('天气')) {
      key = 'weather';
    } else if (text.contains('suggest') ||
        text.contains('place') ||
        text.contains('景点') ||
        text.contains('cadang')) {
      key = 'places';
    } else if (text.contains('book') ||
        text.contains('hotel') ||
        text.contains('预订') ||
        text.contains('tempah')) {
      key = 'booking';
    }

    return responses[key]![_language]!;
  }

  void _handleSendMessage([String? textOverride]) {
    final textToSend = textOverride ?? _inputController.text;
    if (textToSend.trim().isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: textToSend.trim(),
          sender: _MessageSender.user,
          lang: _language,
          timestamp: DateTime.now(),
        ),
      );
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 800), () {
      final responseText = _getBotResponse(textToSend);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: responseText,
            sender: _MessageSender.bot,
            lang: _language,
            timestamp: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  void _toggleVoiceInput() {
    if (_isListening) return;
    setState(() => _isListening = true);
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      const simulated = {
        'en': 'Show me the weather in Kuala Lumpur',
        'bm': 'Tempat menarik di Gua Batu',
        'cn': '推荐几个景点',
      };
      setState(() {
        _isListening = false;
        _inputController.text = simulated[_language]!;
      });
    });
  }

  void _clearChat() {
    const cleared = {
      'en': 'Chat history cleared. How can I help you?',
      'bm': 'Sejarah perbualan dibersihkan. Bagaimana saya boleh membantu?',
      'cn': '聊天记录已清除。我能如何帮助您？',
    };
    setState(() {
      _messages
        ..clear()
        ..add(
          _ChatMessage(
            text: cleared[_language]!,
            sender: _MessageSender.bot,
            lang: _language,
            timestamp: DateTime.now(),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    const headerColor = Color(0xFF2563EB);
    const lightBlue = Color(0xFFEFF6FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: headerColor,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.message_rounded,
                          color: headerColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WanderEase Bot',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Always active',
                              style: TextStyle(
                                color: Color(0xFFDBEAFE),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _language,
                          dropdownColor: headerColor,
                          iconEnabledColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('EN')),
                            DropdownMenuItem(value: 'bm', child: Text('BM')),
                            DropdownMenuItem(value: 'cn', child: Text('中文')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _language = value);
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: _clearChat,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: const Color(0xFFDBEAFE),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return _TypingBubble();
                      }
                      final message = _messages[index];
                      final isUser = message.sender == _MessageSender.user;
                      return Align(
                        alignment:
                            isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: isUser
                                ? headerColor
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft:
                                  Radius.circular(isUser ? 18 : 4),
                              bottomRight:
                                  Radius.circular(isUser ? 4 : 18),
                            ),
                            border: Border.all(
                              color: isUser
                                  ? Colors.transparent
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(
                                  color:
                                      isUser ? Colors.white : const Color(0xFF1E293B),
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    message.lang.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isUser
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isUser
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SuggestionChip(
                          label: 'Weather',
                          icon: Icons.cloud_outlined,
                          onTap: () => _handleSendMessage("What's the weather?"),
                        ),
                        _SuggestionChip(
                          label: 'Places',
                          icon: Icons.place_outlined,
                          onTap: () =>
                              _handleSendMessage('Suggest places to visit'),
                        ),
                        _SuggestionChip(
                          label: 'Hotels',
                          icon: Icons.public_rounded,
                          onTap: () => _handleSendMessage('How to book a hotel?'),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        color: const Color(0xFF94A3B8),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSendMessage(),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _language == 'en'
                                ? 'Type or speak...'
                                : _language == 'bm'
                                    ? 'Taip atau cakap...'
                                    : '打字或语音...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFFEF4444)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _toggleVoiceInput,
                          icon: const Icon(Icons.mic_rounded),
                          color: _isListening
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: _inputController.text.trim().isEmpty ||
                                _isTyping
                            ? null
                            : _handleSendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                          shape: const CircleBorder(),
                          elevation: 2,
                        ),
                        child: _isTyping
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isListening)
              Positioned.fill(
                child: Container(
                  color: lightBlue.withOpacity(0.95),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF93C5FD).withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFDBEAFE),
                              ),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: headerColor,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Listening...',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Talk to WanderEase',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: () => setState(() => _isListening = false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: headerColor,
                          side: const BorderSide(color: Color(0xFFDBEAFE)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final hours = time.hour.toString().padLeft(2, '0');
  final minutes = time.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(),
            SizedBox(width: 6),
            _Dot(delay: 150),
            SizedBox(width: 6),
            _Dot(delay: 300),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({this.delay = 0});

  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.delay == 0) {
      _controller.repeat(reverse: true);
    } else {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (!mounted) return;
        _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: const CircleAvatar(
        radius: 3,
        backgroundColor: Color(0xFF60A5FA),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2563EB),
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFEFF6FF),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFDBEAFE)),
          ),
        ),
      ),
    );
  }
}

enum _MessageSender { user, bot }

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.sender,
    required this.lang,
    required this.timestamp,
  });

  final String text;
  final _MessageSender sender;
  final String lang;
  final DateTime timestamp;
}
