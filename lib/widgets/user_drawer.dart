import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/pages/about_page.dart';
import 'package:inventorio/pages/all_items_page.dart';
import 'package:inventorio/widgets/app_constants.dart';
import 'package:inventorio/widgets/dialog_factory.dart';
import 'package:inventorio/pages/inventory_details_page.dart';
import 'package:inventorio/pages/scan_page.dart';
import 'package:inventorio/pages/logging_page.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  static const int PRE_ITEMS = 4;
  static const int POST_ITEMS = 1;

  Widget build(BuildContext context) {
    return StreamBuilder<UserAccount>(
      initialData: _repo.getCachedUser(),
      stream: _repo.userUpdateStream,
      builder: (context, snap) {
        return buildWithUser(context, snap.data);
      },
    );
  }

  Widget _expansionItem(BuildContext context, UserAccount userAccount, String text, Function() push) {
    var styleItem = TextStyle(fontFamily: AppConstants.ITEM_FONT);
    return ListTile(
      enabled: userAccount.isSignedIn,
      dense: true,
      title: Text(text, style: styleItem,),
      onTap: () {
        Navigator.popUntil(context, ModalRoute.withName('/'));
        push();
      },
    );
  }

  Widget buildWithUser(BuildContext context, UserAccount userAccount) {
    var styleItem = TextStyle(fontFamily: AppConstants.ITEM_FONT);
    var styleSubTitle = TextStyle(fontFamily: AppConstants.NUMERIC_FONT);
    var inventoryLength = userAccount.knownInventories?.length ?? 0;

    List<Widget> drawerItems = [
      UserAccountsDrawerHeader(
        accountName: Text('${userAccount.displayName}'),
        accountEmail: Text('${userAccount.email}'),
        currentAccountPicture: CircleAvatar(
            key: ObjectKey('${userAccount.email}_avatar'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          backgroundImage:
          userAccount.imageUrl == null
            ? AssetImage('resources/icons/icon.png')
            : CachedNetworkImageProvider(userAccount.imageUrl, scale: 0.3)
        ),
      ),
      ListTile(
        leading: Icon(Icons.exit_to_app),
        title: Text('Log out', style: TextStyle(fontWeight: FontWeight.bold),),
        enabled: !userAccount.isLoading
            && userAccount.isSignedIn
            && userAccount.displayName != RepositoryBloc.CACHED_DATA,
        onTap: () async {
          Navigator.popUntil(context, ModalRoute.withName('/'));
          var confirmed = await DialogFactory.sureDialog(context, 'Are you sure you want to log out', 'Log out', 'Cancel');
          if (confirmed) { _bloc.actionSink(InvAction(Act.SignOut, null)); }
        },
      ),
      ExpansionTile(
        title: Text('Inventory Management', style: styleItem,),
        children: <Widget>[
          _expansionItem(context, userAccount, 'Create New Inventory', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
          }),
          _expansionItem(context, userAccount, 'Scan Existing Inventory Code', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ScanPage())).then((code) {
              _bloc.actionSink(InvAction(Act.AddInventory, code));
            });
          }),
          _expansionItem(context, userAccount, 'Edit/share Current Inventory', () {
            _repo.getInventoryDetailFuture(userAccount.currentInventoryId).then((toEdit) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(toEdit)));
            });
          }),
          _expansionItem(context, userAccount, 'Logs', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => LoggingPage()));
          }),
        ],
      ),
      ListTile(
        title: Text('All Items', style: styleItem,),
        onTap: () {
          Navigator.popUntil(context, ModalRoute.withName('/'));
          Navigator.push(context, MaterialPageRoute(builder: (context) => AllItemsPage()));
          Future.delayed(Duration(milliseconds: 300), () {
            _bloc.actionSink(InvAction(Act.SelectAll, true));
          });
        },
      ),
    ];


    return Drawer(
      child: ListView.builder(
        key: ObjectKey('${userAccount.email}_drawer_list'),
        padding: EdgeInsets.zero,
        itemCount: PRE_ITEMS + inventoryLength + POST_ITEMS,
        itemBuilder: (context, index) {
          if (index < PRE_ITEMS) {
            return drawerItems[index];
          } else if (PRE_ITEMS <= index && index < PRE_ITEMS + inventoryLength) {
            return StreamBuilder<InventoryDetails>(
              key: ObjectKey('${userAccount.email}_detail_stream_$index'),
              stream: _repo.getInventoryDetailObservable(userAccount.knownInventories[index - PRE_ITEMS]),
              initialData: InventoryDetails(uuid: userAccount.knownInventories[index - PRE_ITEMS], name: 'Inventory $index')
                ..currentCount = 0
                ..isSelected = false,
              builder: (context, snap) {
                if (!snap.hasData) return SizedBox.shrink();

                var title = '${snap.data?.name ?? 'Inventory $index'}';
                var subTitle = '${snap.data?.currentCount ?? 0} items';
                return ListTile(
                  key: ObjectKey('${snap.data.uuid}_detail_item_$index'),
                  title: Text(title, style: styleItem,),
                  subtitle: Text(subTitle, style: styleSubTitle,),
                  selected: snap.data?.isSelected ?? false,
                  onTap: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    Future.delayed(Duration(milliseconds: 300), () {
                      _bloc.actionSink(InvAction(Act.ChangeInventory, snap.data.uuid));
                    });
                  },
                );
              },
            );
          } else if (PRE_ITEMS + inventoryLength <= index) {
            return ListTile(
              title: Text('About', style: styleItem,),
              onTap: () {
                Navigator.popUntil(context, ModalRoute.withName('/'));
                Navigator.push(context, MaterialPageRoute(builder: (context) => AboutPage()));
              },
            );
          } else {
            return SizedBox.shrink();
          }
        }
      ),
    );
  }
}
