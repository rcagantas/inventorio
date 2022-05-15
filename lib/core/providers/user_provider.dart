
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/app_user.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/items_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/scheduler_provider.dart';

class UserNotifier extends StateNotifier<AppUser> {
  final Ref ref;
  UserNotifier(AppUser state, this.ref) : super(state);

  void setLatest(AppUser user) {
    this.state = user;
  }
}

final userProvider = StateNotifierProvider<UserNotifier, AppUser>((ref) {
  return UserNotifier(
    AppUser(knownInventories: null, userId: null, currentInventoryId: null, currentVersion: null,),
    ref
  );
});

final userStreamProvider = StreamProvider<AppUser>((ref) async* {
  await ref.read(schedulerProvider).cancelNotifications();
  final auth = ref.watch(authProvider);
  if (auth == null) return;

  final authId = auth.uid;
  if (authId.isEmpty) return;

  final stream = ref.read(pluginsProvider).store
    .collection('users')
    .doc(authId)
    .snapshots();

  await for (final event in stream) {
    if (event.exists) {
      /// this is an existing user
      final appUser =  AppUser.fromJson(event.data() ?? new Map());
      if (appUser.knownInventories != null) {
        for (final inventoryId in appUser.knownInventories!) {
          ref.read(itemsStreamProvider(inventoryId));
        }
      }
      ref.read(userProvider.notifier).setLatest(appUser);
      yield appUser;
    } else {
      /// this is a new user
      ref.read(actionSinkProvider).createNewAppUser(authId);
    }
  }
});