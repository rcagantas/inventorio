import 'dart:async';

import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'data/definitions.dart';

class InventoryRepository {
  final _googleSignIn = Injector.getInjector().get<GoogleSignIn>();
  final _log = Logger('InventoryRepository');
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();
  static const DEBOUNCE = Duration(milliseconds: 100);
  static const UNSET = '---';

  final _fireUsers = Firestore.instance.collection('users');
  final _fireInventory = Firestore.instance.collection('inventory');
  final _fireDictionary = Firestore.instance.collection('productDictionary');
  Stream<UserAccount> _userAccountStream;

  InventoryRepository() {
    _userAccountStream = _googleSignIn.onCurrentUserChanged
        .where((g) => g != null)
        .asyncMap((g) async {
          g.authentication.then((auth) {
            _log.fine('Firebase sign-in with Google: ${g.id}');
            FirebaseAuth.instance.signInWithGoogle(idToken: auth.idToken, accessToken: auth.accessToken);
          });
          var userDoc = await _fireUsers.document(g.id).get();
          return userDoc.exists
              ? UserAccount.fromJson(userDoc.data)
              : _createNewUserAccount(g.id);
        });
  }

  void signIn() async {
    if (_googleSignIn.currentUser == null) await _googleSignIn.signInSilently(suppressErrors: true);
    if (_googleSignIn.currentUser == null) await _googleSignIn.signIn();
    _log.info('Signed in with ${_googleSignIn.currentUser.displayName}');
  }

  void signOut() {
    _googleSignIn.signOut();
  }

  Observable<UserAccount> getUserAccountObservable() {
    return Observable.combineLatest2(
      _userAccountStream,
      _fireUsers.document(_googleSignIn.currentUser?.id ?? UNSET).snapshots(),
      (UserAccount a, DocumentSnapshot b) {
        if (b.exists) {
          var u = UserAccount.fromJson(b.data);
          return u.userId != a.userId? a: u;
        }
        return a;
      }
    )
    .debounce(DEBOUNCE);
  }

  UserAccount _createNewUserAccount(String userId) {
    _log.fine('Attempting to create user account for $userId');
    UserAccount userAccount = UserAccount(userId, generateUuid());

    _fireInventory.document(userAccount.currentInventoryId).setData(
      InventoryDetails(uuid: userAccount.currentInventoryId, name: 'Inventory', createdBy: userAccount.userId,).toJson()
    );

    Firestore.instance.collection('users').document(userId).setData(userAccount.toJson());
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
    ).debounce(DEBOUNCE);
  }

  void dispose() {
  }
}