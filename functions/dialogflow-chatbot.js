'use strict';

/**
 * Dialogflow Fulfillment Webhook for Travel Planner Chatbot
 *
 * Features:
 * - Accommodation search by location
 * - Event search by type (Food, Music, Culture)
 * - Multilingual support: English (en), Bahasa Melayu (ms), Chinese (zh-CN / zh-TW)
 * - Smart location normalization (handles abbreviations, BM and Chinese location names)
 * - Event type normalization across languages
 * - Sorted results by price (lowest first)
 * - Limited results (max 5) to prevent overwhelming responses
 * - Enhanced error handling and logging
 * - Rich formatted responses with pricing and details
 * - Weather API integration via OpenWeatherMap
 * - Location-aware suggestions using user's nearby city
 */

const https = require('https');

// ---------------------------------------------------------------------------
// Fetch current weather from OpenWeatherMap (free tier)
// ---------------------------------------------------------------------------
function fetchWeatherData(city, apiKey) {
  return new Promise((resolve, reject) => {
    const encoded = encodeURIComponent(`${city},MY`);
    const url = `https://api.openweathermap.org/data/2.5/weather?q=${encoded}&appid=${apiKey}&units=metric`;
    https.get(url, (res) => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        try { resolve(JSON.parse(raw)); } catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

// Translate OpenWeatherMap English description to BM / Chinese
const WEATHER_DESC_MAP = {
  ms: {
    'clear sky': 'Langit cerah', 'few clouds': 'Sedikit berawan',
    'scattered clouds': 'Berawan berselerak', 'broken clouds': 'Berawan banyak',
    'overcast clouds': 'Mendung', 'light rain': 'Hujan ringan',
    'moderate rain': 'Hujan sederhana', 'heavy intensity rain': 'Hujan lebat',
    'thunderstorm': 'Ribut petir', 'drizzle': 'Gerimis', 'mist': 'Kabus',
    'fog': 'Kabus tebal', 'haze': 'Jerebu', 'smoke': 'Berasap',
  },
  zh: {
    'clear sky': '晴天', 'few clouds': '少云', 'scattered clouds': '多云',
    'broken clouds': '阴天', 'overcast clouds': '阴天', 'light rain': '小雨',
    'moderate rain': '中雨', 'heavy intensity rain': '大雨',
    'thunderstorm': '雷暴', 'drizzle': '毛毛雨', 'mist': '薄雾',
    'fog': '浓雾', 'haze': '霾', 'smoke': '烟雾',
  },
};

const fastProjectId = 'fyp-project-7199d';

process.env.GCLOUD_PROJECT = fastProjectId;

const functions = require('firebase-functions');
const { WebhookClient } = require('dialogflow-fulfillment');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: fastProjectId
});

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Multilingual response strings
// ---------------------------------------------------------------------------
const RESPONSES = {
  en: {
    noLocation: "Please specify a location. For example, try 'Penang' or 'Kuala Lumpur'.",
    noAccommodation: (city) =>
      `Sorry, I couldn't find any accommodations in ${city}. 🏨\n\nTry these popular destinations:\n• Kuala Lumpur\n• Penang\n• Langkawi\n• Melaka\n• Johor Bahru\n• Kota Kinabalu`,
    accommodationHeader: (count, city) =>
      `Found ${count} accommodation${count > 1 ? 's' : ''} in ${city}! 🏨\n\n`,
    moreAccommodations: (n) => `... and ${n} more options available.`,
    errorAccommodation: "Sorry, I encountered an error while searching for accommodations. Please try again later.",
    noEventType: "Please specify an event type. For example, try 'Food', 'Music', or 'Culture' events.",
    noEvents: (type) =>
      `Sorry, I couldn't find any ${type} events at the moment. 🎉\n\nTry these categories:\n• Food\n• Music\n• Culture`,
    eventsHeader: (count, type) =>
      `Found ${count} ${type} event${count > 1 ? 's' : ''}! 🎉\n\n`,
    moreEvents: (n) => `... and ${n} more events available.`,
    errorEvents: "Sorry, I encountered an error while searching for events. Please try again later.",
    priceNA: 'Price N/A',
    free: 'Free',
    dateTBA: 'Date TBA',
    locationTBA: 'Location TBA',

    howToBuyTicket:
      '🎟️ How to buy a ticket:\n1. Open the Events module\n2. Tap an event\n3. Tap "Join Event"\n\nFree events are confirmed instantly.\nPaid events proceed to PayPal checkout.',
    cancellationPolicy:
      '❌ Cancellation Policy:\nYou can cancel a ticket from the "My Tickets" tab.\n\n⚠️ Cancellations are NOT allowed within 3 days of the event.\nA refund will be processed if you are eligible.',
    paymentMethod:
      '💳 Payment Method:\nWe accept PayPal for all paid events and accommodation bookings.',
    seatTypes:
      '💺 Seat Types (for events with seat selection):\n• VIP (Row A) — base price + RM30\n• Premium (Row B–C) — base price + RM15\n• Standard (Row D+) — base price\n\n⏱️ Selected seats are held for 10 minutes.',
    howToBookAccommodation:
      '🏨 How to book accommodation:\n1. Open the Accommodation module\n2. Tap a property\n3. Tap "Book Now"\n4. Choose room type, dates & number of guests\n5. Complete payment via PayPal.',
    viewMyTickets:
      '🎟️ To view your tickets:\nTap the "Tickets" tab at the bottom of the Events screen.',
    viewMyBookings:
      '🏨 To view your accommodation bookings:\nTap the "Trips" tab at the bottom of the Accommodation screen.',
    failedPayment:
      '⚠️ Payment Failed?\nGo to the "My Tickets" tab → find the failed order → tap "Retry" to complete the payment.',
    extraBed:
      '🛏️ Extra Bed:\nYou can request an extra bed during the accommodation booking process.\nAn extra bed fee applies and varies by property.',
    noEventByName: (name) =>
      `Sorry, I couldn't find an event named "${name}". 🎉\n\nTry browsing by category: Food, Music, or Culture.`,
    ticketAvailable: (name, remaining) =>
      `✅ "${name}" still has ${remaining} ticket${remaining !== 1 ? 's' : ''} available.`,
    ticketSoldOut: (name) =>
      `😔 Sorry, "${name}" is sold out.`,
    ticketNoInfo: (name) =>
      `ℹ️ I found "${name}" but ticket availability info is not set by the organizer.`,
    errorTicket: 'Sorry, I encountered an error checking ticket availability. Please try again.',
    noWeatherCity: "Please specify a city for the weather. For example: 'Weather in Penang'.",
    weatherResult: (city, desc, temp, feels, humidity, wind) =>
      `🌤️ Weather in ${city} right now:\n\n🌡️ ${temp}°C (feels like ${feels}°C)\n💧 Humidity: ${humidity}%\n🌬️ Wind: ${wind} km/h\n☁️ ${desc}`,
    errorWeather: (city) =>
      `Sorry, I couldn't fetch weather for "${city}". Please check the city name and try again.`,
    cheapestAccommodation: (name, price, city) =>
      `🏆 Cheapest accommodation in ${city}:\n\n🏨 ${name}\n💰 RM${price}\n\nThis is the most affordable option available.`,
    mostExpensiveAccommodation: (name, price, city) =>
      `💎 Most expensive accommodation in ${city}:\n\n🏨 ${name}\n💰 RM${price}`,
  },
  ms: {
    noLocation: "Sila nyatakan lokasi. Contohnya, cuba 'Pulau Pinang' atau 'Kuala Lumpur'.",
    noAccommodation: (city) =>
      `Maaf, tiada penginapan dijumpai di ${city}. 🏨\n\nCuba destinasi popular ini:\n• Kuala Lumpur\n• Pulau Pinang\n• Langkawi\n• Melaka\n• Johor Bahru\n• Kota Kinabalu`,
    accommodationHeader: (count, city) =>
      `Dijumpai ${count} penginapan di ${city}! 🏨\n\n`,
    moreAccommodations: (n) => `... dan ${n} pilihan lagi tersedia.`,
    errorAccommodation: "Maaf, ralat berlaku semasa mencari penginapan. Sila cuba lagi kemudian.",
    noEventType: "Sila nyatakan jenis acara. Contohnya, cuba acara 'Makanan', 'Muzik', atau 'Budaya'.",
    noEvents: (type) =>
      `Maaf, tiada acara ${type} dijumpai buat masa ini. 🎉\n\nCuba kategori ini:\n• Makanan\n• Muzik\n• Budaya`,
    eventsHeader: (count, type) =>
      `Dijumpai ${count} acara ${type}! 🎉\n\n`,
    moreEvents: (n) => `... dan ${n} acara lagi tersedia.`,
    errorEvents: "Maaf, ralat berlaku semasa mencari acara. Sila cuba lagi kemudian.",
    priceNA: 'Harga Tiada',
    free: 'Percuma',
    dateTBA: 'Tarikh Belum Ditentukan',
    locationTBA: 'Lokasi Belum Ditentukan',

    howToBuyTicket:
      '🎟️ Cara membeli tiket:\n1. Buka modul Acara\n2. Ketik acara yang diminati\n3. Ketik "Join Event"\n\nAcara percuma disahkan serta-merta.\nAcara berbayar akan diteruskan ke pembayaran PayPal.',
    cancellationPolicy:
      '❌ Polisi Pembatalan:\nAnda boleh batalkan tiket dari tab "Tiket Saya".\n\n⚠️ Pembatalan TIDAK dibenarkan dalam masa 3 hari sebelum acara.\nBayaran balik akan diproses jika anda layak.',
    paymentMethod:
      '💳 Kaedah Pembayaran:\nKami menerima PayPal untuk semua acara berbayar dan tempahan penginapan.',
    seatTypes:
      '💺 Jenis Tempat Duduk (untuk acara dengan pilihan tempat duduk):\n• VIP (Baris A) — harga asas + RM30\n• Premium (Baris B–C) — harga asas + RM15\n• Standard (Baris D+) — harga asas\n\n⏱️ Tempat duduk ditahan selama 10 minit selepas dipilih.',
    howToBookAccommodation:
      '🏨 Cara menempah penginapan:\n1. Buka modul Penginapan\n2. Ketik hartanah pilihan\n3. Ketik "Book Now"\n4. Pilih jenis bilik, tarikh & bilangan tetamu\n5. Lengkapkan pembayaran melalui PayPal.',
    viewMyTickets:
      '🎟️ Untuk melihat tiket anda:\nKetik tab "Tickets" di bahagian bawah skrin Acara.',
    viewMyBookings:
      '🏨 Untuk melihat tempahan penginapan anda:\nKetik tab "Trips" di bahagian bawah skrin Penginapan.',
    failedPayment:
      '⚠️ Pembayaran Gagal?\nPergi ke tab "Tiket Saya" → cari pesanan yang gagal → ketik "Retry" untuk melengkapkan pembayaran.',
    extraBed:
      '🛏️ Katil Tambahan:\nAnda boleh meminta katil tambahan semasa proses tempahan penginapan.\nBayaran katil tambahan dikenakan dan berbeza mengikut hartanah.',
    noEventByName: (name) =>
      `Maaf, tiada acara bernama "${name}". 🎉\n\nCuba cari mengikut kategori: Makanan, Muzik, atau Budaya.`,
    ticketAvailable: (name, remaining) =>
      `✅ "${name}" masih ada ${remaining} tiket tersedia.`,
    ticketSoldOut: (name) =>
      `😔 Maaf, "${name}" telah habis dijual.`,
    ticketNoInfo: (name) =>
      `ℹ️ Acara "${name}" dijumpai tetapi maklumat tiket belum ditetapkan oleh penganjur.`,
    errorTicket: 'Maaf, ralat berlaku semasa menyemak ketersediaan tiket. Sila cuba lagi.',
    noWeatherCity: "Sila nyatakan bandar untuk cuaca. Contoh: 'Cuaca di Pulau Pinang'.",
    weatherResult: (city, desc, temp, feels, humidity, wind) =>
      `🌤️ Cuaca di ${city} sekarang:\n\n🌡️ ${temp}°C (terasa seperti ${feels}°C)\n💧 Kelembapan: ${humidity}%\n🌬️ Angin: ${wind} km/j\n☁️ ${desc}`,
    errorWeather: (city) =>
      `Maaf, gagal mendapatkan cuaca untuk "${city}". Sila semak nama bandar dan cuba lagi.`,
    cheapestAccommodation: (name, price, city) =>
      `🏆 Penginapan paling murah di ${city}:\n\n🏨 ${name}\n💰 RM${price}\n\nIni adalah pilihan paling berpatutan yang tersedia.`,
    mostExpensiveAccommodation: (name, price, city) =>
      `💎 Penginapan paling mahal di ${city}:\n\n🏨 ${name}\n💰 RM${price}`,
  },
  zh: {
    noLocation: "请指定位置。例如，试试「槟城」或「吉隆坡」。",
    noAccommodation: (city) =>
      `抱歉，在${city}找不到任何住宿。🏨\n\n试试这些热门目的地：\n• 吉隆坡\n• 槟城\n• 兰卡威\n• 马六甲\n• 新山\n• 哥打京那巴鲁`,
    accommodationHeader: (count, city) =>
      `在${city}找到${count}个住宿！🏨\n\n`,
    moreAccommodations: (n) => `...还有${n}个更多选项。`,
    errorAccommodation: "抱歉，搜索住宿时遇到错误。请稍后再试。",
    noEventType: "请指定活动类型。例如，试试「美食」、「音乐」或「文化」活动。",
    noEvents: (type) =>
      `抱歉，目前找不到任何${type}活动。🎉\n\n试试这些类别：\n• 美食\n• 音乐\n• 文化`,
    eventsHeader: (count, type) =>
      `找到${count}个${type}活动！🎉\n\n`,
    moreEvents: (n) => `...还有${n}个更多活动。`,
    errorEvents: "抱歉，搜索活动时遇到错误。请稍后再试。",
    priceNA: '价格未知',
    free: '免费',
    dateTBA: '日期待定',
    locationTBA: '地点待定',

    howToBuyTicket:
      '🎟️ 购票方法：\n1. 打开活动模块\n2. 点击活动\n3. 点击"Join Event"\n\n免费活动即时确认。\n付费活动将进入PayPal付款流程。',
    cancellationPolicy:
      '❌ 取消政策：\n您可以在"我的票"标签中取消票。\n\n⚠️ 活动前3天内不允许取消。\n如符合条件，将处理退款。',
    paymentMethod:
      '💳 付款方式：\n我们接受PayPal付款，适用于所有付费活动和住宿预订。',
    seatTypes:
      '💺 座位类型（适用于提供选座的活动）：\n• VIP（A排）— 基本价 + RM30\n• Premium（B–C排）— 基本价 + RM15\n• Standard（D排以上）— 基本价\n\n⏱️ 选座后保留10分钟。',
    howToBookAccommodation:
      '🏨 预订住宿方法：\n1. 打开住宿模块\n2. 点击物业\n3. 点击"Book Now"\n4. 选择房型、日期和人数\n5. 通过PayPal完成付款。',
    viewMyTickets:
      '🎟️ 查看您的票：\n点击活动界面底部的"Tickets"标签。',
    viewMyBookings:
      '🏨 查看您的住宿预订：\n点击住宿界面底部的"Trips"标签。',
    failedPayment:
      '⚠️ 付款失败？\n前往"我的票"标签 → 找到失败的订单 → 点击"Retry"完成付款。',
    extraBed:
      '🛏️ 加床服务：\n您可以在住宿预订过程中申请加床。\n加床费用因物业而异。',
    noEventByName: (name) =>
      `抱歉，找不到名为"${name}"的活动。🎉\n\n请按类别搜索：美食、音乐或文化。`,
    ticketAvailable: (name, remaining) =>
      `✅ "${name}"还有${remaining}张票可购买。`,
    ticketSoldOut: (name) =>
      `😔 抱歉，"${name}"已售罄。`,
    ticketNoInfo: (name) =>
      `ℹ️ 找到活动"${name}"，但主办方尚未设置票务信息。`,
    errorTicket: '抱歉，查询票务时遇到错误，请稍后再试。',
    noWeatherCity: '请指定城市查询天气。例如：「槟城的天气怎样？」',
    weatherResult: (city, desc, temp, feels, humidity, wind) =>
      `🌤️ ${city}当前天气：\n\n🌡️ ${temp}°C（体感 ${feels}°C）\n💧 湿度：${humidity}%\n🌬️ 风速：${wind} km/h\n☁️ ${desc}`,
    errorWeather: (city) =>
      `抱歉，无法获取"${city}"的天气信息。请检查城市名称后重试。`,
    cheapestAccommodation: (name, price, city) =>
      `🏆 ${city}最便宜的住宿：\n\n🏨 ${name}\n💰 RM${price}\n\n这是目前最实惠的选择。`,
    mostExpensiveAccommodation: (name, price, city) =>
      `💎 ${city}最贵的住宿：\n\n🏨 ${name}\n💰 RM${price}`,
  },
};

// ---------------------------------------------------------------------------
// Event type labels used in response text (per language)
// ---------------------------------------------------------------------------
const EVENT_TYPE_LABELS = {
  en: { Food: 'Food', Music: 'Music', Culture: 'Culture' },
  ms: { Food: 'Makanan', Music: 'Muzik', Culture: 'Budaya' },
  zh: { Food: '美食', Music: '音乐', Culture: '文化' },
};

// ---------------------------------------------------------------------------
// Map Flutter UI language codes → internal lang keys
// ---------------------------------------------------------------------------
function mapUiLang(uiLang) {
  if (!uiLang) return null;
  switch (uiLang.toLowerCase()) {
    case 'bm': return 'ms';
    case 'ms': return 'ms';
    case 'cn':
    case 'zh':
    case 'zh-cn':
    case 'zh-tw': return 'zh';
    case 'en': return 'en';
    default: return null;
  }
}

// ---------------------------------------------------------------------------
// Detect language from the actual query text as a fallback
// ---------------------------------------------------------------------------
function detectLanguageFromText(text) {
  if (!text) return null;

  // Chinese: any CJK Unified Ideograph character
  if (/[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/.test(text)) return 'zh';

  // Malay: common Malay words that are unlikely to appear in English queries
  const malayKeywords = [
    'saya', 'anda', 'di', 'ada', 'untuk', 'dengan', 'tidak', 'ini', 'itu',
    'hotel', 'penginapan', 'makanan', 'muzik', 'budaya', 'acara', 'cari',
    'tunjuk', 'boleh', 'mahu', 'nak', 'tolong', 'bantu', 'tempat', 'lokasi',
    'pulau', 'pinang', 'melaka', 'langkawi',
  ];
  const lower = text.toLowerCase();
  const wordBoundaryCheck = malayKeywords.some(kw => {
    const re = new RegExp(`(^|\\s)${kw}(\\s|$)`);
    return re.test(lower);
  });
  if (wordBoundaryCheck) return 'ms';

  return null;
}

// ---------------------------------------------------------------------------
// Resolve language key from Dialogflow locale string, with text fallback
// ---------------------------------------------------------------------------
function getLang(locale, queryText) {
  // 1. Trust an explicit non-English locale from Dialogflow
  if (locale) {
    const l = locale.toLowerCase();
    if (l.startsWith('ms') || l.startsWith('id')) return 'ms';
    if (l.startsWith('zh')) return 'zh';
  }

  // 2. Fall back to detecting from the actual query text
  const detected = detectLanguageFromText(queryText);
  if (detected) return detected;

  return 'en';
}

// ---------------------------------------------------------------------------
// Normalise location names (English, BM, Chinese variants → stored name)
// ---------------------------------------------------------------------------
function normalizeLocationName(location) {
  if (!location) return location;

  location = String(location).trim().replace(/\s+/g, ' ');

  const locationMap = {
    // Kuala Lumpur
    'kl': 'Kuala Lumpur',
    'k.l': 'Kuala Lumpur',
    'k.l.': 'Kuala Lumpur',
    'kuala lumpur': 'Kuala Lumpur',
    '吉隆坡': 'Kuala Lumpur',

    // Johor Bahru
    'jb': 'Johor Bahru',
    'j.b': 'Johor Bahru',
    'johor bahru': 'Johor Bahru',
    'johor': 'Johor Bahru',
    '新山': 'Johor Bahru',
    '柔佛巴鲁': 'Johor Bahru',

    // Penang
    'penang': 'Penang',
    'pulau pinang': 'Penang',
    'george town': 'Penang',
    'georgetown': 'Penang',
    '槟城': 'Penang',
    '槟州': 'Penang',
    '乔治市': 'Penang',

    // Melaka
    'melaka': 'Melaka',
    'malacca': 'Melaka',
    '马六甲': 'Melaka',

    // Langkawi
    'langkawi': 'Langkawi',
    'pulau langkawi': 'Langkawi',
    '兰卡威': 'Langkawi',

    // Kota Kinabalu
    'kota kinabalu': 'Kota Kinabalu',
    'kk': 'Kota Kinabalu',
    'kinabalu': 'Kota Kinabalu',
    'sabah': 'Kota Kinabalu',
    '哥打京那巴鲁': 'Kota Kinabalu',
    '亚庇': 'Kota Kinabalu',

    // Ipoh
    'ipoh': 'Ipoh',
    '怡保': 'Ipoh',

    // Kuching
    'kuching': 'Kuching',
    '古晋': 'Kuching',

    // Kota Bharu
    'kota bharu': 'Kota Bharu',
    'kb': 'Kota Bharu',
    '哥打巴鲁': 'Kota Bharu',
  };

  const lowerLocation = location.toLowerCase();
  // Check lowercase map first (handles ASCII entries)
  if (locationMap[lowerLocation]) return locationMap[lowerLocation];
  // Check original (handles Unicode/Chinese entries)
  if (locationMap[location]) return locationMap[location];
  return location;
}

// ---------------------------------------------------------------------------
// Extract location directly from raw query text (longest match wins)
// Handles cases where Dialogflow entity extraction truncates multi-word cities
// ---------------------------------------------------------------------------
function extractLocationFromText(text) {
  if (!text) return null;

  const locationAliases = [
    // Longest / most specific first so they match before shorter substrings
    ['kuala lumpur', 'Kuala Lumpur'],
    ['kota kinabalu', 'Kota Kinabalu'],
    ['kota bharu', 'Kota Bharu'],
    ['johor bahru', 'Johor Bahru'],
    ['pulau pinang', 'Penang'],
    ['pulau langkawi', 'Langkawi'],
    ['george town', 'Penang'],
    ['georgetown', 'Penang'],
    ['langkawi', 'Langkawi'],
    ['kinabalu', 'Kota Kinabalu'],
    ['melaka', 'Melaka'],
    ['malacca', 'Melaka'],
    ['penang', 'Penang'],
    ['kuching', 'Kuching'],
    ['johor', 'Johor Bahru'],
    ['sabah', 'Kota Kinabalu'],
    ['ipoh', 'Ipoh'],
    ['k.l.', 'Kuala Lumpur'],
    ['k.l', 'Kuala Lumpur'],
    ['kl', 'Kuala Lumpur'],
    ['jb', 'Johor Bahru'],
    ['kk', 'Kota Kinabalu'],
    ['kb', 'Kota Bharu'],
    // Chinese
    ['吉隆坡', 'Kuala Lumpur'],
    ['新山', 'Johor Bahru'],
    ['柔佛巴鲁', 'Johor Bahru'],
    ['槟城', 'Penang'],
    ['槟州', 'Penang'],
    ['乔治市', 'Penang'],
    ['马六甲', 'Melaka'],
    ['兰卡威', 'Langkawi'],
    ['哥打京那巴鲁', 'Kota Kinabalu'],
    ['亚庇', 'Kota Kinabalu'],
    ['怡保', 'Ipoh'],
    ['古晋', 'Kuching'],
    ['哥打巴鲁', 'Kota Bharu'],
  ];

  const lower = text.toLowerCase();
  for (const [alias, canonical] of locationAliases) {
    if (lower.includes(alias.toLowerCase()) || text.includes(alias)) {
      return canonical;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Normalise event types across languages → stored English value
// ---------------------------------------------------------------------------
function normalizeEventType(eventType) {
  const eventTypeMap = {
    // English (canonical)
    'food': 'Food',
    'music': 'Music',
    'culture': 'Culture',

    // Bahasa Melayu
    'makanan': 'Food',
    'muzik': 'Music',
    'budaya': 'Culture',

    // Chinese
    '美食': 'Food',
    '食物': 'Food',
    '音乐': 'Music',
    '音樂': 'Music',
    '文化': 'Culture',
  };

  const lower = String(eventType).trim().toLowerCase();
  if (eventTypeMap[lower]) return eventTypeMap[lower];
  if (eventTypeMap[eventType]) return eventTypeMap[eventType];

  // Fallback: capitalise first letter
  const s = String(eventType).trim();
  return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
}

// ---------------------------------------------------------------------------
// Format a date for the given language
// ---------------------------------------------------------------------------
function formatDate(dateValue, lang) {
  const localeMap = { en: 'en-MY', ms: 'ms-MY', zh: 'zh-CN' };
  const locale = localeMap[lang] || 'en-MY';
  try {
    if (dateValue && dateValue.toDate) {
      return dateValue.toDate().toLocaleDateString(locale, { year: 'numeric', month: 'short', day: 'numeric' });
    }
    if (typeof dateValue === 'string') {
      return new Date(dateValue).toLocaleDateString(locale, { year: 'numeric', month: 'short', day: 'numeric' });
    }
  } catch (_) {}
  return null;
}

// ===========================================================================
// Main export
// ===========================================================================
exports.dialogflowFirebaseFulfillment = functions.https.onRequest((request, response) => {
  const agent = new WebhookClient({ request, response });

  // Detect language priority:
  // 1. uiLang from queryParams.payload (set by the Flutter UI language dropdown)
  // 2. Dialogflow locale header
  // 3. Text-based detection from the query itself
  const queryText = (request.body && request.body.queryResult && request.body.queryResult.queryText) || '';
  const payloadFields =
    request.body &&
    request.body.originalDetectIntentRequest &&
    request.body.originalDetectIntentRequest.payload &&
    request.body.originalDetectIntentRequest.payload.fields;

  const payloadUiLang = payloadFields && payloadFields.uiLang && payloadFields.uiLang.stringValue;
  const nearbyCity    = payloadFields && payloadFields.nearbyCity && payloadFields.nearbyCity.stringValue;

  const lang = mapUiLang(payloadUiLang) || getLang(agent.locale, queryText);
  const R = RESPONSES[lang] || RESPONSES.en;

  // Words that Dialogflow may incorrectly extract as a location entity but are
  // actually English function/stop words with no geographic meaning.
  const INVALID_LOCATION_WORDS = new Set([
    'do', 'i', 'me', 'my', 'a', 'an', 'the', 'in', 'at', 'to', 'for', 'of',
    'how', 'what', 'where', 'when', 'why', 'can', 'could', 'would', 'should',
    'book', 'find', 'get', 'show', 'tell', 'help', 'any', 'some', 'please',
    'hotel', 'accommodation', 'accommodations', 'place', 'places', 'here', 'there',
  ]);

  // Returns 'cheapest' | 'expensive' | null depending on price intent in query.
  function detectPriceIntent(text) {
    const lower = (text || '').toLowerCase();
    const cheapPatterns = [
      /\b(cheap|cheapest|lowest\s+price|most\s+affordable|budget|affordable|inexpensive|best\s+deal|best\s+value|value\s+for\s+money)\b/i,
      /\b(murah|paling\s+murah|harga\s+terendah|berpatutan|jimat)\b/i,
      /(最便宜|最低价|便宜|实惠|划算|经济)/,
    ];
    const expensivePatterns = [
      /\b(expensive|most\s+expensive|highest\s+price|luxury|premium|priciest)\b/i,
      /\b(mahal|paling\s+mahal|harga\s+tertinggi|mewah)\b/i,
      /(最贵|最高价|最豪华)/,
    ];
    if (cheapPatterns.some(p => p.test(text))) return 'cheapest';
    if (expensivePatterns.some(p => p.test(text))) return 'expensive';
    return null;
  }

  // Returns true when the raw query is asking HOW to book (not searching by city).
  function isHowToBookQuery(text) {
    const lower = (text || '').toLowerCase();
    return (
      /how\s+(do\s+i|to|can\s+i|should\s+i)\s+(book|reserve|make\s+a\s+booking)/i.test(lower) ||
      /steps?\s+(to|for)\s+book/i.test(lower) ||
      lower === 'book accommodation' ||
      lower === 'book a hotel'
    );
  }

  // Returns true when the raw query is asking about weather/forecast.
  function isWeatherQuery(text) {
    const lower = (text || '').toLowerCase();
    return /\b(weather|forecast|temperature|rain|sunny|humid|hot|cold|climate)\b/i.test(lower) ||
           /\b(cuaca|suhu|ramalan|hujan|panas|sejuk|iklim)\b/i.test(lower) ||
           /[\u4e00-\u9fff]/.test(text) && /(天气|气温|预报|下雨|晴天|温度|气候)/.test(text);
  }

  // -------------------------------------------------------------------------
  // Accommodation intent handler
  // -------------------------------------------------------------------------
  async function handleAccommodation(agent) {
    // Dialogflow often misfires "weather in <city>" to this intent because it
    // finds a location entity. Redirect to the weather handler instead.
    if (isWeatherQuery(queryText)) {
      return handleWeather(agent);
    }

    // If the raw query is really a "how to book" question, serve the FAQ answer
    // directly — Dialogflow sometimes misfires and routes these to this intent.
    if (isHowToBookQuery(queryText)) {
      agent.add(R.howToBookAccommodation);
      return;
    }

    let city = agent.parameters['location'];

    // Always try to extract location from raw query text first — it is more
    // reliable than Dialogflow entity extraction, especially for Chinese queries
    // and multi-word cities (e.g. "Kota Kinabalu", "Johor Bahru").
    const locationFromQuery = extractLocationFromText(queryText);
    if (locationFromQuery) {
      city = locationFromQuery;
    } else {
      // Fall back to the Dialogflow parameter value
      if (!city) {
        // Last resort: use the user's detected nearby city
        if (nearbyCity) {
          city = nearbyCity;
        } else {
          agent.add(R.noLocation);
          return;
        }
      }

      // Handle case where Dialogflow returns a geo-city structured object
      if (typeof city === 'object' && !Array.isArray(city)) {
        city = city['city'] || city['name'] || city['original'] || JSON.stringify(city);
      }

      if (Array.isArray(city)) {
        const filterWords = ['find', 'show', 'suggest', 'get', 'search', 'accommodation', 'hotel',
                             'cari', 'tunjuk', 'penginapan', '查找', '搜索', '住宿'];
        const filtered = city.filter(item => !filterWords.includes(item.toLowerCase()));
        city = filtered.length > 0 ? filtered.join(' ') : city[city.length - 1];
      }

      city = normalizeLocationName(city);

      // Reject city values that are common English stop/function words — these
      // are extraction artefacts (e.g. "do" from "How do I book…").
      if (!city || INVALID_LOCATION_WORDS.has(city.toLowerCase())) {
        agent.add(R.noLocation);
        return;
      }
    }

    const priceIntent = detectPriceIntent(queryText);

    try {
      console.log(`[Accommodation Search] City: ${city} | Lang: ${lang} | PriceIntent: ${priceIntent}`);

      const accommodationRef = db.collection('accommodations');
      let snapshot = await accommodationRef.where('location', '==', city).get();

      if (snapshot.empty) {
        console.log(`[Accommodation Search] No exact match, trying case-insensitive`);
        const allAccommodations = await accommodationRef.get();
        const matches = [];

        allAccommodations.forEach(doc => {
          const data = doc.data();
          if (data.location && data.location.toLowerCase() === city.toLowerCase()) {
            matches.push(data);
          }
        });

        if (matches.length === 0) {
          console.log(`[Accommodation Search] No results found for: ${city}`);
          agent.add(R.noAccommodation(city));
          return;
        }

        formatAndSendResponse(agent, city, matches, lang, R, priceIntent);
        return;
      }

      const accommodations = [];
      snapshot.forEach(doc => accommodations.push(doc.data()));

      console.log(`[Accommodation Search] Found ${accommodations.length} results`);
      formatAndSendResponse(agent, city, accommodations, lang, R, priceIntent);

    } catch (error) {
      console.error("[Accommodation Search Error]:", error.message, error.stack);
      agent.add(R.errorAccommodation);
    }
  }

  // -------------------------------------------------------------------------
  // Event intent handler
  // -------------------------------------------------------------------------
  async function handleEvent(agent) {
    let eventType = agent.parameters['event-type'];

    if (!eventType) {
      agent.add(R.noEventType);
      return;
    }

    if (Array.isArray(eventType)) {
      const filterWords = ['any', 'show', 'find', 'get', 'search', 'event', 'events',
                           'acara', 'cari', '活动', '查找'];
      const filtered = eventType.filter(item => !filterWords.includes(item.toLowerCase()));
      eventType = filtered.length > 0 ? filtered.join(' ') : eventType[eventType.length - 1];
    }

    // Map to stored English value, then detect display label for current language
    const storedType = normalizeEventType(eventType);
    const displayType = (EVENT_TYPE_LABELS[lang] || EVENT_TYPE_LABELS.en)[storedType] || storedType;

    try {
      console.log(`[Event Search] Type: ${storedType} | Lang: ${lang}`);

      const eventRef = db.collection('Event');
      let snapshot = await eventRef.where('Type', '==', storedType).get();

      if (snapshot.empty) {
        console.log(`[Event Search] No results found for: ${storedType}`);
        agent.add(R.noEvents(displayType));
        return;
      }

      const events = [];
      snapshot.forEach(doc => events.push(doc.data()));

      console.log(`[Event Search] Found ${events.length} results`);
      formatAndSendEventResponse(agent, storedType, displayType, events, lang, R);

    } catch (error) {
      console.error("[Event Search Error]:", error.message, error.stack);
      agent.add(R.errorEvents);
    }
  }

  // -------------------------------------------------------------------------
  // Format accommodation response
  // -------------------------------------------------------------------------
  function formatAndSendResponse(agent, city, accommodations, lang, R, priceIntent = null) {
    // Sort ascending by price first (cheapest first)
    accommodations.sort((a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0));

    // If user asked for cheapest / most expensive, answer directly
    if (priceIntent === 'cheapest') {
      const best = accommodations[0];
      if (best && best.price) {
        agent.add(R.cheapestAccommodation(best.name || 'Hotel', best.price, city));
        return;
      }
    }
    if (priceIntent === 'expensive') {
      const best = accommodations[accommodations.length - 1];
      if (best && best.price) {
        agent.add(R.mostExpensiveAccommodation(best.name || 'Hotel', best.price, city));
        return;
      }
    }

    const MAX_RESULTS = 5;
    const totalCount = accommodations.length;
    const displayAccommodations = accommodations.slice(0, MAX_RESULTS);

    let responseText = R.accommodationHeader(totalCount, city);

    displayAccommodations.forEach((data, index) => {
      const name = data.name || 'Hotel';
      const price = data.price ? `RM${data.price}` : R.priceNA;
      // Highlight the cheapest with a trophy
      const prefix = index === 0 ? '🏆 ' : '';
      responseText += `${index + 1}. ${prefix}${name}\n`;
      responseText += `   💰 ${price}\n\n`;
    });

    if (totalCount > MAX_RESULTS) {
      responseText += R.moreAccommodations(totalCount - MAX_RESULTS);
    }

    agent.add(responseText.trim());
  }

  // -------------------------------------------------------------------------
  // Format event response
  // -------------------------------------------------------------------------
  function formatAndSendEventResponse(agent, storedType, displayType, events, lang, R) {
    const MAX_RESULTS = 5;

    events.sort((a, b) => {
      let dateA = a.Date && a.Date.toDate ? a.Date.toDate() : new Date(a.Date);
      let dateB = b.Date && b.Date.toDate ? b.Date.toDate() : new Date(b.Date);
      if (dateA.getTime() !== dateB.getTime()) return dateA - dateB;
      return (parseFloat(a.Price) || 0) - (parseFloat(b.Price) || 0);
    });

    const totalCount = events.length;
    const displayEvents = events.slice(0, MAX_RESULTS);

    let responseText = R.eventsHeader(totalCount, displayType);

    displayEvents.forEach((data, index) => {
      const name = data.Name || 'Event';
      const price = data.Price ? `RM${data.Price}` : R.free;
      const location = data.Location || R.locationTBA;
      const date = formatDate(data.Date, lang) || R.dateTBA;

      responseText += `${index + 1}. ${name}\n`;
      responseText += `   📍 ${location}\n`;
      responseText += `   📅 ${date}\n`;
      responseText += `   💰 ${price}\n\n`;
    });

    if (totalCount > MAX_RESULTS) {
      responseText += R.moreEvents(totalCount - MAX_RESULTS);
    }

    agent.add(responseText.trim());
  }

  // -------------------------------------------------------------------------
  // Weather intent handler — calls OpenWeatherMap API
  // -------------------------------------------------------------------------
  async function handleWeather(agent) {
    const apiKey = process.env.OPENWEATHER_API_KEY;
    if (!apiKey || apiKey === 'YOUR_OPENWEATHERMAP_API_KEY_HERE') {
      agent.add('⚠️ Weather service is not configured yet. Please contact the app developer.');
      return;
    }

    // Resolve city: Dialogflow entity → raw text extraction → nearby city fallback
    let city = agent.parameters['location'] || null;
    if (typeof city === 'object' && city !== null && !Array.isArray(city)) {
      city = city['city'] || city['name'] || city['original'] || null;
    }
    if (Array.isArray(city)) city = city[0] || null;

    const cityFromText = extractLocationFromText(queryText);
    if (cityFromText) city = cityFromText;

    if (!city && nearbyCity) city = nearbyCity;

    if (!city) {
      agent.add(R.noWeatherCity);
      return;
    }

    city = normalizeLocationName(city);

    try {
      console.log(`[Weather] City: ${city} | Lang: ${lang}`);
      const data = await fetchWeatherData(city, apiKey);

      if (data.cod !== 200) {
        console.log(`[Weather] API error: ${data.message}`);
        agent.add(R.errorWeather(city));
        return;
      }

      const temp     = Math.round(data.main.temp);
      const feels    = Math.round(data.main.feels_like);
      const humidity = data.main.humidity;
      const windKmh  = Math.round((data.wind.speed || 0) * 3.6);
      const descEn   = (data.weather[0].description || '').toLowerCase();
      const desc     = (WEATHER_DESC_MAP[lang] && WEATHER_DESC_MAP[lang][descEn]) || descEn;

      agent.add(R.weatherResult(city, desc, temp, feels, humidity, windKmh));
    } catch (error) {
      console.error('[Weather Error]:', error.message);
      agent.add(R.errorWeather(city));
    }
  }

  // -------------------------------------------------------------------------
  // Static FAQ handlers — no Firestore query needed
  // -------------------------------------------------------------------------
  function handleHowToBuyTicket(agent)        { agent.add(R.howToBuyTicket); }
  function handleCancellationPolicy(agent)    { agent.add(R.cancellationPolicy); }
  function handlePaymentMethod(agent)         { agent.add(R.paymentMethod); }
  function handleSeatTypes(agent)             { agent.add(R.seatTypes); }
  function handleHowToBookAccommodation(agent){ agent.add(R.howToBookAccommodation); }
  function handleViewMyTickets(agent)         { agent.add(R.viewMyTickets); }
  function handleViewMyBookings(agent)        { agent.add(R.viewMyBookings); }
  function handleFailedPayment(agent)         { agent.add(R.failedPayment); }
  function handleExtraBed(agent)              { agent.add(R.extraBed); }

  // -------------------------------------------------------------------------
  // Live Firestore handler — check ticket availability by event name
  // -------------------------------------------------------------------------
  async function handleTicketAvailability(agent) {
    const eventName = agent.parameters['event-name'] || queryText;
    if (!eventName || !eventName.trim()) {
      agent.add(R.noEventType);
      return;
    }
    try {
      const snapshot = await db.collection('Event').get();
      const lower = eventName.toLowerCase();
      let match = null;
      snapshot.forEach(doc => {
        const d = doc.data();
        const name = (d.Name || d.name || '').toLowerCase();
        if (name.includes(lower) || lower.includes(name)) {
          match = d;
        }
      });
      if (!match) {
        agent.add(R.noEventByName(eventName));
        return;
      }
      const remaining = match.TicketsRemaining != null ? match.TicketsRemaining : match.ticketsRemaining;
      const displayName = match.Name || match.name || eventName;
      if (remaining == null) {
        agent.add(R.ticketNoInfo(displayName));
      } else if (Number(remaining) <= 0) {
        agent.add(R.ticketSoldOut(displayName));
      } else {
        agent.add(R.ticketAvailable(displayName, Number(remaining)));
      }
    } catch (error) {
      console.error('[TicketAvailability Error]:', error.message);
      agent.add(R.errorTicket);
    }
  }

  let intentMap = new Map();
  intentMap.set('Accommodation', handleAccommodation);
  intentMap.set('Event', handleEvent);
  intentMap.set('HowToBuyTicket',           handleHowToBuyTicket);
  intentMap.set('CancellationPolicy',       handleCancellationPolicy);
  intentMap.set('PaymentMethod',            handlePaymentMethod);
  intentMap.set('SeatTypes',                handleSeatTypes);
  intentMap.set('HowToBookAccommodation',   handleHowToBookAccommodation);
  intentMap.set('ViewMyTickets',            handleViewMyTickets);
  intentMap.set('ViewMyBookings',           handleViewMyBookings);
  intentMap.set('FailedPayment',            handleFailedPayment);
  intentMap.set('ExtraBed',                 handleExtraBed);
  intentMap.set('TicketAvailability',       handleTicketAvailability);
  intentMap.set('WeatherQuery',             handleWeather);

  // Default Fallback — try to handle weather queries that Dialogflow couldn't
  // match to any intent, otherwise return a helpful generic message.
  async function handleFallback(agent) {
    if (isWeatherQuery(queryText)) {
      return handleWeather(agent);
    }
    const fallback = {
      en: "Sorry, I didn't understand that. Try asking about:\n• 🌤️ Weather in a city\n• 🏨 Accommodation\n• 🎉 Events\n• 🎟️ Tickets or cancellation policy",
      ms: "Maaf, saya tidak faham. Cuba tanya tentang:\n• 🌤️ Cuaca di sesebuah bandar\n• 🏨 Penginapan\n• 🎉 Acara\n• 🎟️ Tiket atau polisi pembatalan",
      zh: "抱歉，我没有理解您的问题。请尝试询问：\n• 🌤️ 某城市天气\n• 🏨 住宿\n• 🎉 活动\n• 🎟️ 票务或取消政策",
    };
    agent.add(fallback[lang] || fallback.en);
  }

  intentMap.set('Default Fallback Intent', handleFallback);

  return agent.handleRequest(intentMap);
});
