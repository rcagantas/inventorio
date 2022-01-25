import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dart_extensions_methods/dart_extensions_methods.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_expiry.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/models/inv_user.dart';
import 'package:inventorio/models/inv_status.dart';
import 'package:inventorio/services/inv_scheduler_service.dart';
import 'package:inventorio/services/inv_store_service.dart';
import 'package:inventorio/utils/log/log_printer.dart';
import 'package:logger/logger.dart';

enum InvSort {
  EXPIRY,
  DATE_ADDED,
  PRODUCT
}

class InvState with ChangeNotifier {
  final logger = Logger(printer: SimpleLogPrinter('InvState'));

  InvStatus currentInvStatus;
  InvUser invUser;
  Map<String, InvMeta> _invMetas = {};
  Map<String, List<InvItem>> _invItemMap = {};
  Map<String, InvProduct> _invProductMap = {};
  Map<String, InvProduct> _invLocalProductMap = {};

  final Clock _clock;
  final InvStoreService _invStoreService;
  final InvSchedulerService _invSchedulerService;

  StreamSubscription<InvUser> _userSubscription;
  Map<String, StreamSubscription<InvMeta>> _inventoryMetaSubs = {};
  Map<String, StreamSubscription<List<InvItem>>>_inventorySubs = {};
  Map<String, StreamSubscription<InvProduct>> _productSubs = {};
  Map<String, StreamSubscription<InvProduct>> _localProductSubs = {};

  Map<InvSort, int Function(InvItem item1, InvItem item2)> _sortingFunctionMap;
  InvSort sortingKey = InvSort.EXPIRY;

  List<InvMeta> get invMetas {
    var metaList = invUser.knownInventories
        .where((e) => _invMetas.containsKey(e))
        .map((e) => _invMetas[e]).toList();

    metaList.sort();
    return metaList;
  }

  Timer _schedulerTimer;

  InvState() :
    _clock = GetIt.instance<Clock>(),
    _invStoreService = GetIt.instance<InvStoreService>(),
    _invSchedulerService = GetIt.instance<InvSchedulerService>()
  {
    invUser = InvUser.unset(userId: null);
    _invSchedulerService.initialize(onSelectNotification: onSelectNotification);
    _sortingFunctionMap = {
      InvSort.EXPIRY: expirySort,
      InvSort.DATE_ADDED: dateSort,
      InvSort.PRODUCT: productSort
    };

    addListener(() {
      if (_schedulerTimer != null) {
        _schedulerTimer.cancel();
      }
      _schedulerTimer = Timer(Duration(milliseconds: 100), () => _runSchedulerWhenListComplete());
    });
  }

  Future<void> onSelectNotification(String metaId) async {
    logger.i('Selecting notification with payload $metaId');
    await selectInventory(metaId);
  }

  Future<bool> _checkForFinalizedList() async {
    await Future.delayed(Duration(milliseconds: 50));
    var listToSchedule = _invItemMap.values.expand((e) => e).toList();

    for (InvItem item in listToSchedule) {
      var product = getProduct(item.code);

      if (product.unset)  {
        return true;
      }
    }

    await _runSchedulerWhenListComplete();
    return false;
  }

  Future<void> isReady() async {
    return Future.doWhile(() => _checkForFinalizedList())
        .timeout(Duration(milliseconds: 500), onTimeout: _runSchedulerWhenListComplete);
  }

  Future<void> userStateChange({InvStatus status, InvAuth auth}) async {
    if (currentInvStatus != status) {
      currentInvStatus = status;

      if (currentInvStatus == InvStatus.Unauthenticated) {
        this.clear();
      } else if (currentInvStatus == InvStatus.Authenticated) {
        await this.loadUserId(auth);
      }

    }
  }

  Future<void> clear() async {
    _invMetas = {};
    _invItemMap = {};

    invUser = InvUser.unset(userId: null);
    if (_userSubscription != null) {
      await _userSubscription.cancel();
      await _cancelSubscriptions();
      _userSubscription = null;
    }
  }

