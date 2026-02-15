import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_data.dart';
import '../providers/meal_provider.dart';
import 'meal_rating_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  MealInfo? _selectedMeal;

  @override
  Widget build(BuildContext context) {
    final mealScheduleState = ref.watch(mealProvider);

    if (_selectedMeal != null) {
      return MealRatingScreen(
        mealInfo: _selectedMeal!,
        onBack: () {
          setState(() => _selectedMeal = null);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tap on a meal to rate it',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.copyOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Current Meal
          if (mealScheduleState.currentMeal != null) ...[
            Text(
              'Current Meal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _MealCard(
              meal: mealScheduleState.currentMeal!,
              isCurrentMeal: true,
              onTap: () {
                setState(() => _selectedMeal = mealScheduleState.currentMeal);
              },
            ),
            const SizedBox(height: 16),
          ],

          // Previous Meal
          if (mealScheduleState.previousMeal != null) ...[
            Text(
              'Previous Meal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _MealCard(
              meal: mealScheduleState.previousMeal!,
              onTap: () {
                setState(() => _selectedMeal = mealScheduleState.previousMeal);
              },
            ),
          ],

          // No meals message
          if (mealScheduleState.currentMeal == null &&
              mealScheduleState.previousMeal == null) ...[
            Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    'No meals available to rate',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealInfo meal;
  final bool isCurrentMeal;
  final VoidCallback onTap;

  const _MealCard({
    required this.meal,
    this.isCurrentMeal = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isCurrentMeal
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surface;

    final textColor = isCurrentMeal
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return Card(
      color: cardColor,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meal.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (isCurrentMeal) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NOW',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meal.start} - ${meal.end}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd').format(meal.dateTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Items: ${meal.items.join(", ")}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 32,
                color: textColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Color {
  Color copyOpacity(double opacity) => withOpacity(opacity);
}