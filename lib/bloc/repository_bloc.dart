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
import 'package:connectivity/connectivity.dart';
import 'package:inventorio/data/definitions.dart';

class RepositoryBloc {
  final _googleSignIn = GoogleSignIn();
  final _log = Logger('InventoryRepository');
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();

  static const DURATION_SHORT = Duration(milliseconds: 30);

  CollectionReference get _fireUsers => Firestore.instance.collection('users');
  CollectionReference get _fireInventory => Firestore.instance.collection('inventory');
  CollectionReference get _fireDictionary => Firestore.instance.collection('productDictionary');

  final _userUpdate = BehaviorSubject<UserAccount>();
  Observable<UserAccount> get userUpdateStream => _userUpdate.stream;
  Function(UserAccount) get userUpdateSink => _userUpdate.sink.add;

  Observable<UserAccount> get userLoginStream => _userUpdate.stream
    .where((userAccount) => userAccount.isSignedIn == true && _currentUser.email != userAccount.email);

  UserAccount _currentUser = UserAccount.userLoading();

  final _productSubject = BehaviorSubject<Product>();
  Observable<Product> get productStream => _productSubject.stream;

  final Map<String, Observable<Product>> _productObservables = Map();

  RepositoryBloc() {
    _googleSignIn.onCurrentUserChanged.listen((gAccount) => _accountFromSignIn(gAccount));
    userUpdateStream.listen((userAccount) => _currentUser = userAccount);
    Connectivity().checkConnectivity().then((connection) {
      if (connection == ConnectivityResult.none) {
        Connectivity().onConnectivityChanged.listen((connection) {
          if (connection != ConnectivityResult.none) signIn();
        });
      }
    });
  }

  Future<GoogleSignInAccount> signIn() async {
    var connection = await Connectivity().checkConnectivity();
    if (connection == ConnectivityResult.none) {
      _log.info('No internet connection');
      _loadFromPreferences();
      return null;
    }
    return _signInGoogle();
  }

  Future<GoogleSignInAccount> _signInGoogle() async {
    try {
      if (_googleSignIn.currentUser == null) await _googleSignIn.signInSilently(suppressErrors: true);
      if (_googleSignIn.currentUser == null) await _googleSignIn.signIn();
      _log.info('Signed in with ${_googleSignIn.currentUser.displayName}.');
    } catch (error) {
      _log.severe('Something wrong with sign-in: $error');
      userUpdateSink(UserAccount.userUnset());
    }

    return _googleSignIn.currentUser;
  }

  void signOut() {
    _log.info('Signing out from ${_googleSignIn.currentUser.displayName}.');
    _googleSignIn.signOut();
    _saveToPreferences(null);
  }

  void _accountFromSignIn(GoogleSignInAccount gAccount) async {
    if (gAccount != null) {
      _log.info('Google sign-in: ${gAccount.id.substring(0, 10)}...');
      _saveToPreferences(gAccount.id);
      _loadUserAccount(gAccount.id, gAccount.displayName, gAccount.photoUrl, gAccount.email);
      gAccount.authentication.then((auth) => _firebaseAuth(auth));

    } else {
      _log.info('No account signed in.');
      _saveToPreferences(null);
      userUpdateSink(UserAccount.userUnset());
    }
  }
  
  void _firebaseAuth(GoogleSignInAuthentication auth) {
    _log.info('Attempting Firebase authentication. ');
//    FirebaseAuth.instance.signInWithGoogle(idToken: auth.idToken, accessToken: auth.accessToken);
    AuthCredential credential = GoogleAuthProvider.getCredential(idToken: auth.idToken, accessToken: auth.accessToken);
    FirebaseAuth.instance.signInWithCredential(credential);
    _log.info('Authenticated Firebase.');
  }

  void _loadFromPreferences() {
    SharedPreferences.getInstance().then((pref) {
      String id = pref.getString('inventorio.userId');
      if (id != null) {
        _log.info('Loaded from last login: $id');
        _loadUserAccount(id, 'Cached Data', null, 'Not connected');
      }
    });
  }

  void _saveToPreferences(String id) {
    SharedPreferences.getInstance().then((pref) {
      pref.setString('inventorio.userId', id);
    });
  }

  void _loadUserAccount(String id, String displayName, String imageUrl, String email) {
    if (id == UserAccount.UNSET) {
      return;
    }

    _log.info('Listening for changes to $displayName');
    _fireUsers.document(id).snapshots().listen((doc) => _userLoad(doc, id, displayName, imageUrl, email));
  }

  void _userLoad(DocumentSnapshot doc, String id, String displayName, String imageUrl, String email) {
    var userAccount = UserAccount.userLoading();
    if (!doc.exists) {
      userAccount = _createNewUserAccount(id);
    } else {
      _log.info('Attempting to load user account for $displayName');
      userAccount = UserAccount.fromJson(doc.data)
        ..displayName = displayName
        ..email = email
        ..imageUrl = imageUrl
        ..isSignedIn = true;

      if (userAccount.currentInventoryId == '') {
        // Guard against blank current inventory
        userAccount.currentInventoryId = userAccount.knownInventories[0];
      }

    }
    userUpdateSink(userAccount);
  }

