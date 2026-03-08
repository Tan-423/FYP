part of 'payment_screen.dart';

class BookingItem {
  const BookingItem({
    required this.id,
    required this.type,
    required this.name,
    required this.date,
    required this.amount,
    required this.currency,
    required this.source,
    this.status,
    this.createdAt,
    this.eventDate,
    this.eventLocation,
    this.eventId,
    this.accommodationId,
    this.accommodationLocation,
    this.roomType,
    this.roomCount,
    this.peopleCount,
    this.childCount,
    this.infantCount,
    this.checkIn,
    this.checkOut,
    this.nights,
  });

  final String id;
  final String type;
  final String name;
  final String date;
  final double amount;
  final String currency;
  final String source;
  final String? status;
  final DateTime? createdAt;
  final String? eventDate;
  final String? eventLocation;
  final String? eventId;
  final String? accommodationId;
  final String? accommodationLocation;
  final String? roomType;
  final int? roomCount;
  final int? peopleCount;
  final int? childCount;
  final int? infantCount;
  final String? checkIn;
  final String? checkOut;
  final int? nights;

  bool get canRetry {
    final normalized = (status ?? '').toUpperCase();
    return normalized == 'FAILED' ||
        normalized == 'CANCELLED' ||
        normalized == 'RETRYING';
  }

  factory BookingItem.fromEventPayment(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final createdAt = _timestampFrom(data['CreatedAt']);
    return BookingItem(
      id: (data['PaymentId'] ?? id).toString(),
      type: 'Event',
      name: (data['EventName'] ?? 'Event').toString(),
      date: _dateStringFrom(createdAt),
      amount: _asDouble(data['Amount']),
      currency: (data['Currency'] ?? 'MYR').toString(),
      source: 'event',
      status: (data['Status'] ?? '').toString(),
      createdAt: createdAt,
      eventDate: _dateStringFromValue(data['EventDate'] ?? data['Date']),
      eventLocation: _stringFrom(
        data['EventLocation'] ?? data['Location'],
      ),
      eventId: _stringFrom(data['EventId']),
    );
  }

  factory BookingItem.fromAccommodationPayment(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final createdAt = _timestampFrom(data['CreatedAt']);
    final checkIn = _timestampFrom(data['CheckIn']);
    return BookingItem(
      id: (data['PaymentId'] ?? id).toString(),
      type: 'Accommodation',
      name: (data['AccommodationName'] ?? 'Accommodation').toString(),
      date: _dateStringFrom(checkIn ?? createdAt),
      amount: _asDouble(data['Amount']),
      currency: (data['Currency'] ?? 'MYR').toString(),
      source: 'accommodation',
      status: (data['Status'] ?? '').toString(),
      createdAt: createdAt ?? checkIn,
      accommodationId: _stringFrom(data['AccommodationId']),
      accommodationLocation: _stringFrom(data['AccommodationLocation']),
      roomType: _stringFrom(data['RoomType']),
      roomCount: _intFrom(data['RoomCount']),
      peopleCount: _intFrom(data['PeopleCount']),
      childCount: _intFrom(data['ChildCount']),
      infantCount: _intFrom(data['InfantCount']),
      checkIn: _dateStringFromValue(data['CheckIn']),
      checkOut: _dateStringFromValue(data['CheckOut']),
      nights: _intFrom(data['Nights']),
    );
  }

  static DateTime? _timestampFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _dateStringFrom(DateTime? date) {
    if (date == null) {
      return '';
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _dateStringFromValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      final parsed = DateTime.tryParse(trimmed);
      return parsed == null ? trimmed : _dateStringFrom(parsed);
    }
    final parsed = _timestampFrom(value);
    return _dateStringFrom(parsed);
  }

  static String _stringFrom(dynamic value) {
    if (value == null) {
      return '';
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }
    return text;
  }

  static int? _intFrom(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.status,
    required this.method,
    required this.source,
    this.createdAt,
    this.eventDate,
    this.eventLocation,
    this.eventId,
    this.accommodationId,
    this.accommodationLocation,
    this.roomType,
    this.roomCount,
    this.peopleCount,
    this.childCount,
    this.infantCount,
    this.checkIn,
    this.checkOut,
    this.nights,
  });

  final String id;
  final String name;
  final double amount;
  final String date;
  final String status;
  final String method;
  final String source;
  final DateTime? createdAt;
  final String? eventDate;
  final String? eventLocation;
  final String? eventId;
  final String? accommodationId;
  final String? accommodationLocation;
  final String? roomType;
  final int? roomCount;
  final int? peopleCount;
  final int? childCount;
  final int? infantCount;
  final String? checkIn;
  final String? checkOut;
  final int? nights;

  String get sourceLabel =>
      source == 'accommodation' ? 'Accommodation' : 'Event';

  factory TransactionItem.fromEventPayment(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final capturedAt = BookingItem._timestampFrom(data['CapturedAt']);
    final createdAt = BookingItem._timestampFrom(data['CreatedAt']);
    final dateSource = capturedAt ?? createdAt;
    return TransactionItem(
      id: (data['PaymentId'] ?? id).toString(),
      name: (data['EventName'] ?? 'Event').toString(),
      amount: BookingItem._asDouble(data['Amount']),
      date: BookingItem._dateStringFrom(dateSource),
      status: (data['Status'] ?? 'CAPTURED').toString(),
      method: 'PayPal',
      source: 'event',
      createdAt: dateSource,
      eventDate: BookingItem._dateStringFromValue(
        data['EventDate'] ?? data['Date'],
      ),
      eventLocation: BookingItem._stringFrom(
        data['EventLocation'] ?? data['Location'],
      ),
      eventId: BookingItem._stringFrom(data['EventId']),
    );
  }

  factory TransactionItem.fromAccommodationPayment(
    Map<String, dynamic> data, {
    required String id,
  }) {
    final capturedAt = BookingItem._timestampFrom(data['CapturedAt']);
    final createdAt = BookingItem._timestampFrom(data['CreatedAt']);
    final dateSource = capturedAt ?? createdAt;
    return TransactionItem(
      id: (data['PaymentId'] ?? id).toString(),
      name: (data['AccommodationName'] ?? 'Accommodation').toString(),
      amount: BookingItem._asDouble(data['Amount']),
      date: BookingItem._dateStringFrom(dateSource),
      status: (data['Status'] ?? 'CAPTURED').toString(),
      method: 'PayPal',
      source: 'accommodation',
      createdAt: dateSource,
      accommodationId: BookingItem._stringFrom(data['AccommodationId']),
      accommodationLocation: BookingItem._stringFrom(
        data['AccommodationLocation'],
      ),
      roomType: BookingItem._stringFrom(data['RoomType']),
      roomCount: BookingItem._intFrom(data['RoomCount']),
      peopleCount: BookingItem._intFrom(data['PeopleCount']),
      childCount: BookingItem._intFrom(data['ChildCount']),
      infantCount: BookingItem._intFrom(data['InfantCount']),
      checkIn: BookingItem._dateStringFromValue(data['CheckIn']),
      checkOut: BookingItem._dateStringFromValue(data['CheckOut']),
      nights: BookingItem._intFrom(data['Nights']),
    );
  }
}
