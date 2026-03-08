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
      return '打字或語音...';
    case 'en':
    default:
      return 'Type or speak...';
  }
}

// ---------------------------------------------------------------------------
// Translate BM / CN query text into English so Dialogflow intent matching
// works (the agent is trained in English only). The original text is still
// shown in the chat bubble — only the text sent to Dialogflow is translated.
// ---------------------------------------------------------------------------
String translateQueryToEnglish(String text) {
  var t = text.trim();

  // ── Bahasa Melayu token replacements ────────────────────────────────────
  // Order matters: longer / more-specific phrases first.
  const bmReplacements = <String, String>{
    // verbs / helpers
    'cari':          'find',
    'tunjuk':        'show',
    'senarai':       'list',
    'berikan':       'give',
    'boleh':         '',
    'tolong':        'please',
    'saya mahu':     'i want',
    'saya nak':      'i want',
    'nak':           'i want',

    // accommodation
    'penginapan':    'accommodation',
    'hotel':         'hotel',
    'resort':        'resort',
    'rumah tumpangan': 'guesthouse',

    // event types
    'acara makanan': 'food event',
    'acara muzik':   'music event',
    'acara budaya':  'culture event',
    'acara':         'event',
    'aktiviti':      'event',
    'makanan':       'food',
    'muzik':         'music',
    'budaya':        'culture',

    // locations
    'pulau pinang':  'Penang',
    'george town':   'Penang',
    'kuala lumpur':  'Kuala Lumpur',
    'kota kinabalu': 'Kota Kinabalu',
    'johor bahru':   'Johor Bahru',

    // prepositions
    ' di ':          ' in ',
    ' untuk ':       ' for ',
    ' dengan ':      ' with ',
  };

  // ── Chinese token replacements ───────────────────────────────────────────
  // Order matters: longer / more-specific phrases must come first.
  final cnReplacements = <String, String>{
    // ── question / filler words (strip these out) ──
    '有什么':   'find',   // "what is there" → find
    '有哪些':   'find',   // "which ones are there" → find
    '有没有':   'find',   // "are there any" → find
    '推荐':     'find',   // "recommend" → find
    '哪里有':   'find',   // "where to find" → find
    '哪里':     '',
    '什么':     '',
    '哪些':     '',
    '好的':     '',
    '最好':     'best',
    '附近':     'nearby',
    '给我':     '',
    '我想找':   'find',
    '我想要':   'i want',
    '我想':     'find',
    '我要':     'i want',
    '帮我找':   'find',
    '帮我':     '',
    '请':       '',

    // ── combined event phrases (must come before individual keywords) ──
    '美食活动': 'food event',
    '音乐活动': 'music event',
    '文化活动': 'culture event',

    // ── accommodation ──
    '住宿':     'accommodation',
    '酒店':     'hotel',
    '旅馆':     'hotel',
    '旅店':     'hotel',
    '民宿':     'guesthouse',
    '度假村':   'resort',

    // ── event types ──
    '活动':     'event',
    '美食':     'food',
    '食物':     'food',
    '音乐':     'music',
    '音樂':     'music',
    '文化':     'culture',

    // ── locations ──
    '哥打京那巴鲁': 'Kota Kinabalu',
    '吉隆坡':   'Kuala Lumpur',
    '槟城':     'Penang',
    '新山':     'Johor Bahru',
    '马六甲':   'Melaka',
    '兰卡威':   'Langkawi',
    '亚庇':     'Kota Kinabalu',
    '怡保':     'Ipoh',
    '古晋':     'Kuching',
    '柔佛巴鲁': 'Johor Bahru',
    '乔治市':   'Penang',

    // ── prepositions / particles ──
    '在':       'in',
    '的':       ' ',
    '里':       '',
  };

  // Apply BM replacements (case-insensitive word-level)
  bmReplacements.forEach((bm, en) {
    t = t.replaceAll(RegExp(bm, caseSensitive: false), en.isEmpty ? ' ' : ' $en ');
  });

  // Apply CN replacements — wrap every replacement in spaces so words don't
  // run together (Chinese text has no word separators).
  cnReplacements.forEach((cn, en) {
    t = t.replaceAll(cn, en.isEmpty ? ' ' : ' $en ');
  });

  // Strip any remaining Chinese/Japanese/Korean characters that weren't mapped
  t = t.replaceAll(RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]+'), ' ');

  // Collapse extra whitespace
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return t.isEmpty ? text.trim() : t;
}
