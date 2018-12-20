import 'dart:async';

import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/data/definitions.dart';

class RepositoryBloc {
  final _googleSignIn = Injector.getInjector().get<GoogleSignIn>();
  final _log = Logger('InventoryRepository');
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();
  static const UNSET = '---';

  final _fireUsers = Firestore.instance.collection('users');
  final _fireInventory = Firestore.instance.collection('inventory');
  final _fireDictionary = Firestore.instance.collection('productDictionary');
  final _userUpdate = BehaviorSubject<UserAccount>();

  Observable<UserAccount> get userUpdateStream => _userUpdate.stream;

  RepositoryBloc() {
    _googleSignIn.onCurrentUserChanged.listen((gAccount) => _accountFromSignIn(gAccount));
  }

  void signIn() async {
    if (_googleSignIn.currentUser == null) await _googleSignIn.signInSilently(suppressErrors: true);
    if (_googleSignIn.currentUser == null) await _googleSignIn.signIn();
    _log.info('Signed in with ${_googleSignIn.currentUser.displayName}');
  }

  void signOut() {
    _googleSignIn.signOut();
  }

  void _accountFromSignIn(GoogleSignInAccount gAccount) async {
    gAccount.authentication.then((auth) {
      _log.fine('Firebase sign-in with Google: ${gAccount.id}');
      FirebaseAuth.instance.signInWithGoogle(idToken: auth.idToken, accessToken: auth.accessToken);
    });

    _fireUsers.document(gAccount.id).snapshots().listen((doc) {
      if (!doc.exists) {
        _createNewUserAccount(gAccount.id);
      } else {
        var userAccount = UserAccount.fromJson(doc.data);
        _log.info('Change detected for user account ${userAccount.toJson()}');
        _userUpdate.sink.add(userAccount);
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
    var doc = await _fireUsers.document(_googleSignIn.currentUser?.id ?? UNSET).get();
    var user = UserAccount.fromJson(doc.data);
    user.currentInventoryId = detail.uuid;
    _updateFireUser(user);
  }

  void _updateFireUser(UserAccount userAccount) {
    _fireUsers.document(userAccount.userId).setData(userAccount.toJson());
  }
}