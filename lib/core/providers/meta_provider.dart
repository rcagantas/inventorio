
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/meta.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';

final metaStreamProvider = StreamProvider.family<Meta, String>((ref, inventoryId) async* {
  final store = ref.read(pluginsProvider).store;
  final auth = ref.watch(authProvider);
  if (auth == null) return;

  final stream = store
    .collection('inventory')
    .doc(inventoryId)
    .snapshots();

  await for (final element in stream) {
    if (element.exists && element.data() != null) {
      yield Meta.fromJson(element.data()!);
    }
  }
});