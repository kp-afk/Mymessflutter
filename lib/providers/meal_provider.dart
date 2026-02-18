import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_data.dart';
import '../repositories/meal_repository.dart';
import 'auth_provider.dart';

// ─── Repository provider ──────────────────────────────────────────────────

final mealRepositoryProvider = Provider((ref) => MealRepository());

// ─── Meal schedule provider ───────────────────────────────────────────────

final mealProvider = StateNotifierProvider<MealNotifier, MealScheduleState>((ref) {
  final repository = ref.watch(mealRepositoryProvider);
  return MealNotifier(repository);
});

// ─── RSVP provider ────────────────────────────────────────────────────────
//
// Auto-dispose + family: one instance per mealKey, torn down when off-screen.
// Rebuilds automatically when the signed-in user changes (via currentUserProvider).

final rsvpProvider = StateNotifierProvider.autoDispose
    .family<RsvpNotifier, RsvpState, String>((ref, mealKey) {
  final currentUser = ref.watch(currentUserProvider);
  return RsvpNotifier(mealKey, ref, currentUser?.uid);
});

// ─── MealNotifier (unchanged logic) ──────────────────────────────────────

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
        date.year, date.month, date.day,
        startTime.hour, startTime.minute,
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
    final days = [
      now.subtract(const Duration(days: 1)),
      now,
      now.add(const Duration(days: 1)),
    ];

    for (var date in days) {
      final dayName = DateFormat('EEEE').format(date);
      final menu = menuList.firstWhere(
            (m) => m.day.toLowerCase() == dayName.toLowerCase(),
        orElse: () => menuList.first,
      );
      for (final type in ['Breakfast', 'Lunch', 'Dinner']) {
        final info = _getMealInfo(date.weekday, type, menu, date);
        if (info != null) meals.add(info);
      }
    }

    meals.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    MealInfo? currentMeal, nextMeal, nextToNextMeal, previousMeal;
    int currentMealIndex = -1;

    for (int i = 0; i < meals.length; i++) {
      final meal = meals[i];
      final endTime = dateFormat.parse(meal.end);
      final mealEnd = DateTime(
        meal.dateTime.year, meal.dateTime.month, meal.dateTime.day,
        endTime.hour, endTime.minute,
      );
      if (now.isAfter(meal.dateTime) && now.isBefore(mealEnd)) {
        currentMealIndex = i;
        break;
      }
    }

    if (currentMealIndex != -1) {
      currentMeal = meals[currentMealIndex];
      if (currentMealIndex > 0) previousMeal = meals[currentMealIndex - 1];
      if (currentMealIndex + 1 < meals.length) nextMeal = meals[currentMealIndex + 1];
      if (currentMealIndex + 2 < meals.length) nextToNextMeal = meals[currentMealIndex + 2];
    } else {
      for (int i = 0; i < meals.length; i++) {
        if (now.isBefore(meals[i].dateTime)) {
          if (i > 0) previousMeal = meals[i - 1];
          nextMeal = meals[i];
          if (i + 1 < meals.length) nextToNextMeal = meals[i + 1];
          break;
        }
      }
    }

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

// ─── RsvpNotifier ─────────────────────────────────────────────────────────

class RsvpNotifier extends StateNotifier<RsvpState> {
  final String _mealKey;
  final Ref _ref;
  final String? _userId;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _attendanceSubscription;

  // Debounce: ignore taps while a Firebase write is in flight.
  bool _isUpdating = false;

  // SharedPreferences cache key: unique per user + meal so multiple accounts
  // on the same device don't bleed into each other.
  String get _cacheKey => 'rsvp_${_mealKey}_${_userId ?? 'guest'}';

  RsvpNotifier(this._mealKey, this._ref, this._userId)
  // Start with isLoading: false — we show the cached state immediately.
  // The live listener will silently correct it once Firebase responds.
      : super(RsvpState(isLoading: false)) {
    _initFromCache();
    _listenToAttendance();
  }

  // ── Step 1: paint the UI instantly from local cache ──────────────────────

