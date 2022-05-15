
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/utils_provider.dart';

class ExpiryDot extends ConsumerWidget {
  static const double DOT_WIDTH = 10.0;
  final Item item;
  const ExpiryDot({Key? key, required this.item}) : super(key: key);

  Color getExpiryColor(Utilities utils) {
    Color expiryColor = Colors.green;
    expiryColor = utils.withinBounds(utils.yellowAlarm(utils.toDate(item.expiry))) ? Colors.yellow : expiryColor;
    expiryColor = utils.withinBounds(utils.redAlarm(utils.toDate(item.expiry))) ? Colors.red : expiryColor;
    return expiryColor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utils = ref.watch(utilsProvider);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: DOT_WIDTH,
        height: DOT_WIDTH,
        decoration: BoxDecoration(
          color: getExpiryColor(utils),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
