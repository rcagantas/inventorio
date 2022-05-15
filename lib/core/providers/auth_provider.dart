
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';


class AuthNotifier extends StateNotifier<User?> {
  final Ref? ref;
  AuthNotifier(User? state, this.ref) : super(state);

  void setLatest(User? user) { this.state = user; }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) => AuthNotifier(null, ref));

final authStreamProvider = StreamProvider<User?>((ref) async* {
  final auth_ = ref.read(pluginsProvider).auth.authStateChanges();
  await for (final auth in auth_) {
    ref.read(authProvider.notifier).setLatest(auth);
    yield auth;
  }
});