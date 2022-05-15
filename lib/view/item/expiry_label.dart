
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/utils_provider.dart';
import 'package:inventorio/view/item/expiry_dot.dart';

class ExpiryLabel extends ConsumerWidget {
  final Item item;
  const ExpiryLabel({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utils = ref.watch(utilsProvider);
    final formattedDate = DateFormat.yMMMd(Platform.localeName).format(utils.toDate(item.expiry));
    return Positioned(
      right: 3.0,
      bottom: 3.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('$formattedDate', style: Theme.of(context).textTheme.bodyMedium,),
          ExpiryDot(item: item),
        ],
      )
    );
  }
}