  Future<void> loadUserId(InvAuth invAuth) async {
    if (invUser.userId == invAuth.uid) {
      return;
    }

    await _invStoreService.migrateUserFromGoogleIdIfPossible(invAuth);
    await _subscribeToUser(invAuth.uid);
    await isReady();
  }

  Future<void> _cancelSubscriptions() async {
    logger.i('Cancelling subscriptions...');
    List<Future> cancellations = [];
    cancellations.addAll(_inventoryMetaSubs.values.map((e) => e.cancel()));
    cancellations.addAll(_inventorySubs.values.map((e) => e.cancel()));
    cancellations.addAll(_localProductSubs.values.map((e) => e.cancel()));
    await Future.wait(cancellations);
    logger.i('Cancelled ${cancellations.length} subscriptions');

    _inventoryMetaSubs.clear();
    _inventorySubs.clear();
    _localProductSubs.clear();

    notifyListeners();
  }

  Future<void> _subscribeToUser(String userId) async {
    if (_userSubscription != null) { await _userSubscription.cancel(); }
    _userSubscription = _invStoreService.listenToUser(userId).listen(_onInvUser);
  }

  Future<void> _onInvUser(InvUser user) async {

    if (user.unset) {
      logger.i('Creating new user ${user.userId}');
      invUser = _invStoreService.createNewUser(user.userId);
    } else {
      logger.i('Loading user ${user.userId}');
      invUser = user;
    }

    if (_invItemMap.containsKey(invUser.currentInventoryId)) {
      _invItemMap[invUser.currentInventoryId].sort(getSortingFunction(sortingKey));
    }

    notifyListeners();
    invUser.knownInventories.forEach((invMetaId) {
      _subscribeToInventoryList(invMetaId);
      _subscribeToInventoryMeta(invMetaId);
    });
  }

  void _subscribeToInventoryMeta(String invMetaId) {
    _inventoryMetaSubs.putIfAbsent(invMetaId, () {
      return _invStoreService.listenToInventoryMeta(invMetaId).listen(_onInvMeta);
    });
  }

  void _onInvMeta(InvMeta invMeta) {
    _invMetas[invMeta.uuid] = invMeta;
    notifyListeners();
  }

  void _subscribeToInventoryList(String invMetaId) {
    _inventorySubs.putIfAbsent(invMetaId, () {
      logger.i('Subscribing to list $invMetaId');
      return _invStoreService.listenToInventoryList(invMetaId).listen((event) {
        _onInvList(invMetaId, event);
      });
    });
  }

  Future<void> _runSchedulerWhenListComplete() async {
    var listToSchedule = _invItemMap.values.expand((e) => e).toList();
    var expiryList = <InvExpiry>[];

    for (InvItem item in listToSchedule) {
      var product = getProduct(item.code);

      if (product.unset)  {
        logger.w('Product information is not ready. Deferred scheduling for ${item.uuid}.');
        continue;
      }

      expiryList.add(InvExpiry(item: item, product: product, daysOffset: item.redOffset));
      expiryList.add(InvExpiry(item: item, product: product, daysOffset: item.yellowOffset));
    }

    var now = _clock.now();
    expiryList..removeWhere((element) => element.alertDate.compareTo(now) < 0)..sort();
    expiryList = expiryList.sublist(0, expiryList.length > 64? 64 : expiryList.length);

    await _invSchedulerService.clearScheduledTasks();
    logger.i('Running scheduler for ${expiryList.length} items');

    for (var expiry in expiryList) {
      var delayMs = 50 * expiryList.indexOf(expiry);
      _invSchedulerService.delayedScheduleNotification(expiry, delayMs);
    }
  }

  void _onInvList(String invMetaId, List<InvItem> list) {
    _invItemMap[invMetaId] = list;

    if (list.isNotNullOrEmpty()) {
      _invItemMap[invMetaId].sort(getSortingFunction(sortingKey));

      for (var invItem in _invItemMap[invMetaId]) {
        _subscribeToProduct(invMetaId, invItem.code);
      }
    }

    notifyListeners();
  }

