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
        stream: _bloc.detailStream,
        builder: (context, snapshot) {

          var header = UserAccountsDrawerHeader(
            accountName: StreamBuilder<List<InventoryDetailsEx>>(
              stream: _bloc.detailStream,
              builder: (context, snapshot) {
                InventoryDetailsEx detailsEx = snapshot.data?.firstWhere((i) => i.isSelected);
                return detailsEx != null ? Text('${detailsEx.name}') : Text('Default');
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
                  onTap: () {
                    Navigator.of(context).pop();
                    _bloc.changeCurrentInventory(i.uuid);
                  },
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
