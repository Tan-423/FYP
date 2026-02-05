part of 'event_management.dart';

enum EventView {
  auth,
  organizerLogin,
  explore,
  detail,
  seatSelection,
  payment,
  tickets,
  manage,
  profile,
  organize,
  edit
}

class EventModel {
  EventModel({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.price,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.organizerId,
    required this.organizerName,
    required this.ticketTotal,
    required this.ticketsRemaining,
    required this.ticketsSold,
    required this.seatSelectionEnabled,
  });

  final String id;
  final String name;
  final String location;
  final String date;
  final double price;
  final String category;
  final String description;
  final String imageUrl;
  final String organizerId;
  final String organizerName;
  final int? ticketTotal;
  final int? ticketsRemaining;
  final int? ticketsSold;
  final bool seatSelectionEnabled;
}

class TicketModel {
  TicketModel({
    required this.ticketId,
    required this.purchaseDate,
    required this.event,
  });

  final String ticketId;
  final String purchaseDate;
  final EventModel event;
}

class EventSeat {
  EventSeat({
    required this.docId,
    required this.eventId,
    required this.seatId,
    required this.type,
    required this.price,
    required this.status,
    required this.heldBy,
    required this.heldUntil,
  });

  final String docId;
  final String eventId;
  final String seatId;
  final String type;
  final double price;
  final String status;
  final String? heldBy;
  final DateTime? heldUntil;
}

class SeatTypeOption {
  const SeatTypeOption({
    required this.type,
    required this.priceDelta,
  });

  final String type;
  final double priceDelta;
}

class PaymentRecord {
  const PaymentRecord({
    required this.paymentId,
    required this.eventId,
    required this.eventName,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  final String paymentId;
  final String eventId;
  final String eventName;
  final double amount;
  final String status;
  final DateTime? createdAt;
}
