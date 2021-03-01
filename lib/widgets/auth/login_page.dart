import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/providers/user_state.dart';
import 'package:inventorio/widgets/inv_key.dart';
import 'package:package_info/package_info.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserState>(
      builder: (context, UserState userState, _) {

        var mediaQuery = MediaQuery.of(context);
        bool darkMode = mediaQuery?.platformBrightness == Brightness.dark;

        return Scaffold(
          body: Center(
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Inventorio', style: Theme.of(context).textTheme.headline3,),
                  Image.asset('resources/icons/icon_transparent.png', width: 150.0, height: 150.0),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String version = snapshot.hasData
                          ? 'version ${snapshot.data.version} build ${snapshot.data.buildNumber}'
                          : '';
                      return Text('$version', textAlign: TextAlign.center,);
                    },
                  ),
                  Container(height: 50.0,),
                  FlatButton(
                    color: darkMode? Colors.white : Colors.blue,
                    textColor: darkMode? Colors.black: Theme.of(context).canvasColor,
                    key: InvKey.GOOGLE_SIGN_IN_BUTTON,
                    child: Row(
                      //mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(color: Colors.white),
                          child: Image.asset('resources/icons/google_logo.png', height: 25.0,)
                        ),
                        Text('Sign in with Google',
                          style: Theme.of(context).textTheme.bodyText1.copyWith(
                              fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                              fontWeight: FontWeight.w500,
                              fontSize: Theme.of(context).textTheme.bodyText1.fontSize + 2,
                              color: darkMode? Colors.black : Colors.white
                          ),
                        )
                      ],
                    ),
                    onPressed: () => userState.signInWithGoogle(),
                  ),
                  Container(height: 20.0,),
                  FutureBuilder(
                    future: userState.isAppleSignInAvailable(),
                    builder: (context, snapshot) {

                      return Visibility(
                        visible: snapshot.hasData && snapshot.data == true,
                        replacement: Container(),
                        child: SignInWithAppleButton(
                          style: darkMode
                            ? SignInWithAppleButtonStyle.white
                            : SignInWithAppleButtonStyle.black,
                          borderRadius: BorderRadius.all(Radius.circular(3.0)),
                          height: 40,
                          key: InvKey.APPLE_SIGN_IN_BUTTON,
                          onPressed: () => userState.signInWithApple(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