  Future<void> _initFromCache() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && mounted) {
        state = state.copyWith(
          userSelection: _selectionFromString(cached),
        );
      }
    } catch (_) {
      // Cache read failures are silent — Firebase will fill in the truth.
    }
  }

  // ── Step 2: live Firebase listener — real-time attendee list + counts ────
  // Also derives the current user's selection directly from the snapshot
  // so we never need a separate one-shot fetch.

  void _listenToAttendance() {
    final parsed = _parseMealKey();
    final ref = _database
        .child('attendance')
        .child(parsed['date']!)
        .child(parsed['meal']!);

    _attendanceSubscription = ref.onValue.listen((event) {
      if (!mounted) return;

      if (event.snapshot.value == null) {
        state = state.copyWith(
          yesCount: 0,
          userSelection: RsvpOption.none,
          attendeesList: [],
        );
        _writeCache(RsvpOption.none);
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final attendees = <AttendeeInfo>[];
      int yesCount = 0;
      RsvpOption? mySelection;

      data.forEach((uid, userData) {
        final userMap = Map<String, dynamic>.from(userData as Map);
        final isAttending = userMap['isAttending'] as bool? ?? false;

        // Derive the current user's own selection straight from the live
        // snapshot — no extra round-trip needed.
        if (_userId != null && uid == _userId) {
          mySelection = isAttending ? RsvpOption.yes : RsvpOption.no;
          _writeCache(mySelection!);
        }

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
          // Only override userSelection from Firebase if we actually found
          // this user's record. If they have no record yet, keep whatever
          // the cache told us (avoids a flicker back to "none" on slow connections).
          userSelection: mySelection ?? state.userSelection,
        );
      }
    });
  }

  // ── Optimistic update with rollback ───────────────────────────────────────
  // UI updates immediately. Firebase write happens async in the background.
  // If the write fails we roll back to the previous state + cache.

  Future<void> updateAttendance(
      bool isAttending,
      String userId,
      String userName,
      String userEmail,
      ) async {
    if (_isUpdating) return; // Debounce: drop taps while write is in flight
    _isUpdating = true;

    final previousState = state;
    final newSelection = isAttending ? RsvpOption.yes : RsvpOption.no;

    // Optimistic: reflect the tap instantly
    if (mounted) {
      state = state.copyWith(userSelection: newSelection);
    }
    _writeCache(newSelection);

    try {
      final parsed = _parseMealKey();
      await _database
          .child('attendance')
          .child(parsed['date']!)
          .child(parsed['meal']!)
          .child(userId)
          .set({
        'isAttending': isAttending,
        'name': userName,
        'email': userEmail,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      // Rollback on failure — restore previous state and cache
      if (mounted) state = previousState;
      _writeCache(previousState.userSelection);
      // Rethrow so the UI layer can optionally show a snackbar
      rethrow;
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> removeAttendance(String userId) async {
    if (_isUpdating) return;
    _isUpdating = true;

    final previousState = state;

    // Optimistic
    if (mounted) {
      state = state.copyWith(userSelection: RsvpOption.none);
    }
    _writeCache(RsvpOption.none);

    try {
      final parsed = _parseMealKey();
      await _database
          .child('attendance')
          .child(parsed['date']!)
          .child(parsed['meal']!)
          .child(userId)
          .remove();
    } catch (e) {
      if (mounted) state = previousState;
      _writeCache(previousState.userSelection);
      rethrow;
    } finally {
      _isUpdating = false;
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  Future<void> _writeCache(RsvpOption selection) async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, _selectionToString(selection));
    } catch (_) {}
  }

  String _selectionToString(RsvpOption s) => switch (s) {
    RsvpOption.yes  => 'yes',
    RsvpOption.no   => 'no',
    RsvpOption.none => 'none',
  };

  RsvpOption _selectionFromString(String s) => switch (s) {
    'yes' => RsvpOption.yes,
    'no'  => RsvpOption.no,
    _     => RsvpOption.none,
  };

  // ── Misc helpers ──────────────────────────────────────────────────────────

  Map<String, String> _parseMealKey() {
    final parts = _mealKey.split('_');
    return {'date': parts[0], 'meal': parts[1]};
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────

String createMealKey(MealInfo mealInfo) {
  final dateStr = DateFormat('yyyy-MM-dd').format(mealInfo.dateTime);
  return '${dateStr}_${mealInfo.name}';
}

// ─── Dedicated live attendees stream ─────────────────────────────────────
//
// Bypasses the StateNotifier entirely — pipes Firebase onValue directly to
// whoever is watching. Used by the dialog so it always reflects the live DB
// state, independent of any optimistic update or caching logic in RsvpNotifier.

final attendeesStreamProvider = StreamProvider.autoDispose
    .family<List<AttendeeInfo>, String>((ref, mealKey) {
  final parts = mealKey.split('_');
  final date = parts[0];
  final meal = parts[1];

  final dbRef = FirebaseDatabase.instance
      .ref()
      .child('attendance')
      .child(date)
      .child(meal);

  return dbRef.onValue.map((event) {
    if (event.snapshot.value == null) return <AttendeeInfo>[];

    final data = Map<String, dynamic>.from(event.snapshot.value as Map);
    final attendees = <AttendeeInfo>[];

    data.forEach((uid, userData) {
      final userMap = Map<String, dynamic>.from(userData as Map);
      final isAttending = userMap['isAttending'] as bool? ?? false;
      if (isAttending) {
        attendees.add(AttendeeInfo(
          name: userMap['name'] as String? ?? 'Unknown',
          email: userMap['email'] as String? ?? '',
        ));
      }
    });

    // Sort alphabetically so the list order is stable as people join/leave
    attendees.sort((a, b) => a.name.compareTo(b.name));
    return attendees;
  });
});