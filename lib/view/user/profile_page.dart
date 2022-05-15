
import 'package:flutter/material.dart';
import 'package:flutterfire_ui/auth.dart';
import 'package:inventorio/firebase_options.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(avatarSize: 100, providerConfigs: [
      GoogleProviderConfiguration(clientId: DefaultFirebaseOptions.currentPlatform.appId),
      AppleProviderConfiguration(),
    ], actions: [
      SignedOutAction((context) {

      }),
    ],);
  }
}
