import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/inventory_bloc.dart';
import 'package:inventorio/data/definitions.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
//            accountName: Text(model?.selected?.details?.name ?? 'Current Inventory Name'),
//            accountEmail: Text('${model?.selected?.items?.length ?? '?'} items',),
            accountName: StreamBuilder(
              stream: _bloc.inventoryStream,
              builder: (context, AsyncSnapshot<InventoryDetails> snapshot) {
                print('${snapshot.data}');
                return snapshot.hasData
                    ? Text('${snapshot.data.name}')
                    : Text('Default');
              },
            ),
            accountEmail: Text('items'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              backgroundImage: AssetImage('resources/icons/icon.png'),
            ),
          ),
        ],
      ),
    );
  }
}
