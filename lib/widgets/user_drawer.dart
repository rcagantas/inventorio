import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
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

          var login = StreamBuilder<UserAccountEx>(
            stream: _bloc.userAccountStream,
            builder: (context, snapshot) {
              var signedIn = snapshot.hasData && snapshot.data.displayName != null;
              return ListTile(
                title: Text(signedIn ? 'Log out' : 'Login with Google'),
                subtitle: Text(signedIn ? 'Logged in as ${snapshot.data.displayName}' : 'Log in'),
              );
            }
          );


          List<Widget> widgets = [];
          widgets.add(header);
          widgets.add(login);
          widgets.add(Divider());

          if (snapshot.hasData) {
            snapshot.data.forEach((i) {
              widgets.add(
                ListTile(
                  selected: i.isSelected,
                  title: Text('${i.name}'),
                  subtitle: Text('${i.currentCount} items'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _bloc.actionSink(ActionEvent(Action.ChangeInventory, i.toJson()));
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
