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
 */

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
  const payloadUiLang =
    request.body &&
    request.body.originalDetectIntentRequest &&
    request.body.originalDetectIntentRequest.payload &&
    request.body.originalDetectIntentRequest.payload.fields &&
    request.body.originalDetectIntentRequest.payload.fields.uiLang &&
    request.body.originalDetectIntentRequest.payload.fields.uiLang.stringValue;
  const lang = mapUiLang(payloadUiLang) || getLang(agent.locale, queryText);
  const R = RESPONSES[lang] || RESPONSES.en;

  // -------------------------------------------------------------------------
  // Accommodation intent handler
  // -------------------------------------------------------------------------
  async function handleAccommodation(agent) {
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
        agent.add(R.noLocation);
        return;
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

      if (!city) {
        agent.add(R.noLocation);
        return;
      }
    }

    try {
      console.log(`[Accommodation Search] City: ${city} | Lang: ${lang}`);

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

        formatAndSendResponse(agent, city, matches, lang, R);
        return;
      }

      const accommodations = [];
      snapshot.forEach(doc => accommodations.push(doc.data()));

      console.log(`[Accommodation Search] Found ${accommodations.length} results`);
      formatAndSendResponse(agent, city, accommodations, lang, R);

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
  function formatAndSendResponse(agent, city, accommodations, lang, R) {
    const MAX_RESULTS = 5;

    accommodations.sort((a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0));

    const totalCount = accommodations.length;
    const displayAccommodations = accommodations.slice(0, MAX_RESULTS);

    let responseText = R.accommodationHeader(totalCount, city);

    displayAccommodations.forEach((data, index) => {
      const name = data.name || 'Hotel';
      const price = data.price ? `RM${data.price}` : R.priceNA;

      responseText += `${index + 1}. ${name}\n`;
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

  let intentMap = new Map();
  intentMap.set('Accommodation', handleAccommodation);
  intentMap.set('Event', handleEvent);

  return agent.handleRequest(intentMap);
});
