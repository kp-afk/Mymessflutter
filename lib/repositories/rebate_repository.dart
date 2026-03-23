import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rebate_data.dart';
import 'rating_repository.dart'; // For Result class

class RebateRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Future<Result<String>> submitRebate(RebateSubmission rebate) async {
    try {
      final docRef = await _firestore.collection('rebates').add({
        'userName': rebate.userName,
        'userEmail': rebate.userEmail,
        'userId': rebate.userId,
        'startDate': Timestamp.fromDate(rebate.startDate),
        'endDate': Timestamp.fromDate(rebate.endDate),
        'reason': rebate.reason,
        'totalDays': rebate.totalDays,
        'status': 'Pending',
        'managerNote': null,
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': null,
      });

      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(Exception('Failed to submit rebate: $e'));
    }
  }

  Future<List<Rebate>> getUserRebates(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('rebates')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => _fromDoc(doc)).toList();
    } catch (e) {
      print('Error fetching rebates: $e');
      return [];
    }
  }

  Stream<List<Rebate>> getUserRebatesStream(String userId) {
    return _firestore
        .collection('rebates')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => _fromDoc(doc)).toList());
  }

  Rebate _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Rebate(
      rebateId: doc.id,
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userId: data['userId'] ?? '',
      startDate: _parseTimestamp(data['startDate']) ?? DateTime.now(),
      endDate: _parseTimestamp(data['endDate']) ?? DateTime.now(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'Pending',
      totalDays: data['totalDays'] ?? 0,
      managerNote: data['managerNote'],
      timestamp: _parseTimestamp(data['timestamp']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }
}