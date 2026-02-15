import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/meal_data.dart';

class MealRepository {
  Future<List<Menu>?> getMenu() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/menu.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Menu.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading menu: $e');
      return null;
    }
  }
}