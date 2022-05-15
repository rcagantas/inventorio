
import 'package:flutter/material.dart';
import 'package:flutterfire_ui/auth.dart';
import 'package:inventorio/firebase_options.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SignInScreen(
      subtitleBuilder: (context, action) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Welcome to Inventorio'),
        );
      },
      footerBuilder: (context, action) {
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Text(
            'By signing in, you agree to our terms and conditions.',
            style: TextStyle(color: Colors.grey),
          ),
        );
      },
      headerBuilder: (context, constraints, _) => AspectRatio(aspectRatio: 1, child: Image.asset('resources/icons/icon_transparent.png'),),
      sideBuilder: (context, constraints) => AspectRatio(aspectRatio: 1, child: Image.asset('resources/icons/icon_transparent.png'),),
      providerConfigs: [
        GoogleProviderConfiguration(clientId: DefaultFirebaseOptions.currentPlatform.appId),
        AppleProviderConfiguration(),
      ]
    );
  }
}