  void _subscribeToProduct(String invMetaId, String code) {
    _productSubs.putIfAbsent(code, () {
      return _invStoreService.listenToProduct(code)
          .listen(_onInvProductUpdate);
    });

    _localProductSubs.putIfAbsent('$invMetaId-$code', () {
      return _invStoreService.listenToLocalProduct(invMetaId, code)
          .listen(_onInvLocalProductUpdate);
    });
  }

  Future<InvProduct> fetchProduct(String code) async {
    if (getProduct(code).unset) {
      _subscribeToProduct(invUser.currentInventoryId, code);
      String invMetaId = invUser.currentInventoryId;

      var product = await _invStoreService.fetchProduct(code);
      var localProduct = await _invStoreService.fetchLocalProduct(invMetaId, code);

      if (product.unset && localProduct.unset) {
        logger.i('Unknown product: $code');
      }

      _onInvProductUpdate(product);
      _onInvLocalProductUpdate(localProduct);
    }

    return getProduct(code);
  }

  void _onInvProductUpdate(InvProduct invProduct) {
    if (invProduct.unset) {
      return;
    }

    String code = invProduct.code;

    if (!_invProductMap.containsKey(code) || _invProductMap[code] != invProduct) {
      _invProductMap[code] = invProduct;
      logger.i('Product ${invProduct.toJson()}');
      notifyListeners();
    }
  }

  void _onInvLocalProductUpdate(InvProduct invProduct) {
    if (invProduct.unset) {
      return;
    }

    String code = invProduct.code;
    if (!_invLocalProductMap.containsKey(code) || _invLocalProductMap[code] != invProduct) {
      _invLocalProductMap[code] = invProduct;
      logger.i('Local Product ${invProduct.toJson()}');
      notifyListeners();
    }
  }

  bool isLoading() {
    return _invItemMap[invUser.currentInventoryId] == null;
  }

  InvProduct getProduct(String code) {
    InvProduct defaultProduct = InvProduct.unset(code: code);
    InvProduct master = _invProductMap.containsKey(code) ? _invProductMap[code] : defaultProduct;
    InvProduct local = _invLocalProductMap.containsKey(code) ? _invLocalProductMap[code] : defaultProduct;

    return !local.unset ? local : master;
  }

  int productSort(InvItem item1, InvItem item2) {
    return getProduct(item1.code).compareTo(getProduct(item2.code));
  }

  int expirySort(InvItem item1, InvItem item2) {
    int comparison = item1.expiry.compareTo(item2.expiry);
    return comparison != 0 ? comparison : productSort(item1, item2);
  }

  int dateSort(InvItem item1, InvItem item2) {
    int comparison = item2.dateAdded.compareTo(item1.dateAdded);
    return comparison != 0 ? comparison : productSort(item1, item2);
  }

  int Function(InvItem item1, InvItem item2) getSortingFunction(InvSort sortingKey) {
    return _sortingFunctionMap[sortingKey];
  }

  InvMeta selectedInvMeta() {
    return _invMetas.containsKey(invUser.currentInventoryId)
        ? _invMetas[invUser.currentInventoryId]
        : InvMeta(name: 'Inventory');
  }

  List<InvItem> selectedInvList() {
    return _invItemMap[invUser.currentInventoryId] ?? [];
  }

  int inventoryItemCount(String metaId) {
    return _invItemMap[metaId]?.length ?? 0;
  }

  void toggleSort() {
    var index = InvSort.values.indexOf(sortingKey);
    sortingKey = InvSort.values[(index + 1) % InvSort.values.length];

    var invMetaId = selectedInvMeta().uuid;
    _invItemMap[invMetaId].sort(getSortingFunction(sortingKey));
    notifyListeners();
  }

