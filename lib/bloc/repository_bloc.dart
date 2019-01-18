import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:logging/logging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventorio/data/definitions.dart';

class RepositoryBloc {
  final _googleSignIn = GoogleSignIn();
  final _log = Logger('InventoryRepository');
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();
  static const UNSET = '---';

  static final unsetUser = UserAccount(UNSET, UNSET)
    ..displayName = ''
    ..email = ''
    ..isSignedIn = false
  ;

  final _fireUsers = Firestore.instance.collection('users');
  final _fireInventory = Firestore.instance.collection('inventory');
  final _fireDictionary = Firestore.instance.collection('productDictionary');

  final _userUpdate = BehaviorSubject<UserAccount>();
  Observable<UserAccount> get userUpdateStream => _userUpdate.stream;
  Function(UserAccount) get userUpdateSink => _userUpdate.sink.add;

  UserAccount _currentUser;

  RepositoryBloc() {
    _googleSignIn.onCurrentUserChanged.listen((gAccount) => _accountFromSignIn(gAccount));
    userUpdateStream.listen((userAccount) => _currentUser = userAccount);
  }

  void signIn() async {
    try {
      if (_googleSignIn.currentUser == null) await _googleSignIn.signInSilently(suppressErrors: true);
      if (_googleSignIn.currentUser == null) await _googleSignIn.signIn();
      _log.info('Signed in with ${_googleSignIn.currentUser.displayName}.');
    } catch (error) {
      _log.severe('Something wrong with sign-in', error);
      _loadFromPreferences();
    }
  }

  void signOut() {
    _log.info('Signing out from ${_googleSignIn.currentUser.displayName}.');
    _googleSignIn.signOut();
  }

  void _accountFromSignIn(GoogleSignInAccount gAccount) async {
    if (gAccount != null) {
      gAccount.authentication.then((auth) {
        _log.info('Firebase sign-in with Google: ${gAccount.id}');
        FirebaseAuth.instance.signInWithGoogle(idToken: auth.idToken, accessToken: auth.accessToken);
      });
      _loadUserAccount(gAccount.id, gAccount.displayName, gAccount.photoUrl, gAccount.email);
    } else {
      _log.info('No account signed in.');
      userUpdateSink(unsetUser);
    }
  }

  void _loadFromPreferences() {
    SharedPreferences.getInstance().then((pref) {
      String id = pref.getString('inventorio.userId');
      _loadUserAccount(id, 'Cached Data', null, 'Not connected');
    });
  }

  void _loadUserAccount(String id, String displayName, String imageUrl, String email) {
    _fireUsers.document(id).snapshots().listen((doc) {
      if (!doc.exists) {
        _createNewUserAccount(id);
      } else {
        var userAccount = UserAccount.fromJson(doc.data)
          ..displayName = displayName
          ..email = email
          ..imageUrl = imageUrl
          ..isSignedIn = true;
        userUpdateSink(userAccount);
      }
    });
  }

  UserAccount _createNewUserAccount(String userId) {
    _log.info('Attempting to create user account for $userId');
    UserAccount userAccount = UserAccount(userId, generateUuid());

    _fireInventory.document(userAccount.currentInventoryId).setData(
      InventoryDetails(uuid: userAccount.currentInventoryId, name: 'Inventory', createdBy: userAccount.userId,).toJson()
    );

    _updateFireUser(userAccount);
    return userAccount;
  }

  List<InventoryItem> _itemMapper(QuerySnapshot snaps, String inventoryId) {
    return snaps.documents.map((doc) {
      var item = InventoryItem.fromJson(doc.data);
      if (item.inventoryId == null) item.inventoryId = inventoryId;
      return item;
    }).toList();
  }

  Observable<List<InventoryItem>> getItemListObservable(String inventoryId) {
    if (inventoryId == null) return Observable<List<InventoryItem>>.empty();
    return Observable(_fireInventory.document(inventoryId).collection('inventoryItems').snapshots())
      .map((snaps) => _itemMapper(snaps, inventoryId));
  }

