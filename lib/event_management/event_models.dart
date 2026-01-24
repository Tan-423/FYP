part of 'event_management.dart';

enum EventView { explore, detail, tickets, organize }

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
    required this.organizer,
  });

  final String id;
  final String name;
  final String location;
  final String date;
  final double price;
  final String category;
  final String description;
  final String imageUrl;
  final String organizer;
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
