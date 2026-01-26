import 'package:cloud_firestore/cloud_firestore.dart';

enum AccommodationView {
  auth,
  ownerLogin,
  home,
  explore,
  detail,
  booking,
  payment,
  trips,
  owner,
  publish,
}

class AccommodationItem {
  const AccommodationItem({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.type,
    required this.rating,
    required this.description,
    required this.facilities,
    required this.image,
    required this.roomTypes,
    required this.roomCapacities,
    required this.extraBedFee,
    this.ownerId,
    this.createdAt,
  });

  final String id;
  final String name;
  final String location;
  final double price;
  final String type;
  final double rating;
  final String description;
  final List<String> facilities;
  final String image;
  final Map<String, int> roomTypes;
  final Map<String, int> roomCapacities;
  final double extraBedFee;
  final String? ownerId;
  final DateTime? createdAt;

  factory AccommodationItem.fromMap(Map<String, dynamic> data, {required String id}) {
    final facilitiesRaw = data['facilities'];
    final roomTypesRaw = data['roomTypes'];
    final roomCapacitiesRaw = data['roomCapacities'];
    return AccommodationItem(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      location: (data['location'] as String?)?.trim() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      type: (data['type'] as String?)?.trim() ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      description: (data['description'] as String?)?.trim() ?? '',
      facilities:
          facilitiesRaw is List
              ? facilitiesRaw.map((value) => value.toString()).toList()
              : const [],
      image: (data['image'] as String?)?.trim() ?? '',
      roomTypes:
          roomTypesRaw is Map
              ? roomTypesRaw.map(
                (key, value) => MapEntry(
                  key.toString(),
                  value is num ? value.toInt() : int.tryParse('$value') ?? 0,
                ),
              )
              : const {},
      roomCapacities:
          roomCapacitiesRaw is Map
              ? roomCapacitiesRaw.map(
                (key, value) => MapEntry(
                  key.toString(),
                  value is num ? value.toInt() : int.tryParse('$value') ?? 0,
                ),
              )
              : const {},
      extraBedFee: (data['extraBedFee'] as num?)?.toDouble() ?? 0,
      ownerId: data['ownerId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class BookingItem {
  const BookingItem({
    required this.bookingId,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.roomType,
    required this.roomCount,
    required this.peopleCount,
    required this.childCount,
    required this.infantCount,
    required this.extraBed,
    required this.extraBedFee,
    required this.totalPaid,
    required this.accommodation,
  });

  final String bookingId;
  final String status;
  final String checkIn;
  final String checkOut;
  final String roomType;
  final int roomCount;
  final int peopleCount;
  final int childCount;
  final int infantCount;
  final bool extraBed;
  final double extraBedFee;
  final double totalPaid;
  final AccommodationItem accommodation;
}

class BookingRequest {
  const BookingRequest({
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.pricePerNight,
    required this.roomCount,
    required this.peopleCount,
    required this.childCount,
    required this.infantCount,
    required this.extraBed,
    required this.extraBedFee,
    required this.totalPrice,
  });

  final String roomType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final double pricePerNight;
  final int roomCount;
  final int peopleCount;
  final int childCount;
  final int infantCount;
  final bool extraBed;
  final double extraBedFee;
  final double totalPrice;
}

class AccommodationPaymentRecord {
  const AccommodationPaymentRecord({
    required this.paymentId,
    required this.accommodationId,
    required this.accommodationName,
    required this.amount,
    required this.status,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.pricePerNight,
    required this.roomCount,
    required this.peopleCount,
    required this.childCount,
    required this.infantCount,
    required this.extraBed,
    required this.extraBedFee,
  });

  final String paymentId;
  final String accommodationId;
  final String accommodationName;
  final double amount;
  final String status;
  final String roomType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final double pricePerNight;
  final int roomCount;
  final int peopleCount;
  final int childCount;
  final int infantCount;
  final bool extraBed;
  final double extraBedFee;
}

class NewPropertyForm {
  const NewPropertyForm({
    required this.name,
    required this.type,
    required this.location,
    required this.price,
    required this.description,
    required this.facilities,
    required this.roomTypes,
    required this.roomCapacities,
    required this.extraBedFee,
  });

  final String name;
  final String type;
  final String location;
  final double price;
  final String description;
  final List<String> facilities;
  final Map<String, int> roomTypes;
  final Map<String, int> roomCapacities;
  final double extraBedFee;
}

class NotificationItem {
  const NotificationItem({required this.id, required this.message});

  final int id;
  final String message;
}