  Future<List<InventoryItem>> getItemListFuture() async {
    String inventoryId = _currentUser?.currentInventoryId;
    if (inventoryId == null) return Future.value([]);
    var snaps = await _fireInventory.document(inventoryId).collection('inventoryItems').getDocuments();
    return _itemMapper(snaps, inventoryId);
  }

  InventoryDetails _inventoryDetailZip(DocumentSnapshot doc, QuerySnapshot query) {
    return InventoryDetails.fromJson(doc.data)
      ..isSelected = _currentUser.currentInventoryId == doc.reference.documentID
      ..currentCount = query.documents.length;
  }

  Observable<InventoryDetails> getInventoryDetailObservable(String inventoryId) {
    if (inventoryId == null) return Observable<InventoryDetails>.empty();
    return Observable.combineLatest2(
      _fireInventory.document(inventoryId).snapshots(),
      _fireInventory.document(inventoryId).collection('inventoryItems').snapshots(),
      _inventoryDetailZip
    );
  }

  Future<InventoryDetails> getInventoryDetailFuture(String inventoryId) async {
    var doc = await _fireInventory.document(inventoryId).get();
    var query = await _fireInventory.document(inventoryId).collection('inventoryItems').getDocuments();
    return _inventoryDetailZip(doc, query);
  }

  Product _combineProductDocumentSnap(DocumentSnapshot local, DocumentSnapshot master, String inventoryId) {
    Product product = Product(isInitial: true);
    product = master.exists? Product.fromJson(master.data): product;
    product = local.exists? Product.fromJson(local.data): product;
    return product;
  }

  final Map<String, Observable<Product>> _productObservables = Map();

  Observable<Product> getProductObservable(String inventoryId, String code) {
    return _productObservables.putIfAbsent('$inventoryId $code', () {
      return Observable.combineLatest2(
        _fireInventory.document(inventoryId).collection('productDictionary').document(code).snapshots(),
        _fireDictionary.document(code).snapshots(),
        (local, master) => _combineProductDocumentSnap(local, master, inventoryId),
      ).asBroadcastStream()
      .debounce(Duration(milliseconds: 100));
    });
  }

  Future<Product> getProductFuture(String inventoryId, String code) async {
    var docs = await Future.wait([
      _fireInventory.document(inventoryId).collection('productDictionary').document(code).get(),
      _fireDictionary.document(code).get()
    ]);
    return _combineProductDocumentSnap(docs[0], docs[1], inventoryId);
  }

  void dispose() {
    _userUpdate.close();
  }

  UserAccount changeCurrentInventory(InventoryDetails detail) {
    if (_currentUser == null) return _currentUser;
    _log.info('Changing current inventory to ${detail.uuid}');
    _currentUser.currentInventoryId = detail.uuid;
    return _updateFireUser(_currentUser);
  }

  UserAccount _updateFireUser(UserAccount userAccount) {
    _fireUsers.document(userAccount.userId).setData(userAccount.toJson());
    return userAccount;
  }

  UserAccount unsubscribeFromInventory(InventoryDetails detail) {
    if (_currentUser == null) return _currentUser;
    if (_currentUser.knownInventories.length == 1) return _currentUser;
    _currentUser.knownInventories.remove(detail.uuid);
    _currentUser.currentInventoryId = _currentUser.knownInventories[0];
    _log.info('Unsubscribing ${_currentUser.userId} from inventory ${detail.uuid}');
    return _updateFireUser(_currentUser);
  }

  UserAccount getCachedUser() { return _currentUser == null ? unsetUser : _currentUser; }

  void removeItem(InventoryItem item) {
    _log.info('Removing item: ${item.uuid}');
    _fireInventory.document(item.inventoryId).collection('inventoryItems').document(item.uuid).delete();
  }

