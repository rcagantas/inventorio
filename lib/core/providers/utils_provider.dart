
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

@immutable
class Utilities {
  static const int RED = 7;
  static const int YELLOW = 30;

  DateTime toDate(String? isoDate) {
    final defaultDate = clock.now().add(Duration(days: 30));
    return DateTime.parse(isoDate ?? defaultDate.toIso8601String());
  }

  String toFormattedDate(String? isoDate) {
    return DateFormat.yMMMd(Platform.localeName).format(toDate(isoDate));
  }
  DateTime redAlarm(DateTime expiryDate) => expiryDate.subtract(Duration(days: RED));
  DateTime yellowAlarm(DateTime expiryDate) => expiryDate.subtract(Duration(days: YELLOW));
  bool withinBounds(DateTime date) => date.difference(clock.now()).inDays <= 0;
}

final utilsProvider = StateProvider<Utilities>((ref) => new Utilities());