import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/meta_provider.dart';

class InventoryName extends ConsumerWidget {
  final String inventoryId;
  const InventoryName({Key? key, required this.inventoryId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaSt = ref.watch(metaStreamProvider(this.inventoryId));
    return metaSt.when(
      data: (meta) => Text('${meta.name}'),
      error: (error, stack) => Container(),
      loading: () => Text('Inventorio')
    );
  }
}
