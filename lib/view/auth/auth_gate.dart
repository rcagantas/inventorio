
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';
import 'package:inventorio/view/auth/login_page.dart';

import '../item/home.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({Key? key}) : super(key: key);

  Widget build(BuildContext context, WidgetRef ref) {
    final auth_ = ref.watch(authStreamProvider);
    ref.watch(userStreamProvider);
    return auth_.when(
      data: (auth) {
        return auth == null
          ? LoginPage()
          : Home(key: ObjectKey(auth), appUser: ref.watch(userProvider),);
      },
      error: (error, stack) => Container(),
      loading: () => const Center(child: const CircularProgressIndicator(),),
    );
  }
}
