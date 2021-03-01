import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/widgets/inv_key.dart';

class SplashPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      key: InvKey.SPLASH_PAGE,
      child: Center(
        child: Image.asset(
          'resources/icons/icon_small.png',
          width: 60.0, height: 60.0,
        ),
      ),
    );
  }
}