  UserAccount _createNewUserAccount(String userId) {
    if (userId == null) return UserAccount.userUnset();

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
      .debounce(DURATION_SHORT)
      .map((snaps) => _itemMapper(snaps, inventoryId));
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
    ).debounce(DURATION_SHORT);
  }

  Future<InventoryDetails> getInventoryDetailFuture(String inventoryId) async {
    var doc = await _fireInventory.document(inventoryId).get();
    var query = await _fireInventory.document(inventoryId).collection('inventoryItems').getDocuments();
    return _inventoryDetailZip(doc, query);
  }

  final Map<String, Product> _cachedProduct = Map();

  String _getCacheKey(String inventoryId, String code) => inventoryId + '_' + code;

  Product getCachedProduct(String inventoryId, String code) {
    String key = _getCacheKey(inventoryId, code);
    return _cachedProduct.containsKey(key) ? _cachedProduct[key] : Product(isLoading: true);
  }

  Product _updateCache(String cacheKey, Product product) {
    if (!_cachedProduct.containsKey(cacheKey) || _cachedProduct[cacheKey] != product) {
      _log.info('Updated cache for ${product.code} ${product.name}');
    }
    _cachedProduct[cacheKey] = product;
    _productSubject.sink.add(product);
    return product;
  }

  Product _combineProductDocumentSnap(DocumentSnapshot local, DocumentSnapshot master, String inventoryId, String code) {
    Product product = Product(code: code, isInitial: true);
    product = master.exists? Product.fromJson(master.data): product;
    product = local.exists? Product.fromJson(local.data): product;
    return product;
  }

  Observable<Product> getProductObservable(String inventoryId, String code) {
    return _productObservables.putIfAbsent(_getCacheKey(inventoryId, code), () {
      Observable.combineLatest2(
        _fireInventory.document(inventoryId).collection('productDictionary').document(code).snapshots(),
        _fireDictionary.document(code).snapshots(),
        (local, master) => _combineProductDocumentSnap(local, master, inventoryId, code),
      )
      .debounce(DURATION_SHORT)
      .listen((product) {
        _updateCache(_getCacheKey(inventoryId, code), product);
      });

      return _productSubject.where((product) => product.code == code);
    });
  }

  Future<Product> getProductFuture(String inventoryId, String code) async {
    Product cachedProduct = getCachedProduct(inventoryId, code);
    if (!cachedProduct.isLoading) return cachedProduct;

    var docs = await Future.wait([
      _fireInventory.document(inventoryId).collection('productDictionary').document(code).get(),
      _fireDictionary.document(code).get()
    ]);
    Product product = _combineProductDocumentSnap(docs[0], docs[1], inventoryId, code);
    _cachedProduct[_getCacheKey(inventoryId, code)] = product;
    return product;
  }

  void dispose() {
    _userUpdate.close();
    _productSubject.close();
  }

  UserAccount changeCurrentInventory(String uuid) {
    if (!_currentUser.isSignedIn) return _currentUser;
    _log.info('Changing current inventory to $uuid');
    _currentUser.currentInventoryId = uuid;
    return _updateFireUser(_currentUser);
  }

  UserAccount _updateFireUser(UserAccount userAccount) {
    _fireUsers.document(userAccount.userId).setData(userAccount.toJson());
    return userAccount;
  }

  UserAccount unsubscribeFromInventory(InventoryDetails detail) {
    if (!_currentUser.isSignedIn) return _currentUser;
    if (_currentUser.knownInventories.length == 1) return _currentUser;
    _currentUser.knownInventories.remove(detail.uuid);
    _currentUser.currentInventoryId = _currentUser.knownInventories[0];
    _log.info('Unsubscribing ${_currentUser.userId} from inventory ${detail.uuid}');
    return _updateFireUser(_currentUser);
  }

  UserAccount getCachedUser() { return _currentUser == null ? UserAccount.userLoading() : _currentUser; }

  void removeItem(InventoryItem item) {
    _log.info('Removing item: ${item.uuid}');
    _fireInventory.document(item.inventoryId).collection('inventoryItems').document(item.uuid).delete();
  }

  void updateItem(InventoryItem item) {
    _log.info('Adding item: ${item.uuid} expiring on ${item.expiryDate}');
    _fireInventory.document(item.inventoryId).collection('inventoryItems').document(item.uuid).setData(item.toJson());
  }

  void _uploadProduct(Product product) {
    if (!_currentUser.isSignedIn) return;
    _log.info('Trying to set product ${product.code} with ${product.toJson()}');
    String inventoryId = product.inventoryId ?? _currentUser.currentInventoryId;
    _updateCache(_getCacheKey(inventoryId, product.code), product);
    _fireInventory.document(inventoryId)
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
      inventoryId: _currentUser?.currentInventoryId ?? UserAccount.UNSET
    );
  }

  String setExpiryString(DateTime dateTime) {
    DateTime now = DateTime.now();
    var dateTimeString = dateTime
        .add(Duration(hours: now.hour, minutes: now.minute + 1, seconds: now.second))
        .toIso8601String();
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
    if (!_currentUser.isSignedIn || inventory.uuid == null) return;
    inventory.createdBy = _currentUser.userId;
    _fireInventory.document(inventory.uuid).setData(inventory.toJson()).whenComplete(() {
      _addInventory(inventory.uuid);
    });
  }

  void addInventory(String inventoryId) {
    if (!_currentUser.isSignedIn || inventoryId == null) return;
    _fireInventory.document(inventoryId).get().then((doc) {
      if (doc.exists) { _addInventory(inventoryId); }
    });
  }
}