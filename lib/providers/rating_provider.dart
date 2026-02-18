import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rating_data.dart';
import '../repositories/rating_repository.dart';
import 'auth_provider.dart';

final ratingRepositoryProvider = Provider((ref) => RatingRepository());

final ratingProvider = StateNotifierProvider<RatingNotifier, RatingScreenState>(
      (ref) => RatingNotifier(
    ref.watch(ratingRepositoryProvider),
    ref.watch(currentUserProvider),
  ),
);

class RatingScreenState {
  final Map<String, int> itemRatings;
  final int staffBehaviorRating;
  final int hygieneRating;
  final bool isSubmitting;
  final bool submitSuccess;
  final String? errorMessage;
  final MealRating? existingRating;
  final bool isLoading;

  RatingScreenState({
    this.itemRatings = const {},
    this.staffBehaviorRating = 0,
    this.hygieneRating = 0,
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.errorMessage,
    this.existingRating,
    this.isLoading = true,
  });

  RatingScreenState copyWith({
    Map<String, int>? itemRatings,
    int? staffBehaviorRating,
    int? hygieneRating,
    bool? isSubmitting,
    bool? submitSuccess,
    String? errorMessage,
    MealRating? existingRating,
    bool? isLoading,
    bool clearError = false,
  }) {
    return RatingScreenState(
      itemRatings: itemRatings ?? this.itemRatings,
      staffBehaviorRating: staffBehaviorRating ?? this.staffBehaviorRating,
      hygieneRating: hygieneRating ?? this.hygieneRating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess: submitSuccess ?? this.submitSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      existingRating: existingRating ?? this.existingRating,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RatingNotifier extends StateNotifier<RatingScreenState> {
  final RatingRepository _repository;
  final User? _currentUser;

  RatingNotifier(this._repository, this._currentUser) : super(RatingScreenState());

  Future<void> loadExistingRating(String mealDate, String mealTime) async {
    state = state.copyWith(isLoading: true);

    if (_currentUser == null || _currentUser!.email == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final existingRating = await _repository.getUserRatingForMeal(
      _currentUser!.email!,
      mealDate,
      mealTime,
    );

    if (existingRating != null) {
      state = RatingScreenState(
        itemRatings: existingRating.itemRatings,
        staffBehaviorRating: existingRating.staffBehaviorRating,
        hygieneRating: existingRating.hygieneRating,
        existingRating: existingRating,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void updateItemRating(String itemName, int rating) {
    final currentRatings = Map<String, int>.from(state.itemRatings);
    currentRatings[itemName] = rating;
    state = state.copyWith(itemRatings: currentRatings);
  }

  void updateStaffBehaviorRating(int rating) {
    state = state.copyWith(staffBehaviorRating: rating);
  }

  void updateHygieneRating(int rating) {
    state = state.copyWith(hygieneRating: rating);
  }

  Future<void> submitRating({
    required String mealName,
    required String mealDate,
    required String mealTime,
    required List<String> items,
    required bool isUpdate,
  }) async {
    if (_currentUser == null || _currentUser!.email == null) {
      state = state.copyWith(
        errorMessage: 'Please sign in to submit ratings',
      );
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    final userName = _currentUser!.displayName ?? 'User';
    final userEmail = _currentUser!.email!;

    // Validate all items rated
    final missingRatings = items.where((item) => !state.itemRatings.containsKey(item)).toList();
    if (missingRatings.isNotEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Please rate all items',
      );
      return;
    }

    if (state.staffBehaviorRating == 0 || state.hygieneRating == 0) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Please rate staff behavior and hygiene',
      );
      return;
    }

    final submission = RatingSubmission(
      userName: userName,
      userEmail: userEmail,
      mealName: mealName,
      mealDate: mealDate,
      mealTime: mealTime,
      itemRatings: state.itemRatings,
      staffBehaviorRating: state.staffBehaviorRating,
      hygieneRating: state.hygieneRating,
    );

    final result = await _repository.submitRating(submission);

    if (result.isSuccess) {
      state = state.copyWith(
        isSubmitting: false,
        submitSuccess: true,
      );
    } else {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: result.error?.toString() ?? 'Failed to submit rating',
      );
    }
  }

  void resetState() {
    state = RatingScreenState();
  }
}