class Menu {
  final String day;
  final Meal breakfast;
  final Meal lunch;
  final Meal dinner;

  Menu({
    required this.day,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      day: json['day'] as String,
      breakfast: Meal.fromJson(json['breakfast'] as Map<String, dynamic>),
      lunch: Meal.fromJson(json['lunch'] as Map<String, dynamic>),
      dinner: Meal.fromJson(json['dinner'] as Map<String, dynamic>),
    );
  }
}

class Meal {
  final String start;
  final String end;
  final List<String> items;

  Meal({
    required this.start,
    required this.end,
    required this.items,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      start: json['start'] as String,
      end: json['end'] as String,
      items: (json['items'] as List).map((e) => e.toString()).toList(),
    );
  }
}

class MealInfo {
  final String name;
  final String start;
  final String end;
  final List<String> items;
  final DateTime dateTime;

  MealInfo({
    required this.name,
    required this.start,
    required this.end,
    required this.items,
    required this.dateTime,
  });
}

class MealScheduleState {
  final MealInfo? currentMeal;
  final MealInfo? nextMeal;
  final MealInfo? nextToNextMeal;
  final MealInfo? previousMeal;

  MealScheduleState({
    this.currentMeal,
    this.nextMeal,
    this.nextToNextMeal,
    this.previousMeal,
  });

  MealScheduleState copyWith({
    MealInfo? currentMeal,
    MealInfo? nextMeal,
    MealInfo? nextToNextMeal,
    MealInfo? previousMeal,
  }) {
    return MealScheduleState(
      currentMeal: currentMeal ?? this.currentMeal,
      nextMeal: nextMeal ?? this.nextMeal,
      nextToNextMeal: nextToNextMeal ?? this.nextToNextMeal,
      previousMeal: previousMeal ?? this.previousMeal,
    );
  }
}

class AttendeeInfo {
  final String name;
  final String email;

  AttendeeInfo({
    required this.name,
    required this.email,
  });
}

enum RsvpOption { none, yes, no }

class RsvpState {
  final int yesCount;
  final RsvpOption userSelection;
  final List<AttendeeInfo> attendeesList;
  final bool isLoading;

  RsvpState({
    this.yesCount = 0,
    this.userSelection = RsvpOption.none,
    this.attendeesList = const [],
    this.isLoading = true,
  });

  RsvpState copyWith({
    int? yesCount,
    RsvpOption? userSelection,
    List<AttendeeInfo>? attendeesList,
    bool? isLoading,
  }) {
    return RsvpState(
      yesCount: yesCount ?? this.yesCount,
      userSelection: userSelection ?? this.userSelection,
      attendeesList: attendeesList ?? this.attendeesList,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}