import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/dialog_factory.dart';
import 'package:inventorio/widgets/inventory_details_page.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          StreamBuilder<List<InventoryDetails>>(
            stream: _bloc.detailStream,
            builder: (context, snapshot) {
              return UserAccountsDrawerHeader(
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundImage: AssetImage('resources/icons/icon.png'),
                ),
                accountName: snapshot.hasData && snapshot.data.length > 0
                  ? Text('${snapshot.data.firstWhere((i) => i.isSelected).name}')
                  : Text('Current Inventory'),
                accountEmail: snapshot.hasData && snapshot.data.length > 0
                  ? Text('${snapshot.data.firstWhere((i) => i.isSelected).currentCount} items')
                  : Text('0 items'),
              );
            },
          ),
          StreamBuilder<UserAccount>(
            stream: _bloc.userAccountStream,
            builder: (context, snapshot) {
              var signedIn = snapshot.hasData && snapshot.data.isSignedIn;
              return ListTile(
                title: Text(signedIn ? 'Log out' : 'Login with Google'),
                subtitle: Text(signedIn ? 'Logged in as ${snapshot.data.displayName}' : ''),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (signedIn) {
                    var confirmed = await DialogFactory.sureDialog(context, 'Are you sure you want to log out', 'Log out', 'Cancel');
                    if (confirmed) _bloc.actionSink(ActionEvent(Action.SignOut, null));
                  } else {
                    _bloc.actionSink(ActionEvent(Action.SignIn, null));
                  }
                },
              );
            }
          ),
          StreamBuilder<List<InventoryDetails>>(
            stream: _bloc.detailStream,
            builder: (context, snapshot) {
              var selected = snapshot.hasData && snapshot.data.length > 0
                  ? snapshot.data?.firstWhere((i) => i.isSelected)
                  : null;
              return ExpansionTile(
                title: Text('Inventory Management'),
                children: <Widget>[
                  ListTile(
                    enabled: selected != null,
                    dense: true,
                    title: Text('Create New Inventory'),
                  ),
                  ListTile(
                    enabled: selected != null,
                    dense: true,
                    title: Text('Scan Existing Inventory Code'),
                  ),
                  ListTile(
                    enabled: selected != null,
                    dense: true,
                    title: Text('Edit/share Current Inventory'),
                    onTap: () async {
                      InventoryDetails edited = await Navigator.push(context,
                          MaterialPageRoute(builder: (context) => InventoryDetailsPage(selected),)
                      );
                    },
                  ),
                ],
              );
            }
          ),
          StreamBuilder<List<InventoryDetails>>(
            stream: _bloc.detailStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('${snapshot.data[index].name}: ${snapshot.data[index].currentCount} items'),
                    selected: snapshot.data[index].isSelected,
                    onTap: () {
                      Navigator.of(context).pop();
                      _bloc.actionSink(ActionEvent(Action.ChangeInventory, snapshot.data[index].toJson()));
                    },
                  );
                }
              );
            },
          ),
        ],
      ),
    );
  }
}