  Future<void> selectInventory(String metaId) async {
    if (!invUser.unset && invUser.knownInventories.contains(metaId)) {
      logger.i('Selecting inventory $metaId');
      var userBuilder = InvUserBuilder.fromUser(invUser)
        ..currentInventoryId = metaId;
      await _invStoreService.updateUser(userBuilder);
    }
  }

  Future<void> selectInvMeta(InvMeta invMeta) async {
    await selectInventory(invMeta.uuid);
  }

  Future<void> removeItem(InvItem item) async {
    logger.i('Deleting item [${getProduct(item.code).name}] ${item.toJson()}');
    await _invStoreService.deleteItem(item);
  }

  Future<void> updateItem(InvItemBuilder itemBuilder) async {
    var product = await fetchProduct(itemBuilder.code);
    if (product.unset) {
      logger.i('Product is unset. Aborting add of item ${itemBuilder.toJson()}');
      return;
    }

    logger.i('Adding item [${product.name}] ${itemBuilder.toJson()}');
    await _invStoreService.updateItem(itemBuilder);
  }

  Future<void> updateProduct(InvProductBuilder productBuilder) async {
    if (invUser.currentInventoryId.isNullOrEmpty()) {
      logger.w('User is unset or currentInventoryId is unset');
      return;
    }

    if (productBuilder.build() == getProduct(productBuilder.code)
        && productBuilder.imageFile == null) {
      logger.w('Product [${productBuilder.name}]: Information did not change. Ignoring.');
      return;
    }

    logger.i('Adding product [${productBuilder.name}] ${productBuilder.toString()}');

    // we need to update the cache immediately so that we can add the item.
    _onInvLocalProductUpdate(productBuilder.build());

    await _invStoreService.updateProduct(productBuilder, invUser.currentInventoryId);
    await _updateProductWithImage(productBuilder);
  }

  Future<void> _updateProductWithImage(InvProductBuilder productBuilder) async {

    if (productBuilder.resizedImageFileFuture == null) {
      return;
    }

    File resized = await productBuilder.resizedImageFileFuture;

    String imageUrl = await _invStoreService.uploadProductImage(productBuilder.code, resized);
    productBuilder.imageUrl = imageUrl;

    logger.i('Re-uploading with ${productBuilder.imageUrl}');
    await _invStoreService.updateProduct(productBuilder, invUser.currentInventoryId);

    await productBuilder.imageFile.delete();
    await resized.delete();
  }

  Future<void> updateInvMeta(InvMetaBuilder invMetaBuilder) async {
    if (invMetaBuilder.createdBy == null) {
      invMetaBuilder.createdBy = invUser.userId;
    }

    await _invStoreService.updateMeta(invMetaBuilder);
  }

  Future<void> unsubscribeFromInventory(String uuid) async {
    if (invUser.knownInventories.contains(uuid)
        && invUser.knownInventories.length > 1
    ) {
      logger.i('Removing inventory $uuid');
      var userBuilder = InvUserBuilder.fromUser(invUser)
        ..knownInventories.remove(uuid);

      if (userBuilder.currentInventoryId == uuid) {
        userBuilder.currentInventoryId = userBuilder.knownInventories[0];
      }

      await _invStoreService.updateUser(userBuilder);
    }
  }

  Future<InvMeta> addInventory(String uuid) async {
    var meta = await _invStoreService.fetchInvMeta(uuid);

    if (meta.unset) {
      logger.e("trying to add inventory that doesn't exist!");
      return meta;
    }

    if (!invUser.knownInventories.contains(uuid)) {
      logger.i('Adding inventory $uuid');
      var userBuilder = InvUserBuilder.fromUser(invUser)
        ..currentInventoryId = uuid
        ..knownInventories.add(uuid);
      await _invStoreService.updateUser(userBuilder);

    } else if (invUser.knownInventories.contains(uuid)) {
      await this.selectInventory(uuid);
    }
    return meta;
  }

  InvMetaBuilder createNewInventory() {
    return _invStoreService.createNewMeta(invUser.userId);
  }
}