import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/meal_data.dart';
import '../repositories/meal_repository.dart';
import 'auth_provider.dart';

// Provider for MealRepository
final mealRepositoryProvider = Provider((ref) => MealRepository());

// Provider for MealNotifier
final mealProvider = StateNotifierProvider<MealNotifier, MealScheduleState>((ref) {
  final repository = ref.watch(mealRepositoryProvider);
  return MealNotifier(repository);
});

// ✅ FIXED: Auto-dispose provider that rebuilds when user changes
final rsvpProvider = StateNotifierProvider.autoDispose.family<RsvpNotifier, RsvpState, String>(
      (ref, mealKey) {
    // Watch the current user - provider rebuilds when user changes
    final currentUser = ref.watch(currentUserProvider);

    final notifier = RsvpNotifier(mealKey, ref);

    // Check user's attendance when provider is created and user is signed in
    if (currentUser != null) {
      Future.microtask(() => notifier.checkUserAttendance(currentUser.uid));
    }

    return notifier;
  },
);

class MealNotifier extends StateNotifier<MealScheduleState> {
  final MealRepository _repository;
  Timer? _timer;

  MealNotifier(this._repository) : super(MealScheduleState()) {
    _startMealStateUpdates();
  }

  void _startMealStateUpdates() {
    _updateMealScheduleState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _updateMealScheduleState();
    });
  }

  Future<void> _updateMealScheduleState() async {
    final menuList = await _repository.getMenu();
    if (menuList != null && mounted) {
      state = _calculateMealState(menuList);
    }
  }

  MealScheduleState _calculateMealState(List<Menu> menuList) {
    final now = DateTime.now();
    final dateFormat = DateFormat('HH:mm');

    MealInfo? _getMealInfo(int dayOfWeek, String mealType, Menu menu, DateTime date) {
      Meal? meal;
      switch (mealType) {
        case 'Breakfast':
          meal = menu.breakfast;
          break;
        case 'Lunch':
          meal = menu.lunch;
          break;
        case 'Dinner':
          meal = menu.dinner;
          break;
        default:
          return null;
      }

      final startTime = dateFormat.parse(meal.start);
      final mealDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

      return MealInfo(
        name: mealType,
        start: meal.start,
        end: meal.end,
        items: meal.items,
        dateTime: mealDateTime,
      );
    }

    final meals = <MealInfo>[];

    // Get previous, current, and next day
    final days = [
      now.subtract(const Duration(days: 1)),
      now,
      now.add(const Duration(days: 1)),
    ];

    for (var date in days) {
      final dayName = DateFormat('EEEE').format(date);
      final menu = menuList.firstWhere(
            (m) => m.day.toLowerCase() == dayName.toLowerCase(),
        orElse: () => menuList.first, // Fallback
      );

      final breakfast = _getMealInfo(date.weekday, 'Breakfast', menu, date);
      final lunch = _getMealInfo(date.weekday, 'Lunch', menu, date);
      final dinner = _getMealInfo(date.weekday, 'Dinner', menu, date);

      if (breakfast != null) meals.add(breakfast);
      if (lunch != null) meals.add(lunch);
      if (dinner != null) meals.add(dinner);
    }

    meals.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    MealInfo? currentMeal;
    MealInfo? nextMeal;
    MealInfo? nextToNextMeal;
    MealInfo? previousMeal;

    int currentMealIndex = -1;

    // Find current meal
    for (int i = 0; i < meals.length; i++) {
      final meal = meals[i];
      final endTime = dateFormat.parse(meal.end);
      final mealEnd = DateTime(
        meal.dateTime.year,
        meal.dateTime.month,
        meal.dateTime.day,
        endTime.hour,
        endTime.minute,
      );

      if (now.isAfter(meal.dateTime) && now.isBefore(mealEnd)) {
        currentMealIndex = i;
        break;
      }
    }

    if (currentMealIndex != -1) {
      currentMeal = meals[currentMealIndex];
      if (currentMealIndex > 0) {
        previousMeal = meals[currentMealIndex - 1];
      }
      if (currentMealIndex + 1 < meals.length) {
        nextMeal = meals[currentMealIndex + 1];
      }
      if (currentMealIndex + 2 < meals.length) {
        nextToNextMeal = meals[currentMealIndex + 2];
      }
    } else {
      // No current meal, find next upcoming
      for (int i = 0; i < meals.length; i++) {
        final meal = meals[i];
        if (now.isBefore(meal.dateTime)) {
          if (i > 0) {
            previousMeal = meals[i - 1];
          }
          nextMeal = meal;
          if (i + 1 < meals.length) {
            nextToNextMeal = meals[i + 1];
          }
          break;
        }
      }
    }

    // If no current or next meal, use last meal as previous
    if (currentMeal == null && nextMeal == null && meals.isNotEmpty) {
      previousMeal = meals.last;
    }

    return MealScheduleState(
      currentMeal: currentMeal,
      nextMeal: nextMeal,
      nextToNextMeal: nextToNextMeal,
      previousMeal: previousMeal,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// RSVP with Firebase Realtime Database
// Structure: attendance/$date/$meal/$uid (matches existing Kotlin app)
class RsvpNotifier extends StateNotifier<RsvpState> {
  final String _mealKey;
  final Ref _ref;  // ✅ Store ref to access current user dynamically
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _attendanceSubscription;

  RsvpNotifier(this._mealKey, this._ref) : super(RsvpState(isLoading: true)) {
    _listenToAttendance();
  }

  // Parse mealKey (format: "2024-02-10_Breakfast") into date and meal
  Map<String, String> _parseMealKey() {
    final parts = _mealKey.split('_');
    return {
      'date': parts[0], // "2024-02-10"
      'meal': parts[1], // "Breakfast"
    };
  }

  void _listenToAttendance() {
    final parsed = _parseMealKey();
    final attendanceRef = _database
        .child('attendance')
        .child(parsed['date']!)
        .child(parsed['meal']!);

    _attendanceSubscription = attendanceRef.onValue.listen((event) {
      if (!mounted) return;

      if (event.snapshot.value == null) {
        state = RsvpState(
          yesCount: 0,
          userSelection: RsvpOption.none,
          attendeesList: [],
          isLoading: false,
        );
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final attendees = <AttendeeInfo>[];
      int yesCount = 0;

      data.forEach((userId, userData) {
        final userMap = Map<String, dynamic>.from(userData as Map);
        final isAttending = userMap['isAttending'] as bool? ?? false;

        if (isAttending) {
          yesCount++;
          attendees.add(AttendeeInfo(
            name: userMap['name'] as String? ?? 'Unknown',
            email: userMap['email'] as String? ?? '',
          ));
        }
      });

      if (mounted) {
        state = state.copyWith(
          yesCount: yesCount,
          attendeesList: attendees,
          isLoading: false,
        );
      }
    });
  }

  Future<void> updateAttendance(bool isAttending, String userId, String userName, String userEmail) async {
    try {
      final parsed = _parseMealKey();
      final attendanceRef = _database
          .child('attendance')
          .child(parsed['date']!)
          .child(parsed['meal']!)
          .child(userId);

      if (isAttending) {
        await attendanceRef.set({
          'isAttending': true,
          'name': userName,
          'email': userEmail,
          'timestamp': ServerValue.timestamp,
        });
        if (mounted) {
          state = state.copyWith(userSelection: RsvpOption.yes);
        }
      } else {
        await attendanceRef.set({
          'isAttending': false,
          'name': userName,
          'email': userEmail,
          'timestamp': ServerValue.timestamp,
        });
        if (mounted) {
          state = state.copyWith(userSelection: RsvpOption.no);
        }
      }
    } catch (e) {
      print('Error updating attendance: $e');
    }
  }

  Future<void> removeAttendance(String userId) async {
    try {
      final parsed = _parseMealKey();
      final attendanceRef = _database
          .child('attendance')
          .child(parsed['date']!)
          .child(parsed['meal']!)
          .child(userId);

      await attendanceRef.remove();
      if (mounted) {
        state = state.copyWith(userSelection: RsvpOption.none);
      }
    } catch (e) {
      print('Error removing attendance: $e');
    }
  }

  Future<void> checkUserAttendance(String userId) async {
    try {
      final parsed = _parseMealKey();
      final snapshot = await _database
          .child('attendance')
          .child(parsed['date']!)
          .child(parsed['meal']!)
          .child(userId)
          .get();

      if (mounted) {
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          final isAttending = data['isAttending'] as bool? ?? false;
          state = state.copyWith(
            userSelection: isAttending ? RsvpOption.yes : RsvpOption.no,
            isLoading: false,
          );
        } else {
          state = state.copyWith(
            userSelection: RsvpOption.none,
            isLoading: false,
          );
        }
      }
    } catch (e) {
      print('Error checking user attendance: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}

// Helper to create meal key from MealInfo
String createMealKey(MealInfo mealInfo) {
  final dateStr = DateFormat('yyyy-MM-dd').format(mealInfo.dateTime);
  return '${dateStr}_${mealInfo.name}';
}