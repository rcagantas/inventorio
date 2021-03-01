import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_status.dart';
import 'package:inventorio/services/inv_auth_service.dart';
import 'package:inventorio/utils/log/log_printer.dart';
import 'package:logger/logger.dart';

class UserState with ChangeNotifier {
  final logger = Logger(printer: SimpleLogPrinter('UserState'));

  InvAuthService _invAuthService;
  InvStatus _status = InvStatus.Uninitialized;
  InvAuth invAuth;

  InvStatus get status => _status;

  setStatus(InvStatus status) {
    _status = status;
    notifyListeners();
  }

  UserState() :
    _invAuthService = GetIt.instance<InvAuthService>()
  {
    setStatus(InvStatus.Uninitialized);
    _invAuthService.onAuthStateChanged.listen(_onAuthStateChanged);
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      setStatus(InvStatus.Authenticating);
      await _invAuthService.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      setStatus(InvStatus.Unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setStatus(InvStatus.Authenticating);
      await _invAuthService.signInWithGoogle();
    } catch (e) {
      setStatus(InvStatus.Unauthenticated);
    }
  }

  Future<void> signInWithApple() async {
    try {
      setStatus(InvStatus.Authenticating);
      await _invAuthService.signInWithApple();
    } catch (e) {
      setStatus(InvStatus.Unauthenticated);
    }
  }

  Future<void> signOut() async {
    setStatus(InvStatus.Authenticating);
    await _invAuthService.signOut();
    setStatus(InvStatus.Unauthenticated);
  }

  void _onAuthStateChanged(InvAuth invAuth) {
    if (invAuth == null) {
      setStatus(InvStatus.Unauthenticated);
    } else if (invAuth != this.invAuth){
      this.invAuth = invAuth;
      setStatus(InvStatus.Authenticated);
      logger.i('Signed-in with ${invAuth.email} $_status.');
    }
  }

  Future<bool> isAppleSignInAvailable() => _invAuthService.isAppleSignInAvailable();
}