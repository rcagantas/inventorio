import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'data/definitions.dart';

class InventoryRepository {
  final _googleSignIn = Injector.getInjector().get<GoogleSignIn>();
  final _log = Logger('InventoryRepository');
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();

  static const UNSET = '---';
  GoogleSignInAccount _googleSignInAccount;
  UserAccount _userAccount = _defaultUserAccount();

  Future<UserAccount> getAccount() async {
    var currentSignedInAccount = _googleSignInAccount;

    _googleSignInAccount = _googleSignInAccount == null? await _googleSignIn.signInSilently(suppressErrors: true): _googleSignInAccount;
    _googleSignInAccount = _googleSignInAccount == null? await _googleSignIn.signIn() : _googleSignInAccount;

    if (currentSignedInAccount != _googleSignInAccount && _googleSignInAccount != null) {
      _log.info('Currently signed-in as ${_googleSignInAccount.displayName}');

      _googleSignInAccount.authentication.then((auth) {
        _log.fine('Firebase sign-in with Google: ${_googleSignInAccount.id}');
        FirebaseAuth.instance.signInWithGoogle(idToken: auth.idToken, accessToken: auth.accessToken);
      });

      return Future<UserAccount>(() async {
        var userDoc = await Firestore.instance.collection('users').document(_googleSignInAccount.id ?? '0').get();
        _userAccount = userDoc.exists
          ? UserAccount.fromJson(userDoc.data)
          : _createNewUserAccount(_googleSignInAccount.id);
        return _userAccount;
      });
    }

    return Future<UserAccount>.value(_userAccount);
  }

  static UserAccount _defaultUserAccount() {
    return UserAccount(UNSET, UNSET);
  }

  UserAccount _createNewUserAccount(String userId) {
    _log.fine('Attempting to create user account for $userId');
    UserAccount userAccount = UserAccount(userId, generateUuid());

    Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).setData(
        InventoryDetails(uuid: userAccount.currentInventoryId, name: 'Inventory', createdBy: userAccount.userId,).toJson()
    );

    Firestore.instance.collection('users').document(userId).setData(userAccount.toJson());
    return userAccount;
  }

  Stream<InventoryItem> getItems(String inventoryId) {
    return Firestore.instance.collection('inventory').document(inventoryId).snapshots().map((doc) => InventoryItem.fromJson(doc.data));
  }
}