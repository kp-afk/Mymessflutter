import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_data.dart';

class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use 'mealRatings' collection to match existing Firestore rules
  final String _collectionName = 'mealRatings';

  /// Helper to generate a unique, consistent ID for a user's specific meal rating
  String _generateDocId(String email, String date, String time) {
    // We replace dots/special chars to keep the Document ID clean
    String cleanEmail = email.toLowerCase().replaceAll(RegExp(r'[.@]+'), '_');
    return '${cleanEmail}_${date}_$time';
  }

  /// Submits a rating. If the rating exists, it updates; otherwise, it creates.
  Future<Result<String>> submitRating(RatingSubmission rating) async {
    try {
      final docId = _generateDocId(rating.userEmail, rating.mealDate, rating.mealTime);
      final docRef = _firestore.collection(_collectionName).doc(docId);

      // Using .set with merge: true allows this to act as both create and update
      await docRef.set({
        'userName': rating.userName,
        'userEmail': rating.userEmail,
        'mealName': rating.mealName,
        'mealDate': rating.mealDate,
        'mealTime': rating.mealTime,
        'itemRatings': rating.itemRatings,
        'staffBehaviorRating': rating.staffBehaviorRating,
        'hygieneRating': rating.hygieneRating,
        // We use set's merge behavior, but we update the timestamp logic
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return Result.success(docId);
    } catch (e) {
      return Result.failure(Exception('Failed to submit rating: $e'));
    }
  }

  Future<MealRating?> getUserRatingForMeal(
      String userEmail,
      String mealDate,
      String mealTime,
      ) async {
    try {
      // With deterministic IDs, we can fetch the document directly
      // instead of running a collection query (more efficient/cheaper)
      final docId = _generateDocId(userEmail, mealDate, mealTime);
      final doc = await _firestore.collection(_collectionName).doc(docId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;

      return MealRating(
        ratingId: doc.id,
        userName: data['userName'] ?? '',
        userEmail: data['userEmail'] ?? '',
        mealName: data['mealName'] ?? '',
        mealDate: data['mealDate'] ?? '',
        mealTime: data['mealTime'] ?? '',
        itemRatings: Map<String, int>.from(data['itemRatings'] ?? {}),
        staffBehaviorRating: data['staffBehaviorRating'] ?? 0,
        hygieneRating: data['hygieneRating'] ?? 0,
        timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      print('Error fetching user rating: $e');
      return null;
    }
  }

  Future<List<MealRating>> getAllRatingsForMeal(
      String mealDate,
      String mealTime,
      ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mealDate', isEqualTo: mealDate)
          .where('mealTime', isEqualTo: mealTime)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return MealRating(
          ratingId: doc.id,
          userName: data['userName'] ?? '',
          userEmail: data['userEmail'] ?? '',
          mealName: data['mealName'] ?? '',
          mealDate: data['mealDate'] ?? '',
          mealTime: data['mealTime'] ?? '',
          itemRatings: Map<String, int>.from(data['itemRatings'] ?? {}),
          staffBehaviorRating: data['staffBehaviorRating'] ?? 0,
          hygieneRating: data['hygieneRating'] ?? 0,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      print('Error fetching ratings: $e');
      return [];
    }
  }

  // This method remains for explicit updates, but submitRating now handles it too
  Future<Result<void>> updateRating(String ratingId, RatingSubmission rating) async {
    try {
      await _firestore.collection(_collectionName).doc(ratingId).update({
        'itemRatings': rating.itemRatings,
        'staffBehaviorRating': rating.staffBehaviorRating,
        'hygieneRating': rating.hygieneRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return Result.success(null);
    } catch (e) {
      return Result.failure(Exception('Failed to update rating: $e'));
    }
  }
}

// Simple Result class
class Result<T> {
  final T? _value;
  final Exception? _error;

  Result.success(this._value) : _error = null;
  Result.failure(this._error) : _value = null;

  bool get isSuccess => _error == null;
  T? get value => _value;
  Exception? get error => _error;
  Exception? exceptionOrNull() => _error;
}