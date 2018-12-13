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

  static const UNSET = '---';
  GoogleSignInAccount _googleSignInAccount;
  UserAccount _userAccount = _defaultUserAccount();

  final _fireUsers = Firestore.instance.collection('users');
  final _fireInventory = Firestore.instance.collection('inventory');
  final _fireDictionary = Firestore.instance.collection('productDictionary');

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
        var userDoc = await _fireUsers.document(_googleSignInAccount.id ?? '0').get();
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

  Future<Product> getProduct(String inventoryId, String code) async {
    var snap = await _fireInventory.document(inventoryId).collection('productDictionary').document(code).get();
    if (snap.exists) return Product.fromJson(snap.data);
    var masterSnap = await _fireDictionary.document(code).get();
    if (snap.exists) return Product.fromJson(masterSnap.data);
    return Product();
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
}