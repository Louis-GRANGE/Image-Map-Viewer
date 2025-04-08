import 'dart:math';
import 'package:flutter/material.dart';

class Tools {
  // Add utility methods or properties here as needed
  /// Generates a random color
  static Color randomColor()
  {
    final random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }

  /// Example method to format a string
  static String formatString(String input) {
    return input.trim().toUpperCase();
  }
}