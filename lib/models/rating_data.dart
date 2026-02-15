class MealRating {
  final String ratingId;
  final String userName;
  final String userEmail;
  final String mealName;
  final String mealDate;
  final String mealTime;
  final Map<String, int> itemRatings;
  final int staffBehaviorRating;
  final int hygieneRating;
  final DateTime? timestamp;
  final DateTime? updatedAt;

  MealRating({
    this.ratingId = '',
    required this.userName,
    required this.userEmail,
    required this.mealName,
    required this.mealDate,
    required this.mealTime,
    required this.itemRatings,
    required this.staffBehaviorRating,
    required this.hygieneRating,
    this.timestamp,
    this.updatedAt,
  });
}

class RatingSubmission {
  final String userName;
  final String userEmail;
  final String mealName;
  final String mealDate;
  final String mealTime;
  final Map<String, int> itemRatings;
  final int staffBehaviorRating;
  final int hygieneRating;

  RatingSubmission({
    required this.userName,
    required this.userEmail,
    required this.mealName,
    required this.mealDate,
    required this.mealTime,
    required this.itemRatings,
    required this.staffBehaviorRating,
    required this.hygieneRating,
  });
}