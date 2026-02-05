enum BillTrackingView { dashboard, createBill, details, history, createGroup }

class BillUser {
  const BillUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });
  final String id;
  final String name;
  final String avatarUrl;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'avatarUrl': avatarUrl};
  }

  factory BillUser.fromMap(Map<String, dynamic> map) {
    return BillUser(
      id: map['id'] as String,
      name: map['name'] as String,
      avatarUrl: map['avatarUrl'] as String,
    );
  }
}

class BillGroup {
  const BillGroup({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.members,
  });
  final String id;
  final String ownerId;
  final String name;
  final List<BillUser> members;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  factory BillGroup.fromMap(Map<String, dynamic> map) {
    return BillGroup(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String,
      members:
          (map['members'] as List<dynamic>)
              .map((m) => BillUser.fromMap(m as Map<String, dynamic>))
              .toList(),
    );
  }
}

class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    required this.price,
    required this.assignedTo,
  });

  final String id;
  final String name;
  final double price;
  final List<String> assignedTo;

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price, 'assignedTo': assignedTo};
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      assignedTo: List<String>.from(map['assignedTo'] as List<dynamic>),
    );
  }
}

enum BillStatus { settled, pending }

class BillModel {
  const BillModel({
    required this.id,
    required this.groupId,
    required this.ownerId,
    required this.title,
    required this.date,
    required this.totalAmount,
    required this.currency,
    required this.exchangeRate,
    required this.items,
    required this.sst,
    required this.serviceCharge,
    required this.payerId,
    required this.status,
    required this.memberStatuses,
  });

  final String id;
  final String groupId;
  final String ownerId;
  final String title;
  final DateTime date;
  final double totalAmount;
  final String currency;
  final double exchangeRate;
  final List<BillItem> items;
  final double sst;
  final double serviceCharge;
  final String payerId;
  final BillStatus status;
  final Map<String, BillStatus> memberStatuses;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'ownerId': ownerId,
      'title': title,
      'date': date.millisecondsSinceEpoch,
      'totalAmount': totalAmount,
      'currency': currency,
      'exchangeRate': exchangeRate,
      'items': items.map((item) => item.toMap()).toList(),
      'sst': sst,
      'serviceCharge': serviceCharge,
      'payerId': payerId,
      'status': status.name,
      'memberStatuses': memberStatuses.map(
        (key, value) => MapEntry(key, value.name),
      ),
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      ownerId: map['ownerId'] as String? ?? '',
      title: map['title'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      currency: map['currency'] as String,
      exchangeRate: (map['exchangeRate'] as num).toDouble(),
      items:
          (map['items'] as List<dynamic>)
              .map((item) => BillItem.fromMap(item as Map<String, dynamic>))
              .toList(),
      sst: (map['sst'] as num).toDouble(),
      serviceCharge: (map['serviceCharge'] as num).toDouble(),
      payerId: map['payerId'] as String,
      status: BillStatus.values.firstWhere((e) => e.name == map['status']),
      memberStatuses: (map['memberStatuses'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, BillStatus.values.firstWhere((e) => e.name == value)),
      ),
    );
  }
}

class CurrencyInfo {
  const CurrencyInfo({
    required this.rate,
    required this.symbol,
    required this.name,
  });
  final double rate;
  final String symbol;
  final String name;
}

const Map<String, CurrencyInfo> billCurrencies = {
  // Rates are MYR per 1 unit of currency (approximate).
  'MYR': CurrencyInfo(rate: 1, symbol: 'RM', name: 'Ringgit Malaysia'),
  'SGD': CurrencyInfo(rate: 3.1, symbol: 'S\$', name: 'Singapore Dollar'),
  'USD': CurrencyInfo(rate: 4.7, symbol: '\$', name: 'US Dollar'),
  'THB': CurrencyInfo(rate: 0.13, symbol: 'THB', name: 'Thai Baht'),
  'JPY': CurrencyInfo(rate: 0.03, symbol: 'JPY', name: 'Japanese Yen'),
};

class UserSplit {
  UserSplit({required this.subtotal, required this.total, required this.items});

  double subtotal;
  double total;
  final List<SplitItem> items;
}

class SplitItem {
  SplitItem({required this.name, required this.share});

  final String name;
  final double share;
}

Map<String, UserSplit> calculateUserSplits(
  BillModel bill,
  List<BillUser> users,
) {
  final splits = <String, UserSplit>{};
  for (final user in users) {
    splits[user.id] = UserSplit(subtotal: 0, total: 0, items: []);
  }

  for (final item in bill.items) {
    if (item.assignedTo.isEmpty) continue;
    final share = item.price / item.assignedTo.length;
    for (final userId in item.assignedTo) {
      final split = splits[userId];
      if (split != null) {
        split.subtotal += share;
        split.items.add(SplitItem(name: item.name, share: share));
      }
    }
  }

  final taxMultiplier = 1 + ((bill.sst + bill.serviceCharge) / 100);
  for (final entry in splits.entries) {
    entry.value.total = entry.value.subtotal * taxMultiplier;
  }

  return splits;
}
