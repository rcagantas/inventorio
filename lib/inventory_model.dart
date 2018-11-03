import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inventorio/definitions.dart';
import 'package:path/path.dart';
import 'package:quiver/core.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_native_image/flutter_native_image.dart';

class InventoryModel extends Model {
  final Logger log = Logger('InventoryModel');
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final Uuid _uuid = Uuid();
  static String generateUuid() => _uuid.v4();

  bool get isSignedIn => _googleSignIn.currentUser != null;
  String get userDisplayName => _googleSignIn.currentUser?.displayName ?? '';
  void signIn() { _googleSignIn.signIn(); }
  void signOut() {
    _googleSignIn.signOut().whenComplete(() {
      inventories.clear();
      SharedPreferences.getInstance()
          .then((save) => save.remove('inventorio.userId'));
      notifyListeners();
    });
  }

  UserAccount userAccount;

  CollectionReference get userCollection =>
      Firestore.instance.collection('users');

  CollectionReference get masterProductDictionary =>
      Firestore.instance.collection('productDictionary');

  CollectionReference get inventoryCollection =>
      Firestore.instance.collection('inventory');

  CollectionReference get inventoryItemCollection =>
      userAccount == null ? null : Firestore.instance.collection('inventory')
          .document(userAccount.currentInventoryId)
          .collection('inventoryItems');

  Map<String, InventorySet> inventories = {};

  InventorySet get selected =>
      inventories[userAccount?.currentInventoryId];

  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  NotificationDetails _notificationDetails;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localMasterDictionaryFile async {
    final path = await _localPath;
    return File('$path/master.json');
  }

  InventoryModel() {
    _initLogging();
    _loadMasterDictionary();
    _setupNotifications();
    _ensureLogin();
  }

  void _setupNotifications() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin()
      ..initialize(
        InitializationSettings(
            AndroidInitializationSettings('icon'),
            IOSInitializationSettings()
        ),
        selectNotification: (inventoryId) { changeCurrentInventory(inventoryId); },
      );

