import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_data.dart';
import 'rating_repository.dart'; // For Result class

class ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper function to safely parse timestamp (handles both int and Timestamp)
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Future<Result<String>> submitComplaint(ComplaintSubmission complaint) async {
    try {
      final docRef = await _firestore.collection('complaints').add({
        'userName': complaint.userName,
        'userEmail': complaint.userEmail,
        'userId': complaint.userId,
        'complaintText': complaint.complaintText,
        'category': complaint.category,
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(Exception('Failed to submit complaint: $e'));
    }
  }

  Future<List<Complaint>> getUserComplaints(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('complaints')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Complaint(
          complaintId: doc.id,
          userName: data['userName'] ?? '',
          userEmail: data['userEmail'] ?? '',
          userId: data['userId'] ?? '',
          complaintText: data['complaintText'] ?? '',
          category: data['category'] ?? '',
          status: data['status'] ?? 'Pending',
          timestamp: _parseTimestamp(data['timestamp']),  // ← FIXED
          updatedAt: _parseTimestamp(data['updatedAt']),  // ← FIXED
        );
      }).toList();
    } catch (e) {
      print('Error fetching complaints: $e');
      return [];
    }
  }

  Stream<List<Complaint>> getUserComplaintsStream(String userId) {
    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Complaint(
          complaintId: doc.id,
          userName: data['userName'] ?? '',
          userEmail: data['userEmail'] ?? '',
          userId: data['userId'] ?? '',
          complaintText: data['complaintText'] ?? '',
          category: data['category'] ?? '',
          status: data['status'] ?? 'Pending',
          timestamp: _parseTimestamp(data['timestamp']),  // ← FIXED
          updatedAt: _parseTimestamp(data['updatedAt']),  // ← FIXED
        );
      }).toList();
    });
  }
}