  void updateItem(InventoryItem item) {
    _log.info('Adding item: ${item.uuid}');
    _fireInventory.document(item.inventoryId).collection('inventoryItems').document(item.uuid).setData(item.toJson());
  }

  void _uploadProduct(Product product) {
    if (_currentUser == null) return;
    _log.info('Trying to set product ${product.code} with ${product.toJson()}');
    _fireInventory.document(_currentUser.currentInventoryId)
      .collection('productDictionary')
      .document(product.code)
      .setData(product.toJson());
    _fireDictionary.document(product.code).setData(product.toJson());
  }

  Future<String> _uploadDataToStorage(Uint8List data, String folder, String fileName) async {
    StorageReference storage = FirebaseStorage.instance.ref().child(folder).child(fileName);
    StorageUploadTask uploadTask = storage.putData(data);
    await uploadTask.onComplete;
    String url = await storage.getDownloadURL();
    _log.info('Uploaded $fileName to url');
    return url;
  }

  Future<Product> _uploadProductImage(Product product, Uint8List imageDataToUpload) async {
    if (imageDataToUpload == null || imageDataToUpload.isEmpty) return product;

    String uuid = generateUuid();
    String fileName = '${product.code}_$uuid.jpg';
    product.imageUrl = await _uploadDataToStorage(imageDataToUpload, 'images', fileName);
    _log.info('Image URL: ${product.imageUrl}');

    return product;
  }

  Future<Uint8List> _resizeImage(File toResize) async {
    _log.info('Resizing image ${toResize.path}');
    Stopwatch stopwatch = Stopwatch()..start();

    int size = 512;
    ImageProperties properties = await FlutterNativeImage.getImageProperties(toResize.path);

    _log.info('Resizing image ${basename(toResize.path)}');
    File thumbnail = await FlutterNativeImage.compressImage(
      toResize.path,
      quality: 100,
      targetWidth: size,
      targetHeight: (properties.height * size / properties.width).round()
    );

    stopwatch.stop();
    _log.info('Took ${stopwatch.elapsedMilliseconds} ms to resize ${basename(toResize.path)}');
    Uint8List data = thumbnail.readAsBytesSync();
    thumbnail.delete();
    return data;
  }

  void updateProduct(Product product) {
    _uploadProduct(product);
    if (product.imageFile != null) {
      _resizeImage(product.imageFile).then((resized) {
        _uploadProductImage(product, resized).then((product) {
          _log.info('Reuploading with image URL data.');
          _uploadProduct(product);
        });
      });
    }
  }

  InventoryItem buildItem(String code) {
    return InventoryItem(
      uuid: generateUuid(),
      code: code,
      dateAdded: DateTime.now().toIso8601String(),
      inventoryId: _currentUser.currentInventoryId
    );
  }

  String setExpiryString(DateTime dateTime) {
    DateTime now = DateTime.now();
    var dateTimeString = dateTime.add(Duration(hours: now.hour, minutes: now.minute, seconds: now.second))
        .toIso8601String();
    _log.info('Setting expiry to $dateTimeString');
    return dateTimeString;
  }

  void _addInventory(String inventoryId) {
    if (!_currentUser.knownInventories.contains(inventoryId)) {
      _currentUser.knownInventories.add(inventoryId);
    }
    _currentUser.currentInventoryId = inventoryId;
    _updateFireUser(_currentUser);
  }

  void updateInventory(InventoryDetails inventory) {
    if (_currentUser == null || inventory.uuid == null) return;
    inventory.createdBy = _currentUser.userId;
    _fireInventory.document(inventory.uuid).setData(inventory.toJson()).whenComplete(() {
      _addInventory(inventory.uuid);
    });
  }

  void addInventory(String inventoryId) {
    if (_currentUser == null || inventoryId == null) return;
    _fireInventory.document(inventoryId).get().then((doc) {
      if (doc.exists) { _addInventory(inventoryId); }
    });
  }
}