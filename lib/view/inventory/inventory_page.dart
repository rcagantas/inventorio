
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/meta.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';
import 'package:inventorio/view/inventory/inventory_list.dart';
import 'package:inventorio/view/user/user_profile_list_tile.dart';
import 'package:inventorio/view/scan/scan_page.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({Key? key}) : super(key: key);

  Future<Meta> createNewMeta(WidgetRef ref) async {
    final uuid = ref.read(pluginsProvider).uuid;
    final user = ref.watch(userProvider);
    return await ref.read(actionSinkProvider).createNewMeta(user.userId!, uuid.v1());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth == null) return Container();

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_inventory_button',
            key: Key('add_inventory_button'),
            icon: Icon(Icons.add),
            label: Text('Add'),
            onPressed: () async {
              final meta = await createNewMeta(ref);
              await Navigator.pushNamed(context, '/inventory', arguments: meta);
            }
          ),
          FloatingActionButton.extended(
            key: Key('scan_inventory_button'),
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Scan'),
            onPressed: () async {
              final log = ref.read(pluginsProvider).logger;
              log.i('trying to scan for inventory code');
              final hasCameraPermission = await ScanPage.checkCameraPermission(context);
              if (!hasCameraPermission) return;

              final code = await Navigator.pushNamed(context, '/scan') as String?;
              if (code == null) return;

              await ref.read(actionSinkProvider).addInventoryId(code);
            }
          )
        ],
      ),
      appBar: AppBar(title: Text('Settings')),
      body: Column(
        children: [
          UserProfileListTile(),
          InventoryList()
        ],
      )
    );
  }
}
