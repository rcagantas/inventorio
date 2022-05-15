import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/sort_provider.dart';

class SortIcon extends ConsumerWidget {
  static const Map<Sort, Icon> iconMap = {
    Sort.EXPIRY: Icon(Icons.sort),
    Sort.DATE_ADDED: Icon(Icons.calendar_today),
    Sort.PRODUCT: Icon(Icons.sort_by_alpha),
  };

  const SortIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortState = ref.watch(sortProvider);
    final Icon sortIcon = iconMap[sortState] ?? Icon(Icons.sort);
    return IconButton(onPressed: () => ref.read(sortProvider.notifier).toggle(), icon: sortIcon,);
  }
}
