import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

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
  bool _dialogflowReady = false;
  AutoRefreshingAuthClient? _authClient;
  String? _projectId;
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  final SpeechToText _speechToText = SpeechToText();
  bool _speechAvailable = false;
  String _liveTranscript = '';

  String? _nearbyCity;

  @override
  void initState() {
    super.initState();
    _initDialogflow();
    _initSpeech();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeMessage());
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speechToText.initialize(
      onError: (error) {
        debugPrint('STT error: ${error.errorMsg}');
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _liveTranscript = '';
        });
      },
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _liveTranscript = '';
          });
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final raw = placemarks.first.locality ??
            placemarks.first.subAdministrativeArea ??
            placemarks.first.administrativeArea ??
            '';
        final normalized = _normalizeCityName(raw);
        if (normalized != null && mounted) {
          setState(() => _nearbyCity = normalized);
        }
      }
    } catch (e) {
      debugPrint('Location init error: $e');
    }
  }

  /// Maps reverse-geocoded place names to our supported city names.
  String? _normalizeCityName(String raw) {
    const cityMap = {
      'kuala lumpur': 'Kuala Lumpur',
      'federal territory of kuala lumpur': 'Kuala Lumpur',
      'george town': 'Penang',
      'penang': 'Penang',
      'pulau pinang': 'Penang',
      'langkawi': 'Langkawi',
      'melaka': 'Melaka',
      'malacca': 'Melaka',
      'johor bahru': 'Johor Bahru',
      'johor': 'Johor Bahru',
      'kota kinabalu': 'Kota Kinabalu',
      'sabah': 'Kota Kinabalu',
      'ipoh': 'Ipoh',
      'perak': 'Ipoh',
      'kuching': 'Kuching',
      'sarawak': 'Kuching',
    };
    return cityMap[raw.toLowerCase()];
  }

  static const _weatherEndpoint =
      'https://us-central1-fyp-project-7199d.cloudfunctions.net/getWeather';

  // Known city aliases — longest first so multi-word cities match before short ones.
  static const _cityAliases = [
    ['kuala lumpur', 'Kuala Lumpur'], ['kota kinabalu', 'Kota Kinabalu'],
    ['kota bharu', 'Kota Bharu'],     ['johor bahru', 'Johor Bahru'],
    ['pulau pinang', 'Penang'],        ['pulau langkawi', 'Langkawi'],
    ['george town', 'Penang'],         ['georgetown', 'Penang'],
    ['langkawi', 'Langkawi'],          ['melaka', 'Melaka'],
    ['malacca', 'Melaka'],             ['penang', 'Penang'],
    ['kuching', 'Kuching'],            ['johor', 'Johor Bahru'],
    ['sabah', 'Kota Kinabalu'],        ['ipoh', 'Ipoh'],
    ['kl', 'Kuala Lumpur'],            ['jb', 'Johor Bahru'],
    ['kk', 'Kota Kinabalu'],           ['kb', 'Kota Bharu'],
    // Chinese city names
    ['吉隆坡', 'Kuala Lumpur'], ['槟城', 'Penang'],  ['新山', 'Johor Bahru'],
    ['马六甲', 'Melaka'],        ['兰卡威', 'Langkawi'],
    ['哥打京那巴鲁', 'Kota Kinabalu'], ['亚庇', 'Kota Kinabalu'],
    ['怡保', 'Ipoh'],            ['古晋', 'Kuching'],
    ['柔佛巴鲁', 'Johor Bahru'], ['乔治市', 'Penang'],
  ];

  /// Returns the canonical city name if [text] is a weather query, null otherwise.
  String? _extractWeatherCity(String text) {
    final lower = text.toLowerCase();
    final isWeather =
        RegExp(r'\b(weather|forecast|temperature|rain|sunny|humid|hot|cold|climate)\b',
                caseSensitive: false)
            .hasMatch(lower) ||
        RegExp(r'\b(cuaca|suhu|ramalan|hujan|panas|sejuk|iklim)\b',
                caseSensitive: false)
            .hasMatch(lower) ||
        RegExp(r'(天气|气温|预报|下雨|温度|气候)').hasMatch(text);
    if (!isWeather) return null;

    for (final pair in _cityAliases) {
      final alias = pair[0];
      final canonical = pair[1];
      if (lower.contains(alias) || text.contains(alias)) return canonical;
    }
    return _nearbyCity; // fallback to GPS city
  }

  Future<void> _handleWeatherDirectly(String city) async {
    final uri = Uri.parse(_weatherEndpoint).replace(queryParameters: {
      'city': city,
      'lang': _language,
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 503) {
        _addBotMessage('⚠️ Weather service is not configured yet.');
        return;
      }
      if (response.statusCode == 404) {
        _addBotMessage('Sorry, I couldn\'t find weather data for "$city". Please check the city name.');
        return;
      }
      if (response.statusCode != 200) {
        _addBotMessage('Sorry, weather lookup failed. Please try again later.');
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final cityName = data['city'] as String;
      final temp     = data['temp'];
      final feels    = data['feels_like'];
      final humidity = data['humidity'];
      final wind     = data['wind_kmh'];
      final desc     = data['description'] as String;

      final msg = switch (_language) {
        'bm' => '🌤️ Cuaca di $cityName sekarang:\n\n🌡️ ${temp}°C (terasa seperti ${feels}°C)\n💧 Kelembapan: $humidity%\n🌬️ Angin: $wind km/j\n☁️ $desc',
        'cn' => '🌤️ ${cityName}当前天气：\n\n🌡️ ${temp}°C（体感 ${feels}°C）\n💧 湿度：$humidity%\n🌬️ 风速：$wind km/h\n☁️ $desc',
        _    => '🌤️ Weather in $cityName right now:\n\n🌡️ ${temp}°C (feels like ${feels}°C)\n💧 Humidity: $humidity%\n🌬️ Wind: $wind km/h\n☁️ $desc',
      };
      _addBotMessage(msg);
    } catch (_) {
      if (mounted) _addBotMessage('Sorry, weather lookup failed. Please check your connection.');
    }
  }

  void _showWelcomeMessage() {
    final locationLine = _nearbyCity != null
        ? switch (_language) {
            'bm' => '\n\n📍 Saya nampak anda berhampiran *$_nearbyCity*. Ketik "📍 Berhampiran $_nearbyCity" untuk cari penginapan atau cuaca di sana!',
            'cn' => '\n\n📍 您目前位于 *$_nearbyCity* 附近。点击「📍 附近 $_nearbyCity」查找住宿或天气！',
            _ => '\n\n📍 Looks like you\'re near *$_nearbyCity*. Tap "📍 Near $_nearbyCity" to find accommodation or check the weather there!',
          }
        : '';

    final greetings = {
      'en': '👋 Hi! I\'m ASH, your travel assistant.\n\nI can help you with:\n• 🏨 Finding accommodation\n• 🎉 Discovering events\n• 🎟️ Buying & managing tickets\n• 🌤️ Weather for any city\n• ❌ Cancellation & refund policy\n• 💳 Payment methods\n\nTap a suggestion below or type your question!$locationLine',
      'bm': '👋 Hai! Saya ASH, pembantu perjalanan anda.\n\nSaya boleh membantu anda dengan:\n• 🏨 Mencari penginapan\n• 🎉 Menjelajah acara\n• 🎟️ Membeli & mengurus tiket\n• 🌤️ Cuaca untuk mana-mana bandar\n• ❌ Polisi pembatalan & bayaran balik\n• 💳 Kaedah pembayaran\n\nKetik cadangan di bawah atau taip soalan anda!$locationLine',
      'cn': '👋 你好！我是 ASH，您的旅行助手。\n\n我可以帮助您：\n• 🏨 查找住宿\n• 🎉 发现活动\n• 🎟️ 购票和管理票务\n• 🌤️ 查询任意城市天气\n• ❌ 取消与退款政策\n• 💳 付款方式\n\n点击下方建议或输入您的问题！$locationLine',
    };
    _addBotMessage(greetings[_language] ?? greetings['en']!);
  }

  @override
  void dispose() {
    _authClient?.close();
    _speechToText.stop();
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

  void _addBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          sender: MessageSender.bot,
          lang: _language,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
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
      _authClient = await clientViaServiceAccount(credentials, const [
        'https://www.googleapis.com/auth/dialogflow',
      ]);
      _projectId = projectId;
      if (!mounted) return;
      setState(() => _dialogflowReady = true);
    } catch (error) {
      debugPrint('Dialogflow init failed: $error');
      if (!mounted) return;
      setState(() => _dialogflowReady = false);
      _addBotMessage(
        '⚠️ Chatbot failed to connect.\n\nError: $error\n\nPlease check your internet connection and restart the app.',
      );
    }
  }

  Future<String?> _fetchDialogflowReply(String message) async {
    if (!_dialogflowReady || _authClient == null || _projectId == null) {
      debugPrint('Dialogflow not ready — dialogflowReady=$_dialogflowReady authClient=$_authClient projectId=$_projectId');
      return null;
    }
    final uri = Uri.parse(
      'https://dialogflow.googleapis.com/v2/projects/$_projectId/agent/sessions/$_sessionId:detectIntent',
    );
    // Always use 'en' so Dialogflow's English-trained intents always match.
    // Pass the selected UI language in queryParams.payload so the fulfillment
    // can reply in the user's chosen language.
    final payloadFields = <String, dynamic>{
      'uiLang': {'stringValue': _language},
      if (_nearbyCity != null)
        'nearbyCity': {'stringValue': _nearbyCity},
    };
    final body = jsonEncode({
      'queryInput': {
        'text': {'text': message, 'languageCode': 'en'},
      },
      'queryParams': {
        'payload': {'fields': payloadFields},
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
      _addBotMessage('⚠️ Chatbot is not connected. Please check your internet and restart the app.');
      return;
    }

    // Weather queries are handled directly — bypass Dialogflow entirely to
    // avoid unreliable intent routing for different city names.
    final weatherCity = _extractWeatherCity(textToSend.trim());
    if (weatherCity != null) {
      await _handleWeatherDirectly(weatherCity);
      if (mounted) setState(() => _isTyping = false);
      return;
    }

    // Translate BM/CN to English so Dialogflow intent matching always works.
    // The original text is already shown in the chat bubble above.
    final queryForDialogflow =
        _language == 'en'
            ? textToSend.trim()
            : translateQueryToEnglish(textToSend.trim());

    final reply = await _fetchDialogflowReply(queryForDialogflow);
    if (!mounted) return;
    setState(() => _isTyping = false);
    if (reply != null && reply.trim().isNotEmpty) {
      _addBotMessage(reply.trim());
    } else {
      _addBotMessage("Sorry, I didn't understand that. Try asking about events, accommodation, ticket purchase, or cancellation policy.");
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
        _liveTranscript = '';
      });
      return;
    }

    if (!_speechAvailable) {
      _addBotMessage('⚠️ Speech recognition is not available on this device.');
      return;
    }

    // Map UI language to BCP-47 locale for the recogniser
    final localeId = switch (_language) {
      'bm' => 'ms_MY',
      'cn' => 'zh_CN',
      _ => 'en_US',
    };

    setState(() {
      _isListening = true;
      _liveTranscript = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _liveTranscript = result.recognizedWords);

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          final words = result.recognizedWords.trim();
          setState(() {
            _isListening = false;
            _liveTranscript = '';
            _inputController.text = words;
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: words.length),
            );
          });
          _handleSendMessage();
        }
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _showWelcomeMessage();
  }

  List<Widget> _buildSuggestionChips() {
    const chips = {
      'en': [
        ('Buy a ticket',        Icons.confirmation_number_outlined, 'How do I buy a ticket?'),
        ('Book accommodation',  Icons.hotel_outlined,               'How do I book accommodation?'),
        ('Cancellation policy', Icons.cancel_outlined,              'What is the cancellation policy?'),
        ('Seat types',          Icons.event_seat_outlined,          'What seat types are available?'),
        ('Payment method',      Icons.payment_outlined,             'What payment method is accepted?'),
        ('My tickets',          Icons.receipt_long_outlined,        'How do I view my tickets?'),
      ],
      'bm': [
        ('Beli tiket',          Icons.confirmation_number_outlined, 'Cara beli tiket'),
        ('Tempah penginapan',   Icons.hotel_outlined,               'Cara tempah penginapan'),
        ('Polisi pembatalan',   Icons.cancel_outlined,              'Dasar pembatalan'),
        ('Jenis tempat duduk',  Icons.event_seat_outlined,          'Jenis tempat duduk'),
        ('Kaedah bayaran',      Icons.payment_outlined,             'Kaedah bayaran'),
        ('Tiket saya',          Icons.receipt_long_outlined,        'Lihat tiket saya'),
      ],
      'cn': [
        ('购票',   Icons.confirmation_number_outlined, '如何购票'),
        ('预订住宿', Icons.hotel_outlined,               '如何预订住宿'),
        ('取消政策', Icons.cancel_outlined,              '取消政策'),
        ('座位类型', Icons.event_seat_outlined,          '座位类型'),
        ('付款方式', Icons.payment_outlined,             '付款方式'),
        ('我的票',  Icons.receipt_long_outlined,        '查看我的票'),
      ],
    };

    final list = chips[_language] ?? chips['en']!;
    final result = list.map<Widget>((chip) {
      final (label, icon, query) = chip;
      return SuggestionChip(
        label: label,
        icon: icon,
        onTap: () => _handleSendMessage(query),
      );
    }).toList();

    // Location-aware chip — shown only when GPS city is detected
    if (_nearbyCity != null) {
      final nearLabel = switch (_language) {
        'bm' => '📍 Berhampiran $_nearbyCity',
        'cn' => '📍 附近 $_nearbyCity',
        _ => '📍 Near $_nearbyCity',
      };
      final nearQuery = switch (_language) {
        'bm' => 'penginapan di $_nearbyCity',
        'cn' => '${_nearbyCity}的住宿',
        _ => 'accommodation in $_nearbyCity',
      };
      result.insert(
        0,
        SuggestionChip(
          label: nearLabel,
          icon: Icons.location_on_outlined,
          onTap: () => _handleSendMessage(nearQuery),
        ),
      );
    }

    // Weather chip — always shown
    final weatherLabel = switch (_language) {
      'bm' => '🌤️ Cuaca',
      'cn' => '🌤️ 天气',
      _ => '🌤️ Weather',
    };
    final weatherQuery = _nearbyCity != null
        ? switch (_language) {
            'bm' => 'Cuaca di $_nearbyCity',
            'cn' => '${_nearbyCity}的天气',
            _ => 'Weather in $_nearbyCity',
          }
        : switch (_language) {
            'bm' => 'Cuaca di Kuala Lumpur',
            'cn' => '吉隆坡的天气',
            _ => 'Weather in Kuala Lumpur',
          };
    result.add(
      SuggestionChip(
        label: weatherLabel,
        icon: Icons.wb_sunny_outlined,
        onTap: () => _handleSendMessage(weatherQuery),
      ),
    );

    return result;
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ASH ChatBot',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _dialogflowReady
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFFBBF24),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _dialogflowReady ? 'Connected' : 'Connecting...',
                                  style: const TextStyle(
                                    color: Color(0xFFDBEAFE),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                            if (value == null || value == _language) return;
                            setState(() => _language = value);
                            final notice = {
                              'en': '🇬🇧 Switched to English.',
                              'bm': '🇲🇾 Ditukar ke Bahasa Melayu.',
                              'cn': '🇨🇳 已切换为中文。',
                            };
                            _addBotMessage(notice[value] ?? '');
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
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildSuggestionChips(),
                    ),
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
                            isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color:
                                isUser ? headerColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                            border: Border.all(
                              color:
                                  isUser
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
                                      isUser
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
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
                                      color:
                                          isUser
                                              ? const Color(0xFFBFDBFE)
                                              : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  Text(
                                    formatChatTime(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color:
                                          isUser
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
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          textInputAction: TextInputAction.send,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (_inputController.text.trim().isNotEmpty && !_isTyping) {
                              _handleSendMessage();
                            }
                          },
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
                          color:
                              _isListening
                                  ? const Color(0xFFEF4444)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isTyping ? null : _toggleVoiceInput,
                          icon: const Icon(Icons.mic_rounded),
                          color:
                              _isListening
                                  ? Colors.white
                                  : _isTyping
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed:
                            _inputController.text.trim().isEmpty || _isTyping
                                ? null
                                : _handleSendMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                          shape: const CircleBorder(),
                          elevation: 2,
                        ),
                        child:
                            _isTyping
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
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _liveTranscript.isEmpty
                              ? 'Speak now…'
                              : _liveTranscript,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _liveTranscript.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: _liveTranscript.isEmpty
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: _toggleVoiceInput,
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
