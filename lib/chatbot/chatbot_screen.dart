import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'chatbot_models.dart';
import 'chatbot_utils.dart';
import 'chatbot_widgets.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<ChatMessage> _messages = [];

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isListening = false;
  String _language = 'en';
  Timer? _listeningTimer;
  bool _dialogflowReady = false;
  AutoRefreshingAuthClient? _authClient;
  String? _projectId;
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initDialogflow();
  }

  @override
  void dispose() {
    _authClient?.close();
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

  Future<void> _initDialogflow() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/dialogflow/traverplannerchatbot-sxcn-601250d812e4.json',
      );
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final projectId = jsonMap['project_id'] as String?;
      if (projectId == null || projectId.isEmpty) {
        throw StateError('Dialogflow project_id missing in JSON');
      }
      final credentials = ServiceAccountCredentials.fromJson(jsonMap);
      _authClient = await clientViaServiceAccount(
        credentials,
        const ['https://www.googleapis.com/auth/dialogflow'],
      );
      _projectId = projectId;
      if (!mounted) return;
      setState(() => _dialogflowReady = true);
    } catch (error) {
      debugPrint('Dialogflow init failed: $error');
    }
  }

  Future<String?> _fetchDialogflowReply(String message) async {
    if (!_dialogflowReady || _authClient == null || _projectId == null) {
      return null;
    }
    final uri = Uri.parse(
      'https://dialogflow.googleapis.com/v2/projects/$_projectId/agent/sessions/$_sessionId:detectIntent',
    );
    // Always use 'en' so Dialogflow's English-trained intents always match.
    // Pass the selected UI language in queryParams.payload so the fulfillment
    // can reply in the user's chosen language.
    final body = jsonEncode({
      'queryInput': {
        'text': {'text': message, 'languageCode': 'en'},
      },
      'queryParams': {
        'payload': {
          'fields': {
            'uiLang': {'stringValue': _language},
          },
        },
      },
    });
    final response = await _authClient!.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200) {
      debugPrint('Dialogflow error ${response.statusCode}: ${response.body}');
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final queryResult = data['queryResult'] as Map<String, dynamic>?;
    final fulfillmentText = queryResult?['fulfillmentText'] as String?;
    if (fulfillmentText == null || fulfillmentText.trim().isEmpty) {
      return null;
    }
    return fulfillmentText.trim();
  }

  Future<void> _handleSendMessage([String? textOverride]) async {
    final textToSend = textOverride ?? _inputController.text;
    if (textToSend.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: textToSend.trim(),
          sender: MessageSender.user,
          lang: _language,
          timestamp: DateTime.now(),
        ),
      );
      _inputController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    if (!_dialogflowReady) {
      if (!mounted) return;
      setState(() => _isTyping = false);
      return;
    }

    // Translate BM/CN to English so Dialogflow intent matching always works.
    // The original text is already shown in the chat bubble above.
    final queryForDialogflow = _language == 'en'
        ? textToSend.trim()
        : translateQueryToEnglish(textToSend.trim());

    final reply = await _fetchDialogflowReply(queryForDialogflow);
    if (!mounted) return;
    setState(() {
      if (reply != null && reply.trim().isNotEmpty) {
        _messages.add(
          ChatMessage(
            text: reply.trim(),
            sender: MessageSender.bot,
            lang: _language,
            timestamp: DateTime.now(),
          ),
        );
      }
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _toggleVoiceInput() {
    if (_isListening) return;
    setState(() => _isListening = true);
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
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
                              'ASH ChatBot',
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
                        return const TypingBubble();
                      }
                      final message = _messages[index];
                      final isUser = message.sender == MessageSender.user;
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
                                    formatChatTime(message.timestamp),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: inputHintForLanguage(_language),
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