    _notificationDetails = NotificationDetails(
        AndroidNotificationDetails(
            'com.rcagantas.inventorio.scheduled.notifications',
            'Inventorio Expiration Notification',
            'Notification 7 and 30 days before expiry'
        ),
        IOSNotificationDetails()
    );
  }

  void _ensureLogin() async {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      log.fine('Account changed.');
      if (account != null) {
        _doLogin(account);
      }
    });

    try {
      GoogleSignInAccount user = _googleSignIn.currentUser;
      user = user == null ? await _googleSignIn.signInSilently(suppressErrors: true) : user;
      user = user == null ? await _googleSignIn.signIn() : user;
    } catch (error) {
      log.severe('Something wrong with login', error);
      _loadFromPreferences().then((accountId) {
        _loadUserAccount(accountId);
      });
    }
  }

  void _doLogin(GoogleSignInAccount account) {
    log.fine('Google sign-in account id: ${account.id}');

    account.authentication.then((auth) {
      log.fine('Firebase sign-in with Google: ${account.id}');
      FirebaseAuth.instance.signInWithGoogle(
          idToken: auth.idToken, accessToken: auth.accessToken);
    });

    SharedPreferences.getInstance()
        .then((save) => save.setString('inventorio.userId', account.id));

    _loadUserAccount(account.id);
  }

  void _loadUserAccount(String accountId) {
    if (accountId == null || accountId == "") return;

    _flutterLocalNotificationsPlugin.cancelAll();

    userCollection.document(accountId).snapshots().listen((userDoc) {
      if (!userDoc.exists) {
        _createNewUserAccount(accountId);
        return;
      }


      userAccount = UserAccount.fromJson(userDoc.data);
      log.fine('Loaded account changes ${userDoc.data}');

      if (userDoc.documentID != userAccount?.userId
        || inventories.length != userAccount.knownInventories.length
      ) {
        inventories.clear();
        _delayedActions();
      }

      userAccount.knownInventories.forEach((inventoryId) {
        log.fine('Loading inventory $inventoryId');

        inventoryCollection.document(inventoryId).snapshots().listen((doc) {
          if (!doc.exists) return;

          InventoryDetails details = InventoryDetails.fromJson(doc.data);

          inventories.putIfAbsent(inventoryId, () {
            InventorySet inventory = InventorySet(details);

            doc.reference.collection('inventoryItems').snapshots().listen((snap) {
              inventory.itemClear();

              snap.documents.forEach((doc) {

                InventoryItem item = InventoryItem.fromJson(doc.data);
                inventory.addItem(item);

                identifyProduct(item.code, inventoryId: inventoryId).then((product) {
                  _scheduleIfNeeded(inventoryId, item, product);
                  _delayedActions();
                });

              });

            });
            return inventory;
          });
        });

      });

      notifyListeners();
    });
  }

  void _createNewUserAccount(String userId) {
    log.fine('Attempting to create user account for $userId');
    UserAccount userAccount = UserAccount(userId, generateUuid());

    Firestore.instance
        .collection('inventory')
        .document(userAccount.currentInventoryId)
        .setData(InventoryDetails(
          uuid: userAccount.currentInventoryId,
          name: 'Inventory',
          createdBy: userAccount.userId,
        ).toJson());

    userCollection.document(userId).setData(userAccount.toJson());
  }

  Future<String> _loadFromPreferences() async {
    log.fine('Loading last known user from shared preferences.');
    SharedPreferences save = await SharedPreferences.getInstance();
    String userId = save.getString('inventorio.userId');
    return userId;
  }

  bool inventoryChange = false;
  void changeCurrentInventory(String code) {
    if (userAccount == null || code == null) return;
    log.fine('Changing current inventory to: $code');
    inventoryChange = true;
    userAccount.currentInventoryId = code;
    userCollection.document(userAccount.userId).setData(userAccount.toJson());
  }

  void setFilter(String query) {
    selected.filter = query;
    notifyListeners();
  }

  void toggleSort() {
    selected.sortAlpha = !selected.sortAlpha;
    notifyListeners();
  }

  Product insertUpdateProduct(String code,
      String brand, String name,
      String variant, String imageUrl, File file) {
    Product product = Product(code: code, brand: brand, name: name, variant: variant, imageUrl: imageUrl);
    _uploadProduct(product);

    if (file != null) _resizeImage(file).then((resized) {
      selected.replacedImage[product.code] = resized;
      notifyListeners();

      _uploadProductImage(product, resized).then((product) {
        log.fine('Reuploading with image URL data.');
        _uploadProduct(product);
        identifyProduct(product.code);
        Future.delayed(Duration(minutes: 2), () {
          selected.replacedImage.remove(product.code);
        });
      });
    });

    return product;
  }

  Future<Uint8List> _resizeImage(File toResize) async {
    log.fine('Resizing image ${toResize.path}');
    DateTime startTime = DateTime.now();

    int size = 512;
    ImageProperties properties = await FlutterNativeImage.getImageProperties(toResize.path);

    log.fine('Resizing image ${basename(toResize.path)}');
    File thumbnail = await FlutterNativeImage.compressImage(toResize.path, quality: 100,
        targetWidth: size,
        targetHeight: (properties.height * size / properties.width).round()
    );

    log.fine('Took ${DateTime.now().difference(startTime).inMilliseconds} ms to resize ${basename(toResize.path)}');
    Uint8List data = thumbnail.readAsBytesSync();
    thumbnail.delete();
    return data;
  }

  void _uploadProduct(Product product) {
    log.fine('Trying to set product ${product.code} with ${product.toJson()}');
    var localizedDictionary = Firestore.instance.collection('inventory')
        .document(userAccount.currentInventoryId)
        .collection('productDictionary');

    localizedDictionary.document(product.code).setData(product.toJson());
    masterProductDictionary.document(product.code).setData(product.toJson());
  }

  Future<Product> _uploadProductImage(Product product, Uint8List imageDataToUpload) async {
    if (imageDataToUpload == null || imageDataToUpload.isEmpty) return product;

    String uuid = generateUuid();
    String fileName = '${product.code}_$uuid.jpg';
    product.imageUrl = await _uploadDataToStorage(imageDataToUpload, 'images', fileName);

    return product;
  }

  Future<String> _uploadDataToStorage(Uint8List data, String folder, String fileName) async {
    StorageReference storage = FirebaseStorage.instance.ref().child(folder).child(fileName);
    StorageUploadTask uploadTask = storage.putData(data);
    UploadTaskSnapshot uploadSnap = await uploadTask.future;
    String url = uploadSnap.downloadUrl.toString();
    log.fine('Uploaded $fileName to url');
    return url;
  }

  void _subscribeToProduct(CollectionReference ref, Map<String, Product> map, String code, {String logMessage}) {
    ref.document(code).snapshots().listen((doc) {
      if (doc.exists) {
        if (logMessage != null) log.fine(logMessage);
        map[code] = Product.fromJson(doc.data);
        notifyListeners();
      }
    });
  }

  Future<Product> identifyProduct(String code, {String inventoryId}) async {
    inventoryId = inventoryId == null ? userAccount?.currentInventoryId : inventoryId;
    if (inventoryId == null) return null;

    Product product;
    product = product == null? inventories[inventoryId].productDictionary[code]: product;
    product = product == null? InventorySet.masterProductDictionary[code]: product;
    if (product != null) return product;

    var doc;
    if (inventoryId != null) {
      var localizedDictionary = Firestore.instance.collection('inventory')
          .document(inventoryId)
          .collection('productDictionary');

      doc = await localizedDictionary.document(code).get();
      if (doc.exists) {
        inventories[inventoryId].productDictionary.putIfAbsent(code, () {
          _subscribeToProduct(localizedDictionary, inventories[inventoryId].productDictionary, code,
              logMessage: "Localized data for $code in $inventoryId");
          return Product.fromJson(doc.data);
        });
      }
    }

    if (!InventorySet.masterProductDictionary.containsKey(code)) {
      var masterDoc = await masterProductDictionary.document(code).get();
      if (masterDoc.exists) {
        InventorySet.masterProductDictionary.putIfAbsent(code, () {
          _subscribeToProduct(masterProductDictionary, InventorySet.masterProductDictionary, code,
              logMessage: "Master data for $code");
          return Product.fromJson(masterDoc.data);
        });
      }
    }

    return inventories[inventoryId].getAssociatedProduct(code);
  }

  Future<Product> identifyProduct1(String code, {String inventoryId}) async {
    inventoryId = inventoryId == null ? userAccount?.currentInventoryId : inventoryId;
    if (inventoryId == null) return null;

    if (inventories[inventoryId].getAssociatedProduct(code) != null) {
      print('Cached data   $code');
      return inventories[inventoryId].getAssociatedProduct(code);
    }

    var localizedDictionary = Firestore.instance.collection('inventory')
        .document(inventoryId)
        .collection('productDictionary');

    var doc = await localizedDictionary.document(code).get();
    if (doc.exists) {
      log.fine('Specific data $code');
      inventories[inventoryId].productDictionary.putIfAbsent(code, () {
        localizedDictionary.document(code).snapshots().listen((doc) {
          inventories[inventoryId].productDictionary[code] = Product.fromJson(doc.data);
          notifyListeners();
        });
        return Product.fromJson(doc.data);
      });
    }

    var masterDoc = await masterProductDictionary.document(code).get();
    if (masterDoc.exists) {
      if (!doc.exists) log.fine('Master data $code');
      InventorySet.masterProductDictionary.putIfAbsent(code, () {
        masterProductDictionary.document(code).snapshots().listen((doc) {
          InventorySet.masterProductDictionary[code] = Product.fromJson(doc.data);
          notifyListeners();
        });
        return Product.fromJson(masterDoc.data);
      });
    }

    return inventories[inventoryId].getAssociatedProduct(code);
  }

  InventoryItem buildInventoryItem(String code, DateTime expiryDate, {String uuid}) {
    uuid = uuid == null? generateUuid(): uuid;
    return InventoryItem(uuid: uuid, code: code,
        expiry: expiryDate.toIso8601String().substring(0, 10),
        dateAdded: DateTime.now().toIso8601String()
    );
  }

  void addItem(InventoryItem item) {
    log.fine('Trying to add item ${item.toJson()}');
    inventoryItemCollection.document(item.uuid).setData(item.toJson());
  }

  void removeItem(InventoryItem item) {
    log.fine('Trying to delete item ${item.toJson()}');
    inventoryItemCollection.document(item.uuid).delete();
  }

  void addAsNewItem(InventoryItem item) {
    item.uuid = generateUuid();
    addItem(item);
  }

  Future addInventory(InventoryDetails inventory, {bool createNew}) async {
    if (userAccount == null || inventory == null) return;

    log.fine('Updating inventory: ${inventory.toJson()}');
    var doc = await Firestore.instance.collection('inventory').document(inventory.uuid).get();
    if (createNew) {
      if (!doc.exists) inventory.createdBy = userAccount.userId;
      else {
        var error = Exception("Failed to create Inventory. ID already exists");
        log.fine("Inventory exists but is supposed to be new. UUID collision", error);
        throw error;
      }
    }

    if (!userAccount.knownInventories.contains(inventory.uuid)) {
      userAccount.knownInventories.add(inventory.uuid);
    }

    userAccount.currentInventoryId = inventory.uuid;
    userCollection.document(userAccount.userId).setData(userAccount.toJson());

    inventory.createdBy = userAccount.userId;
    inventoryCollection.document(inventory.uuid).setData(inventory.toJson());
    log.fine('Setting inventory: ${inventory.uuid}');
  }

  Future<bool> scanInventory(String code) async {
    log.fine('Validating inventory code $code...');
    if (userAccount == null) return false;
    if (code.contains('/')) return false;

    DocumentSnapshot scanned = await Firestore.instance.collection('inventory').document(code).get();
    if (!scanned.exists) return false;

    if (!userAccount.knownInventories.contains(code)) userAccount.knownInventories.add(code);

    log.fine('Scanned inventory code $code');
    userCollection.document(userAccount.userId).setData(userAccount.toJson());
    return true;
  }

  void unsubscribeInventory(String code) {
    if (userAccount == null || code == null) return;
    if (userAccount.knownInventories.length == 1) return;
    userAccount.knownInventories.remove(code);
    userAccount.currentInventoryId = userAccount.knownInventories[0];
    userCollection.document(userAccount.userId).setData(userAccount.toJson());
    inventories.remove(code);
    log.fine('Unsubscribing ${userAccount.userId} from inventory $code');
  }

  List<String> _logMessages = List();
  List<String> get logMessages => _logMessages;

  void _initLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      var logMessage = '${rec.time}: ${rec.message}';
      print(logMessage);
      logMessage = userAccount == null
          ? logMessage
          : logMessage.replaceAll(userAccount.userId, '[-]');
      _logMessages.insert(0, logMessage);
      if (_logMessages.length > 1000)
        _logMessages.removeRange(1000, _logMessages.length);
      notifyListeners();
    });
    log.fine('Creating InventoryModel');
  }

  DateTime _expiryPatch(InventoryItem item, DateTime expiry) {
    DateTime added = item.dateAdded != null
        ? DateTime.parse(item.dateAdded.substring(0, 19).replaceAll('-', '').replaceAll(':', ''))
        : DateTime.now();
    expiry = expiry.add(Duration(hours: added.hour, minutes: added.minute + 1));
    return expiry;
  }

  int _hashNotification(String uuid, DateTime expiry) {
    return hash('$uuid/${expiry.toIso8601String()}');
  }

  void _scheduleIfNeeded(String inventoryId, InventoryItem item, Product product) {
    if (item.expiryDate.compareTo(DateTime.now()) > 0) {
      int weekNotificationId = _hashNotification(item.uuid, item.weekNotification);
      String weekMessage = 'is about to expire within 7 days on ${item.year} ${item.month} ${item.day}';
      _scheduleNotification(weekNotificationId, inventoryId, product, weekMessage, _expiryPatch(item, item.weekNotification));

      int monthNotificationId = _hashNotification(item.uuid, item.monthNotification);
      String monthMessage = 'is about to expire within 30 days on ${item.year} ${item.month} ${item.day}';
      _scheduleNotification(monthNotificationId, inventoryId, product, monthMessage, _expiryPatch(item, item.monthNotification));
    }
  }

  Map<int, String> _scheduledNotifications = {};
  void _scheduleNotification(
      int notificationId,
      String inventoryId,
      Product product,
      String message,
      DateTime notificationDate) {
    String productName = product.name;
    String productVariant = product.variant;

    if (_scheduledNotifications.containsKey(notificationId)) {
      return;
    }

    _flutterLocalNotificationsPlugin.schedule(
        notificationId,
        '$productName $productVariant',
        '$message',
        notificationDate,
        _notificationDetails,
        payload: inventoryId
    );

    _scheduledNotifications[notificationId] = '$productName $productVariant on $notificationDate';
    log.info('Alerting $productName $productVariant on $notificationDate');
  }

  void _saveMasterDictionary() {
    _localMasterDictionaryFile.then((f) {
      log.info('Saving master dictionary in ${f.path}');
      f.writeAsString(json.encode(InventorySet.masterProductDictionary));
    });
  }

  void _loadMasterDictionary() {
    _localMasterDictionaryFile.then((f) {
      f.exists().then((exists) {
        if (exists) {
          f.readAsString().then((j) {
            log.info('Loading master dictionary from ${f.path}');
            Map<String, dynamic> temp = json.decode(j);
            InventorySet.masterProductCache = temp.map((k, v) => MapEntry(k, Product.fromJson(v)));
            log.info('Master dictionary cache populated with ${InventorySet.masterProductCache?.length} items');
            notifyListeners();
          });
        }
      });
    });
  }

  void _cleanupNotificationsOfDeletedItems() {
    List<InventoryItem> allItems = inventories.values.expand((inventorySet) => inventorySet.items).toList();
    List<int> hashes = [];
    hashes.addAll(allItems.map((item) => _hashNotification(item.uuid, item.weekNotification)));
    hashes.addAll(allItems.map((item) => _hashNotification(item.uuid, item.monthNotification)));

    log.info('Scheduled items before cleanup: ${_scheduledNotifications.length/2}');

    _scheduledNotifications.removeWhere((hash, value) {
      if (!hashes.contains(hash)) {
        log.info('Cancelling alert ${_scheduledNotifications[hash]}');
        _flutterLocalNotificationsPlugin.cancel(hash);
      }
      return !hashes.contains(hash);
    });

    log.info('Scheduled items after cleanup: ${_scheduledNotifications.length/2}');
  }

  Timer _schedulingTimer;
  void _delayedActions({Duration duration = const Duration(seconds: 2)}) {
    if (inventoryChange) { inventoryChange = false; return; }

    if (_schedulingTimer != null) _schedulingTimer.cancel();
    _schedulingTimer = Timer(duration, () {
      _cleanupNotificationsOfDeletedItems();
      _saveMasterDictionary();
    });
  }
}
