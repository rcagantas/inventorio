import 'dart:async';

import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/data/definitions.dart';

class UserAccountEx extends UserAccount {
  String displayName;
  String imageUrl;
  bool signedIn;
  UserAccountEx(UserAccount userAccount, this.displayName, this.imageUrl, this.signedIn)
      : super(userAccount.userId, userAccount.currentInventoryId) {
    super.knownInventories = userAccount.knownInventories;
  }
}

class RepositoryBloc {
  final _googleSignIn = Injector.getInjector().get<GoogleSignIn>();
  final _log = Logger('InventoryRepository');
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();
  static const UNSET = '---';

  static final unsetUser = UserAccountEx(UserAccount(UNSET, UNSET), null, null, false);

  final _fireUsers = Firestore.instance.collection('users');
  final _fireInventory = Firestore.instance.collection('inventory');
  final _fireDictionary = Firestore.instance.collection('productDictionary');
  final _userUpdate = BehaviorSubject<UserAccountEx>();

  Observable<UserAccountEx> get userUpdateStream => _userUpdate.stream;

  UserAccount _currentUser;

  RepositoryBloc() {
    _googleSignIn.onCurrentUserChanged.listen((gAccount) => _accountFromSignIn(gAccount));
  }

  void signIn() async {
    if (_googleSignIn.currentUser == null) await _googleSignIn.signInSilently(suppressErrors: true);
    if (_googleSignIn.currentUser == null) await _googleSignIn.signIn();
    _log.info('Signed in with ${_googleSignIn.currentUser.displayName}.');
  }

  void signOut() {
    _log.info('Signing out from ${_googleSignIn.currentUser.displayName}.');
    _googleSignIn.signOut();
  }

  void _accountFromSignIn(GoogleSignInAccount gAccount) async {
    if (gAccount != null) {
      gAccount.authentication.then((auth) {
        _log.fine('Firebase sign-in with Google: ${gAccount.id}');
        FirebaseAuth.instance.signInWithGoogle(idToken: auth.idToken, accessToken: auth.accessToken);
      });
      _loadUserAccount(gAccount.id, gAccount.displayName, gAccount.photoUrl);
    } else {
      _log.info('No account signed in.');
      _currentUser = null;
      _userUpdate.sink.add(unsetUser);
    }
  }

  void _loadUserAccount(String id, String displayName, String imageUrl) {
    _fireUsers.document(id).snapshots().listen((doc) {
      if (!doc.exists) {
        _createNewUserAccount(id);
      } else {
        var userAccount = UserAccount.fromJson(doc.data);
        _log.info('Change detected for user account ${userAccount.toJson()}');
        _currentUser = userAccount;
        _userUpdate.sink.add(UserAccountEx(userAccount, displayName, imageUrl, true));
      }
    });
  }

  UserAccount _createNewUserAccount(String userId) {
    _log.fine('Attempting to create user account for $userId');
    UserAccount userAccount = UserAccount(userId, generateUuid());

    _fireInventory.document(userAccount.currentInventoryId).setData(
      InventoryDetails(uuid: userAccount.currentInventoryId, name: 'Inventory', createdBy: userAccount.userId,).toJson()
    );

    _updateFireUser(userAccount);
    return userAccount;
  }

  Future<List<InventoryItem>> getItems(String inventoryId) async {
    var snap = await _fireInventory.document(inventoryId).collection('inventoryItems').getDocuments();
    return snap.documents
        .where((doc) => doc.exists)
        .map((doc) => InventoryItem.fromJson(doc.data))
        .toList();
  }

  Future<InventoryDetails> getInventoryDetails(String inventoryId) async {
    var snap = await _fireInventory.document(inventoryId).get();
    return snap.exists? InventoryDetails.fromJson(snap.data): null;
  }

  Observable<Product> getProductObservable(String inventoryId, String code) {
    return Observable.combineLatest2(
      _fireInventory.document(inventoryId).collection('productDictionary').document(code).snapshots(),
      _fireDictionary.document(code).snapshots(),
      (DocumentSnapshot a, DocumentSnapshot b) {
        if (a.exists) return Product.fromJson(a.data);
        if (b.exists) return Product.fromJson(b.data);
        return Product();
      }
    );
  }

  void dispose() {
    _userUpdate.close();
  }

  Future changeCurrentInventoryFromDetail(InventoryDetails detail) async {
    if (_currentUser == null) return;
    _currentUser.currentInventoryId = detail.uuid;
    _updateFireUser(_currentUser);
  }

  void _updateFireUser(UserAccount userAccount) {
    _fireUsers.document(userAccount.userId).setData(userAccount.toJson());
  }

  void unsubscribeFromInventory(InventoryDetails inventoryDetails) {
    if (_currentUser == null) return;
    if (_currentUser.knownInventories.length == 1) return;
    _currentUser.knownInventories.remove(inventoryDetails.uuid);
    _currentUser.currentInventoryId = _currentUser.knownInventories[0];
    _fireUsers.document(_currentUser.userId).setData(_currentUser.toJson());
    _log.fine('Unsubscribing ${_currentUser.userId} from inventory ${inventoryDetails.uuid}');
  }
}