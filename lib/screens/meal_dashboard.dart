import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_data.dart';
import '../providers/meal_provider.dart';
import '../providers/auth_provider.dart';

class MealDashboard extends ConsumerWidget {
  const MealDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealScheduleState = ref.watch(mealProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar Header
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Anusha Mess',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              centerTitle: true,
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Current Meal Section
                if (mealScheduleState.currentMeal != null) ...[
                  _CurrentMealCard(
                    meal: mealScheduleState.currentMeal!,
                  ),
                  const SizedBox(height: 16),
                ],

                // Next Meal Section
                if (mealScheduleState.currentMeal == null &&
                    mealScheduleState.nextMeal != null) ...[
                  _UpNextMealCard(
                    meal: mealScheduleState.nextMeal!,
                    showRsvp: true,
                  ),
                ] else if (mealScheduleState.currentMeal != null &&
                    mealScheduleState.nextMeal != null) ...[
                  _UpNextMealCard(
                    meal: mealScheduleState.nextMeal!,
                    showRsvp: false,
                  ),
                ],

                // Next to Next Meal
                if (mealScheduleState.nextToNextMeal != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coming up later:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${mealScheduleState.nextToNextMeal!.name} at ${mealScheduleState.nextToNextMeal!.start}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // No meals message
                if (mealScheduleState.currentMeal == null &&
                    mealScheduleState.nextMeal == null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No upcoming meals for today.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentMealCard extends ConsumerWidget {
  final MealInfo meal;

  const _CurrentMealCard({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Now Serving:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              meal.name,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...meal.items.map(
                  (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $item',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _RsvpCard(mealInfo: meal),
          ],
        ),
      ),
    );
  }
}

class _UpNextMealCard extends ConsumerWidget {
  final MealInfo meal;
  final bool showRsvp;

  const _UpNextMealCard({
    required this.meal,
    required this.showRsvp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Up Next:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              meal.name,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            _CountdownTimer(targetDateTime: meal.dateTime),
            const SizedBox(height: 16),
            ...meal.items.map(
                  (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $item',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            if (showRsvp) ...[
              const SizedBox(height: 8),
              _RsvpCard(mealInfo: meal),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime targetDateTime;

  const _CountdownTimer({required this.targetDateTime});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final duration = widget.targetDateTime.difference(now);

    if (duration.isNegative) {
      setState(() => _timeLeft = 'Started!');
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      setState(() => _timeLeft = 'Starts in: ${hours}h ${minutes}m');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeLeft,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _RsvpCard extends ConsumerWidget {
  final MealInfo mealInfo;
  static const totalStudents = 600;

  const _RsvpCard({required this.mealInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealKey = createMealKey(mealInfo);
    final rsvpState = ref.watch(rsvpProvider(mealKey));
    final authState = ref.watch(authStateProvider);

    // No need for manual auth listener - provider handles it automatically

    return authState.when(
      data: (user) {
        final isSignedIn = user != null;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Are you joining us for ${mealInfo.name}?',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (!isSignedIn) ...[
                  Text(
                    'Please sign in to RSVP for this meal 👋',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ] else if (rsvpState.isLoading) ...[
                  const CircularProgressIndicator(),
                ] else if (rsvpState.userSelection == RsvpOption.none) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ref.read(rsvpProvider(mealKey).notifier).updateAttendance(
                              true,
                              user.uid,
                              user.displayName ?? 'User',
                              user.email ?? '',
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("Yes, I'm in! 🤤"),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ref.read(rsvpProvider(mealKey).notifier).updateAttendance(
                              false,
                              user.uid,
                              user.displayName ?? 'User',
                              user.email ?? '',
                            );
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Nah, skipping 😴'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'You chose: ${rsvpState.userSelection == RsvpOption.yes ? "Yes, I'm in! 🤤" : "Nah, skipping 😴"}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(rsvpProvider(mealKey).notifier).removeAttendance(user.uid);
                    },
                    child: const Text('Change my mind'),
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  '${rsvpState.yesCount} / $totalStudents students are heading to the mess.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: rsvpState.yesCount / totalStudents,
                ),

                if (rsvpState.yesCount > 0) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _showAttendeesDialog(context, rsvpState.attendeesList, mealInfo.name);
                    },
                    child: const Text("Click to see who's going"),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  void _showAttendeesDialog(BuildContext context, List<AttendeeInfo> attendees, String mealName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Students attending $mealName'),
        content: SizedBox(
          width: double.maxFinite,
          child: attendees.isEmpty
              ? const Text('Loading attendees...')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: attendees.length,
            itemBuilder: (context, index) {
              final attendee = attendees[index];
              return ListTile(
                title: Text(
                  attendee.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: attendee.email.isNotEmpty ? Text(attendee.email.split('@')[0]) : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}