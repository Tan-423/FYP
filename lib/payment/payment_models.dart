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
  });

  final String id;
  final String name;
  final double amount;
  final String date;
  final String status;
  final String method;
  final String source;
  final DateTime? createdAt;

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
    );
  }
}
