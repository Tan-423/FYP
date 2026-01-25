part of 'event_management.dart';

enum EventView {
  auth,
  organizerLogin,
  explore,
  detail,
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
