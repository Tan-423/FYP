import 'package:cloud_firestore/cloud_firestore.dart';

import 'bill_tracking_models.dart';

class BillTrackingFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names - clear and easy to understand
  static const String _groupsCollection = 'bill_groups';
  static const String _billsCollection = 'bills';

  // ==================== GROUPS ====================

  /// Get all groups as a stream (real-time updates)
  Stream<List<BillGroup>> getGroupsStream() {
    return _firestore
        .collection(_groupsCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BillGroup.fromMap(doc.data()))
              .toList();
        });
  }

  /// Get all groups once
  Future<List<BillGroup>> getGroups() async {
    final snapshot =
        await _firestore.collection(_groupsCollection).orderBy('name').get();
    return snapshot.docs.map((doc) => BillGroup.fromMap(doc.data())).toList();
  }

  /// Get a specific group by ID
  Future<BillGroup?> getGroup(String groupId) async {
    final doc =
        await _firestore.collection(_groupsCollection).doc(groupId).get();
    if (!doc.exists) return null;
    return BillGroup.fromMap(doc.data()!);
  }

  /// Create a new group
  Future<void> createGroup(BillGroup group) async {
    await _firestore
        .collection(_groupsCollection)
        .doc(group.id)
        .set(group.toMap());
  }

  /// Update an existing group
  Future<void> updateGroup(BillGroup group) async {
    await _firestore
        .collection(_groupsCollection)
        .doc(group.id)
        .update(group.toMap());
  }

  /// Delete a group
  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection(_groupsCollection).doc(groupId).delete();
  }

  // ==================== BILLS ====================

  /// Get all bills for a specific group as a stream (real-time updates)
  Stream<List<BillModel>> getBillsStream(String groupId) {
    return _firestore
        .collection(_billsCollection)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          final bills =
              snapshot.docs
                  .map((doc) => BillModel.fromMap(doc.data()))
                  .toList();
          bills.sort((a, b) => b.date.compareTo(a.date));
          return bills;
        });
  }

  /// Get all bills for a specific group once
  Future<List<BillModel>> getBills(String groupId) async {
    final snapshot =
        await _firestore
            .collection(_billsCollection)
            .where('groupId', isEqualTo: groupId)
            .get();
    final bills =
        snapshot.docs.map((doc) => BillModel.fromMap(doc.data())).toList();
    bills.sort((a, b) => b.date.compareTo(a.date));
    return bills;
  }

  /// Get all bills across all groups (for history view)
  Stream<List<BillModel>> getAllBillsStream() {
    return _firestore
        .collection(_billsCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BillModel.fromMap(doc.data()))
              .toList();
        });
  }

  /// Get a specific bill by ID
  Future<BillModel?> getBill(String billId) async {
    final doc = await _firestore.collection(_billsCollection).doc(billId).get();
    if (!doc.exists) return null;
    return BillModel.fromMap(doc.data()!);
  }

  /// Create a new bill
  Future<void> createBill(BillModel bill) async {
    await _firestore
        .collection(_billsCollection)
        .doc(bill.id)
        .set(bill.toMap());
  }

  /// Update an existing bill
  Future<void> updateBill(BillModel bill) async {
    await _firestore
        .collection(_billsCollection)
        .doc(bill.id)
        .update(bill.toMap());
  }

  /// Delete a bill
  Future<void> deleteBill(String billId) async {
    await _firestore.collection(_billsCollection).doc(billId).delete();
  }

  /// Delete all bills for a specific group (useful when deleting a group)
  Future<void> deleteBillsByGroup(String groupId) async {
    final snapshot =
        await _firestore
            .collection(_billsCollection)
            .where('groupId', isEqualTo: groupId)
            .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
