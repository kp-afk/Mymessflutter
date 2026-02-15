import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_data.dart';
import '../providers/rating_provider.dart';

class MealRatingScreen extends ConsumerStatefulWidget {
  final MealInfo mealInfo;
  final VoidCallback onBack;

  const MealRatingScreen({
    super.key,
    required this.mealInfo,
    required this.onBack,
  });

  @override
  ConsumerState<MealRatingScreen> createState() => _MealRatingScreenState();
}

class _MealRatingScreenState extends ConsumerState<MealRatingScreen> {
  @override
  void initState() {
    super.initState();
    // Reset and load existing rating
    Future.microtask(() {
      ref.read(ratingProvider.notifier).resetState();
      ref.read(ratingProvider.notifier).loadExistingRating(
        DateFormat('yyyy-MM-dd').format(widget.mealInfo.dateTime),
        widget.mealInfo.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratingState = ref.watch(ratingProvider);

    // Navigate back on success
    ref.listen(ratingProvider, (previous, next) {
      if (next.submitSuccess && !(previous?.submitSuccess ?? false)) {
        widget.onBack();
        ref.read(ratingProvider.notifier).resetState();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Rate ${widget.mealInfo.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: ratingState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Meal Info Header
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.mealInfo.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.mealInfo.start} - ${widget.mealInfo.end}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.7),
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(widget.mealInfo.dateTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Existing rating warning
          if (ratingState.existingRating != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ You have already rated this meal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitting again will update your previous rating.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Food Items Section
          Text(
            'Rate Food Items',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ...widget.mealInfo.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FoodItemRatingCard(
                itemName: item,
                rating: ratingState.itemRatings[item] ?? 0,
                onRatingChange: (rating) {
                  ref.read(ratingProvider.notifier).updateItemRating(item, rating);
                },
              ),
            );
          }),

          const SizedBox(height: 24),

          // Service Quality Section
          Text(
            'Service Quality',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _ServiceRatingCard(
            title: 'Staff Behavior',
            description: 'Rate the courtesy and helpfulness of the staff',
            rating: ratingState.staffBehaviorRating,
            onRatingChange: (rating) {
              ref.read(ratingProvider.notifier).updateStaffBehaviorRating(rating);
            },
          ),

          const SizedBox(height: 12),

          _ServiceRatingCard(
            title: 'Hygiene & Cleanliness',
            description: 'Rate the cleanliness of the dining area and food service',
            rating: ratingState.hygieneRating,
            onRatingChange: (rating) {
              ref.read(ratingProvider.notifier).updateHygieneRating(rating);
            },
          ),

          // Error message
          if (ratingState.errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  ratingState.errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Submit Button
          FilledButton(
            onPressed: ratingState.isSubmitting
                ? null
                : () {
              ref.read(ratingProvider.notifier).submitRating(
                mealName: widget.mealInfo.name,
                mealDate: DateFormat('yyyy-MM-dd')
                    .format(widget.mealInfo.dateTime),
                mealTime: widget.mealInfo.name,
                items: widget.mealInfo.items,
                isUpdate: ratingState.existingRating != null,
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: ratingState.isSubmitting
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              ratingState.existingRating != null
                  ? 'Update Rating'
                  : 'Submit Rating',
              style: const TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FoodItemRatingCard extends StatelessWidget {
  final String itemName;
  final int rating;
  final ValueChanged<int> onRatingChange;

  const _FoodItemRatingCard({
    required this.itemName,
    required this.rating,
    required this.onRatingChange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _StarRatingBar(
              rating: rating,
              onRatingChange: onRatingChange,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRatingCard extends StatelessWidget {
  final String title;
  final String description;
  final int rating;
  final ValueChanged<int> onRatingChange;

  const _ServiceRatingCard({
    required this.title,
    required this.description,
    required this.rating,
    required this.onRatingChange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSecondaryContainer
                    .withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            _StarRatingBar(
              rating: rating,
              onRatingChange: onRatingChange,
              tint: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRatingBar extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChange;
  final Color? tint;

  const _StarRatingBar({
    required this.rating,
    required this.onRatingChange,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = tint ?? Theme.of(context).colorScheme.primary;

    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () => onRatingChange(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starValue <= rating ? Icons.star : Icons.star_border,
              size: 36,
              color: starValue <= rating
                  ? starColor
                  : starColor.withOpacity(0.3),
            ),
          ),
        );
      }),
    );
  }
}