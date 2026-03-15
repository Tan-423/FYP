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
    'cari': 'find',
    'tunjuk': 'show',
    'senarai': 'list',
    'berikan': 'give',
    'boleh': '',
    'tolong': 'please',
    'saya mahu': 'i want',
    'saya nak': 'i want',
    'nak': 'i want',

    // accommodation
    'penginapan': 'accommodation',
    'hotel': 'hotel',
    'resort': 'resort',
    'rumah tumpangan': 'guesthouse',

    // event types
    'acara makanan': 'food event',
    'acara muzik': 'music event',
    'acara budaya': 'culture event',
    'acara': 'event',
    'aktiviti': 'event',
    'makanan': 'food',
    'muzik': 'music',
    'budaya': 'culture',

    // locations
    'pulau pinang': 'Penang',
    'george town': 'Penang',
    'kuala lumpur': 'Kuala Lumpur',
    'kota kinabalu': 'Kota Kinabalu',
    'johor bahru': 'Johor Bahru',

    // ticket & booking actions
    'beli tiket': 'buy ticket',
    'beli': 'buy',
    'tempah penginapan': 'book accommodation',
    'tempah hotel': 'book accommodation',
    'cara tempah': 'how to book accommodation',
    'cara beli tiket': 'how to buy ticket',
    'tempah': 'book',
    'tempahan saya': 'my booking',
    'tiket saya': 'my ticket',
    'lihat tiket': 'view my tickets',
    'lihat tempahan': 'view my bookings',
    'perjalanan saya': 'my trips',

    // cancellation & refund
    'batal tiket': 'cancel ticket',
    'batalkan tiket': 'cancel ticket',
    'batalkan': 'cancel',
    'dasar pembatalan': 'cancellation policy',
    'polisi pembatalan': 'cancellation policy',
    'bayaran balik': 'refund',

    // payment
    'cara bayar': 'how to pay',
    'kaedah bayaran': 'payment method',
    'bayaran gagal': 'payment failed',
    'bayaran tidak berjaya': 'payment failed',
    'cuba semula bayaran': 'retry payment',
    'bayar': 'pay',
    'bayaran': 'payment',

    // seat
    'pilih tempat duduk': 'choose seat',
    'jenis tempat duduk': 'seat types',
    'tempat duduk vip': 'vip seat',
    'tempat duduk': 'seat',

    // extra bed
    'katil tambahan': 'extra bed',
    'tambah katil': 'extra bed',
    'bayaran katil tambahan': 'extra bed fee',

    // weather
    'cuaca di': 'weather in',
    'ramalan cuaca': 'weather forecast',
    'cuaca': 'weather',
    'suhu': 'temperature',
    'ramalan': 'forecast',
    'hujan': 'rain',
    'panas': 'hot',
    'sejuk': 'cold',

    // ticket availability
    'tiket tersedia': 'tickets available',
    'tiket habis': 'sold out',
    'berapa tiket': 'how many tickets',

    // prepositions
    ' di ': ' in ',
    ' untuk ': ' for ',
    ' dengan ': ' with ',
  };

  // ── Chinese token replacements ───────────────────────────────────────────
  // Order matters: longer / more-specific phrases must come first.
  final cnReplacements = <String, String>{
    // ── question / filler words (strip these out) ──
    '有什么': 'find', // "what is there" → find
    '有哪些': 'find', // "which ones are there" → find
    '有没有': 'find', // "are there any" → find
    '推荐': 'find', // "recommend" → find
    '哪里有': 'find', // "where to find" → find
    '哪里': '',
    '什么': '',
    '哪些': '',
    '好的': '',
    '最好': 'best',
    '附近': 'nearby',
    '给我': '',
    '我想找': 'find',
    '我想要': 'i want',
    '我想': 'find',
    '我要': 'i want',
    '帮我找': 'find',
    '帮我': '',
    '请': '',

    // ── combined event phrases (must come before individual keywords) ──
    '美食活动': 'food event',
    '音乐活动': 'music event',
    '文化活动': 'culture event',

    // ── accommodation ──
    '住宿': 'accommodation',
    '酒店': 'hotel',
    '旅馆': 'hotel',
    '旅店': 'hotel',
    '民宿': 'guesthouse',
    '度假村': 'resort',

    // ── event types ──
    '活动': 'event',
    '美食': 'food',
    '食物': 'food',
    '音乐': 'music',
    '音樂': 'music',
    '文化': 'culture',

    // ── locations ──
    '哥打京那巴鲁': 'Kota Kinabalu',
    '吉隆坡': 'Kuala Lumpur',
    '槟城': 'Penang',
    '新山': 'Johor Bahru',
    '马六甲': 'Melaka',
    '兰卡威': 'Langkawi',
    '亚庇': 'Kota Kinabalu',
    '怡保': 'Ipoh',
    '古晋': 'Kuching',
    '柔佛巴鲁': 'Johor Bahru',
    '乔治市': 'Penang',

    // ── ticket & booking actions ──
    '如何购票': 'how to buy ticket',
    '怎么买票': 'how to buy ticket',
    '购票方法': 'how to buy ticket',
    '购票': 'buy ticket',
    '买票': 'buy ticket',
    '如何预订住宿': 'how to book accommodation',
    '怎么预订': 'how to book accommodation',
    '预订住宿': 'book accommodation',
    '预订酒店': 'book accommodation',
    '预订': 'book',
    '我的票': 'my ticket',
    '查看我的票': 'view my tickets',
    '我的预订': 'my booking',
    '查看预订': 'view my bookings',
    '我的行程': 'my trips',

    // ── cancellation & refund ──
    '取消票': 'cancel ticket',
    '取消机票': 'cancel ticket',
    '取消政策': 'cancellation policy',
    '退款政策': 'cancellation policy',
    '如何取消': 'cancel ticket',
    '退款': 'refund',
    '取消': 'cancel',

    // ── payment ──
    '付款方式': 'payment method',
    '如何付款': 'how to pay',
    '付款失败': 'payment failed',
    '付款不成功': 'payment failed',
    '重试付款': 'retry payment',
    '付款': 'payment',
    '付': 'pay',

    // ── seat ──
    '选择座位': 'choose seat',
    '座位类型': 'seat types',
    'vip座位': 'vip seat',
    '座位': 'seat',

    // ── extra bed ──
    '加床': 'extra bed',
    '额外床位': 'extra bed',
    '加床费': 'extra bed fee',

    // ── weather ──
    '天气怎样': 'weather',
    '天气如何': 'weather',
    '今天天气': 'weather today',
    '天气预报': 'weather forecast',
    '天气': 'weather',
    '气温': 'temperature',
    '预报': 'forecast',
    '下雨': 'rain',
    '下雨吗': 'is it raining',
    '温度': 'temperature',
    '气候': 'climate',

    // ── ticket availability ──
    '还有票吗': 'tickets available',
    '票卖完了吗': 'sold out',
    '剩余票数': 'how many tickets remaining',

    // ── prepositions / particles ──
    '在': 'in',
    '的': ' ',
    '里': '',
  };

  // Apply BM replacements (case-insensitive word-level)
  bmReplacements.forEach((bm, en) {
    t = t.replaceAll(
      RegExp(bm, caseSensitive: false),
      en.isEmpty ? ' ' : ' $en ',
    );
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
