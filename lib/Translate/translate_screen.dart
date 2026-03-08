import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// --- Translation Service ---
class TranslationService {
  final String _apiKey = 'AIzaSyDrYbv-AMJxGD018YWmwkkPYHz7NtUIfsc';

  Future<String> translate({
    required String text,
    required String targetLangCode,
  }) async {
    if (text.trim().isEmpty) return '';
    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$_apiKey',
    );
    try {
      final response = await http.post(
        url,
        body: {'q': text, 'target': targetLangCode, 'format': 'text'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['translations'][0]['translatedText'];
      }
      return 'Error: Could not translate';
    } catch (e) {
      return 'Check internet connection';
    }
  }
}

// --- Data Models ---
class Language {
  final String name;
  final String code;
  final String nativeName;
  const Language(this.name, this.code, this.nativeName);
}

const List<Language> kLanguages = [
  Language('English (US)', 'en-US', 'English'),
  Language('Malay', 'ms', 'Bahasa Melayu'),
  Language('Chinese (Simplified)', 'zh-CN', '简体中文'),
  Language('Spanish', 'es', 'Español'),
  Language('French', 'fr', 'Français'),
  Language('German', 'de', 'Deutsch'),
  Language('Japanese', 'ja', '日本語'),
];

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _textController = TextEditingController();
  final TranslationService _apiService = TranslationService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker();

  String _translatedText = '';
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  Timer? _debounce;

  Language _sourceLanguage = kLanguages[0];
  Language _targetLanguage = kLanguages[1];

  static const Color _primaryColor = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onError: (val) => debugPrint('onError: $val'),
      onStatus: (val) => debugPrint('onStatus: $val'),
    );
    if (mounted) setState(() {});
  }

  Future<void> _extractTextFromImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source);
      if (photo == null) return;

      setState(() => _isLoading = true);

      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      final String extractedText = recognizedText.text;
      textRecognizer.close();

      if (extractedText.isNotEmpty) {
        setState(() {
          _textController.text = extractedText;
          _onTextChanged(extractedText);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image')),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan Text from Image',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0FDFA),
                    child: Icon(Icons.camera_alt_rounded, color: _primaryColor),
                  ),
                  title: const Text('Take a Photo'),
                  subtitle: const Text('Use camera to capture text'),
                  onTap: () {
                    Navigator.pop(context);
                    _extractTextFromImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0FDFA),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: _primaryColor,
                    ),
                  ),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Pick an image with text'),
                  onTap: () {
                    Navigator.pop(context);
                    _extractTextFromImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize(
        onError: (val) => debugPrint('onError: $val'),
        onStatus: (val) => debugPrint('onStatus: $val'),
      );
      if (!_speechEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission denied. Please enable it in settings.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (val) {
        setState(() {
          _textController.text = val.recognizedWords;
          _onTextChanged(val.recognizedWords);
        });
      },
      localeId: _sourceLanguage.code,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _speakText() async {
    if (_translatedText.isEmpty) return;
    await _flutterTts.setLanguage(_targetLanguage.code);
    await _flutterTts.speak(_translatedText);
  }

  void _onTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (text.isNotEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() {
        _isLoading = false;
        _translatedText = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      await _performTranslation();
    });
  }

  Future<void> _performTranslation() async {
    if (_textController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final result = await _apiService.translate(
      text: _textController.text,
      targetLangCode: _targetLanguage.code,
    );
    if (mounted) {
      setState(() {
        _translatedText = result;
        _isLoading = false;
      });
    }
  }

  void _showLanguageSelector(bool isSource) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              Text(
                isSource ? 'Select Source Language' : 'Select Target Language',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: kLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = kLanguages[index];
                    return ListTile(
                      title: Text(lang.name),
                      subtitle: Text(lang.nativeName),
                      onTap: () {
                        setState(() {
                          if (isSource) {
                            _sourceLanguage = lang;
                            _textController.clear();
                            _translatedText = '';
                          } else {
                            _targetLanguage = lang;
                            if (_textController.text.isNotEmpty) {
                              _performTranslation();
                            }
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
      _textController.text = _translatedText;
      _translatedText = '';
      if (_textController.text.isNotEmpty) _performTranslation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Translate',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Language selector bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showLanguageSelector(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _sourceLanguage.name,
                              style: const TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: _primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    color: _primaryColor,
                    size: 28,
                  ),
                  onPressed: _swapLanguages,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showLanguageSelector(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _targetLanguage.name,
                              style: const TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: _primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Input card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sourceLanguage.nativeName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _textController,
                          onChanged: _onTextChanged,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            hintText:
                                _isListening
                                    ? 'Listening...'
                                    : 'Enter text to translate...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                _textController.clear();
                                setState(() => _translatedText = '');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Output card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primaryColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _targetLanguage.nativeName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: _primaryColor,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else
                          Text(
                            _translatedText.isEmpty
                                ? 'Translation will appear here...'
                                : _translatedText,
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  _translatedText.isEmpty
                                      ? Colors.grey
                                      : Colors.black87,
                            ),
                          ),
                        if (_translatedText.isNotEmpty) ...[
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  color: _primaryColor,
                                ),
                                onPressed: _speakText,
                                tooltip: 'Listen',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Camera / OCR button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  color: _primaryColor,
                  size: 26,
                ),
                onPressed: _showImageSourcePicker,
                tooltip: 'Scan text from image',
              ),
            ),
            const SizedBox(width: 16),
            // Mic button
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp: (_) => _stopListening(),
                onTapCancel: () => _stopListening(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent : _primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.redAccent : _primaryColor)
                            .withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isListening ? 'Listening...' : 'Hold to Speak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
