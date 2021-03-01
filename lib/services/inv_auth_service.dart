import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/utils/log/log_printer.dart';
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class InvAuthFailure implements Exception {
  String message;
  InvAuthFailure(this.message);
}

class InvAuthService {
  final logger = Logger(printer: SimpleLogPrinter('InvAuthService'));

  FirebaseAuth _auth;
  GoogleSignIn _googleSignIn;

  Stream<InvAuth> get onAuthStateChanged => _auth.authStateChanges().map((user) {
    return user == null ? null : InvAuth(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      googleSignInId: _googleSignIn.currentUser?.id
    );
  });

  InvAuthService({
    FirebaseAuth auth,
    GoogleSignIn googleSignIn
  }) {
    this._auth = auth;
    this._googleSignIn = googleSignIn;
  }

  Future<void> signInWithEmailAndPassword({
    @required String email,
    @required String password
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    logger.i('Attempting to silently sign-in with Google...');
    GoogleSignInAccount googleAccount = await _googleSignIn.signInSilently(suppressErrors: true);
    if (googleAccount == null) {
      logger.i('Attempting to sign-in with Google...');
      googleAccount = await _googleSignIn.signIn();
    }

    if (googleAccount == null) {
      throw InvAuthFailure('Failed to sign-in with Google');
    }

    GoogleSignInAuthentication googleCredential = await googleAccount.authentication;
    AuthCredential authCredential = GoogleAuthProvider.credential(
        idToken: googleCredential.idToken,
        accessToken: googleCredential.accessToken
    );

    await _auth.signInWithCredential(authCredential);
  }

  Future<void> signInWithApple() async {
    logger.i('Attempting to sign-in with Apple...');
    var credential = await SignInWithApple.getAppleIDCredential(scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ]);

    if (credential == null) {
      throw InvAuthFailure('Failed to sign-in with Apple');
    }

    OAuthProvider oAuthProvider = new OAuthProvider('apple.com');
    AuthCredential authCredential = oAuthProvider.credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );

    await _auth.signInWithCredential(authCredential);
  }

  Future<void> signOut() async {
    logger.i('Signing out...');

    await _auth.signOut();

    if (_googleSignIn.currentUser != null) {
      await _googleSignIn.signOut();
    }

    logger.i('Signed out.');
  }

  Future<bool> isAppleSignInAvailable() => SignInWithApple.isAvailable();
}