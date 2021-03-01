import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_extensions_methods/dart_extensions_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/providers/user_state.dart';
import 'package:inventorio/widgets/inv_key.dart';
import 'package:inventorio/widgets/inventory_edit/inventory_edit_page.dart';
import 'package:inventorio/widgets/scan/scan_page.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  static const ROUTE = '/settings';

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserState, InvState>(
      builder: (context, userState, invState, child) => Scaffold(
        key: InvKey.SETTINGS_PAGE,
        appBar: AppBar(title: Text('Settings'),),
        body: Column(
          children: <Widget>[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).bottomAppBarColor,
                backgroundImage: userState.invAuth.photoUrl.isNullOrEmpty()
                    ? AssetImage('resources/icons/icon_small.png')
                    : CachedNetworkImageProvider(userState.invAuth.photoUrl),
              ),
              title: Text(userState.invAuth.displayName.isNullOrEmpty()
                  ? 'Profile'
                  : '${userState.invAuth.displayName}'),
              subtitle: Text(userState.invAuth.emailDisplay),
              trailing: IconButton(
                tooltip: 'Log Out',
                icon: Icon(Icons.exit_to_app),
                onPressed: () {
                  userState.signOut();
                  Navigator.pop(context);
                },
              ),
            ),
            Wrap(
              children: <Widget>[
                FlatButton(
                  padding: EdgeInsets.all(8.0),
                  onPressed: () async {
                    await Navigator.pushNamed(context, InventoryEditPage.ROUTE,
                      arguments: invState.createNewInventory()
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Icon(Icons.add),
                      Text('New'),
                      Text('Inventory'),
                    ],
                  ),
                ),
                FlatButton(
                  padding: EdgeInsets.all(8.0),
                  onPressed: () async {
                    if (!await ScanPage.hasPermissions(context)) {
                      return;
                    }

                    var popped = await Navigator.pushNamed(context, ScanPage.ROUTE);
                    String uuid = popped?.toString() ?? '';
                    if (uuid.isNotEmpty) {
                      var meta = await invState.addInventory(uuid);

                      if (meta.unset) {
                        await showOkAlertDialog(
                          context: context,
                          message: '${meta.uuid} is not a valid inventory code.'
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      FaIcon(FontAwesomeIcons.qrcode),
                      Text('Scan'),
                      Text('Inventory'),
                    ],
                  ),
                ),
                FlatButton(
                  padding: EdgeInsets.all(8.0),
                  onPressed: () async {
                    await Navigator.pushNamed(context, InventoryEditPage.ROUTE,
                      arguments: InvMetaBuilder.fromMeta(invState.selectedInvMeta())
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Icon(Icons.edit),
                      Text('Edit/Share'),
                      Text('Inventory'),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: invState.invMetas?.length ?? 0,
                itemBuilder: (context, index) {
                  var count = invState.inventoryItemCount(invState.invMetas[index].uuid);
                  var text = count == 1? 'item': 'items';
                  return ListTile(
                    title: Text('${invState.invMetas[index].name}'),
                    subtitle: Text('$count $text'),
                    selected: invState.invMetas[index] == invState.selectedInvMeta(),
                    onTap: () {
                      Navigator.pop(context);
                      invState.selectInvMeta(invState.invMetas[index]);
                    },
                    onLongPress: () async {
                      await Navigator.pushNamed(context, InventoryEditPage.ROUTE,
                        arguments: InvMetaBuilder.fromMeta(invState.invMetas[index])
                      );
                    },
                  );
                },
              )
            )
          ],
        ),
      ),
    );
  }
}
