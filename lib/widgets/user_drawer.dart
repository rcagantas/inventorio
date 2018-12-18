import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/data/definitions.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: StreamBuilder<List<InventoryDetailsEx>>(
        stream: _bloc.detailsStream,
        builder: (context, snapshot) {

          var header = UserAccountsDrawerHeader(
            accountName: StreamBuilder<InventoryDetails>(
              stream: _bloc.inventoryStream,
              builder: (context, snapshot) {
                return snapshot.hasData ? Text('${snapshot.data.name}') : Text('Default');
              },
            ),
            accountEmail: StreamBuilder<List<InventoryItemEx>>(
              stream: _bloc.itemStream,
              builder: (context, snapshot) {
                return snapshot.hasData ? Text('${snapshot.data.length} items'): Text('? items');
              },
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              backgroundImage: AssetImage('resources/icons/icon.png'),
            ),
          );

          List<Widget> widgets = [];
          widgets.add(header);

          if (snapshot.hasData) {
            snapshot.data.forEach((i) {
              widgets.add(
                ListTile(
                  selected: i.isSelected,
                  title: Text('${i.name}'),
                  subtitle: Text('${i.currentCount} items'),
                )
              );
            });
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: widgets,
          );
        },
      ),
    );
  }
}
