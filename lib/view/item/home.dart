
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/app_user.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/main_items_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/view/inventory/inventory_name.dart';
import 'package:inventorio/view/item/sort_icon.dart';
import 'package:inventorio/view/scan/scan_page.dart';
import 'package:inventorio/view/item/item_search_delegate.dart';
import 'package:inventorio/view/item/item_card.dart';

class Home extends ConsumerWidget {

  final AppUser appUser;
  const Home({Key? key, required this.appUser}) : super(key: key);

  Future<void> onAddItem(BuildContext context, WidgetRef ref, String inventoryId) async {
    final log = ref.read(pluginsProvider).logger;
    log.i('trying to add new item in $inventoryId');
    final hasCameraPermission = await ScanPage.checkCameraPermission(context);
    if (!hasCameraPermission) return;

    final code = await Navigator.pushNamed(context, '/scan') as String?;
    if (code == null) return;

    final id = ref.read(pluginsProvider).uuid.v1();
    await Navigator.pushNamed(context, '/expiry', arguments: ItemBuilder(id, code, inventoryId).build());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.read(pluginsProvider).logger;
    final inventoryId = appUser.currentInventoryId ?? 'inventoryId';
    final items = ref.watch(mainItemsProvider);

    log.i('-- building home with ${items.length} items --');
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        key: Key('scan_button'),
        onPressed: () async { await onAddItem(context, ref, inventoryId); },
        child: Icon(Icons.qr_code_scanner),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(top: 3.0),
        itemCount: items.length,
        itemBuilder: (context, index) => ItemCard(items[index]),
      ),
      appBar: AppBar(
        actions: [
          SortIcon(),
          IconButton(onPressed: () => showSearch(context: context, delegate: ItemSearchDelegate(inventoryId)), icon: Icon(Icons.search))
        ],
        title: InventoryName(inventoryId: inventoryId,),
        leading: IconButton(
          icon: Image.asset('resources/icons/icon_small_white.png', fit: BoxFit.cover,),
          iconSize: 50,
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ),
    );
  }
}
