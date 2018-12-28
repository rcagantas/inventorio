import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/dialog_factory.dart';
import 'package:inventorio/widgets/inventory_details_page.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  Widget build(BuildContext context) {
    return Drawer(
      child: StreamBuilder<UserAccount>(
        stream: _bloc.userAccountStream,
        builder: (context, userSnapshot) {
          var signedIn = userSnapshot.hasData && userSnapshot.data.isSignedIn;
          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              UserAccountsDrawerHeader(
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundImage: AssetImage('resources/icons/icon.png'),
                ),
                accountName: StreamBuilder<InventoryDetails>(
                  stream: _bloc.getInventoryDetailObservable(userSnapshot.data?.currentInventoryId),
                  builder: (context, detailSnapshot) {
                    return detailSnapshot.hasData
                      ? Text('${detailSnapshot.data.name}')
                      : Text('Current Inventory');
                  }
                ),
                accountEmail: StreamBuilder<List<InventoryItem>>(
                  stream: _bloc.itemStream,
                  builder: (context, snapshot) {
                    return snapshot.hasData
                      ? Text('${snapshot.data.length} items')
                      : Text('0 items');
                  }
                ),
              ),
              ListTile(
                title: Text(signedIn ? 'Log out' : 'Login with Google'),
                subtitle: Text(signedIn ? 'Logged in as ${userSnapshot.data.displayName}' : ''),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (signedIn) {
                    var confirmed = await DialogFactory.sureDialog(context, 'Are you sure you want to log out', 'Log out', 'Cancel');
                    if (confirmed) _bloc.actionSink(ActionEvent(Action.SignOut, null));
                  } else {
                    _bloc.actionSink(ActionEvent(Action.SignIn, null));
                  }
                },
              ),
              ExpansionTile(
                title: Text('Inventory Management'),
                children: <Widget>[
                  ListTile(
                    enabled: userSnapshot.data?.currentInventoryId != null,
                    dense: true,
                    title: Text('Create New Inventory'),
                  ),
                  ListTile(
                    enabled: userSnapshot.data?.currentInventoryId != null,
                    dense: true,
                    title: Text('Scan Existing Inventory Code'),
                  ),
                  ListTile(
                    enabled: userSnapshot.data?.currentInventoryId != null,
                    dense: true,
                    title: Text('Edit/share Current Inventory'),
                    onTap: () async {
                      InventoryDetails toEdit =  await _bloc.getInventoryDetails(userSnapshot.data?.currentInventoryId);
                      InventoryDetails edited = await Navigator.push(context,
                        MaterialPageRoute(builder: (context) => InventoryDetailsPage(toEdit))
                      );
                    },
                  ),
                ],
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: userSnapshot.data?.knownInventories?.length ?? 0,
                itemBuilder: (context, index) {
                  return StreamBuilder<InventoryDetails>(
                    stream: _bloc.getInventoryDetailObservable(userSnapshot.data?.knownInventories[index]),
                    builder: (context, detailSnapshot) {
                      return ListTile(
                        title: detailSnapshot.hasData
                          ? Text('${detailSnapshot.data.name}')
                          : Text('${userSnapshot.data.knownInventories[index]}'),
                        subtitle: StreamBuilder<List<InventoryItem>>(
                          stream: _bloc.getItemListObservable(detailSnapshot.data?.uuid),
                          builder: (context, snapshot) {
                            return snapshot.hasData
                              ? Text('${snapshot.data.length} items')
                              : Text('0 items');
                          },
                        ),
                        selected: userSnapshot.data?.knownInventories[index] == userSnapshot.data?.currentInventoryId,
                        onTap: () {
                          _bloc.actionSink(ActionEvent(Action.ChangeInventory, detailSnapshot.data.toJson()));
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                }
              )
            ],
          );
        },
      ),
    );
  }
}
