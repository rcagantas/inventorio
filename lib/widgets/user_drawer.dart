import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/dialog_factory.dart';
import 'package:inventorio/widgets/inventory_details_page.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  Widget build(BuildContext context) {
    return Drawer(
      child: StreamBuilder<UserAccount>(
        initialData: _repo.getCachedUser(),
        stream: _repo.userUpdateStream,
        builder: (context, snap) {
          var signedIn = snap.hasData && snap.data.isSignedIn;
          return ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              UserAccountsDrawerHeader(
                accountName: Text('${snap.data?.displayName}'),
                accountEmail: Text('${snap.data?.email}'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundImage:
                  snap.data?.imageUrl == null
                    ? AssetImage('resources/icons/icon.png')
                    : CachedNetworkImageProvider(
                        snap.data.imageUrl,
                        scale: 0.3
                      )
                ),
              ),
              ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text(signedIn ? 'Log out' : 'Login with Google', style: TextStyle(fontWeight: FontWeight.bold),),
                onTap: () async {
                  Navigator.of(context).pop();
                  if (signedIn) {
                    var confirmed = await DialogFactory.sureDialog(context, 'Are you sure you want to log out', 'Log out', 'Cancel');
                    if (confirmed) _bloc.actionSink(Action(Act.SignOut, null));
                  } else {
                    _bloc.actionSink(Action(Act.SignIn, null));
                  }
                },
              ),
              ExpansionTile(
                title: Text('Inventory Management'),
                children: <Widget>[
                  ListTile(
                    enabled: snap.data?.currentInventoryId != null,
                    dense: true,
                    title: Text('Create New Inventory'),
                  ),
                  ListTile(
                    enabled: snap.data?.currentInventoryId != null,
                    dense: true,
                    title: Text('Scan Existing Inventory Code'),
                  ),
                  ListTile(
                    enabled: snap.data?.currentInventoryId != null,
                    dense: true,
                    title: Text('Edit/share Current Inventory'),
                    onTap: () async {
                      InventoryDetails toEdit =  await _repo.getInventoryDetailFuture(snap.data?.currentInventoryId);
                      await Navigator.push(context,
                        MaterialPageRoute(builder: (context) => InventoryDetailsPage(toEdit))
                      );
                    },
                  ),
                ],
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: snap.data?.knownInventories?.length ?? 0,
                itemBuilder: (context, index) {
                  return StreamBuilder<InventoryDetails>(
                    stream: _repo.getInventoryDetailObservable(snap.data?.knownInventories[index]),
                    initialData: InventoryDetails(uuid: snap.data?.knownInventories[index], name: 'Inventory $index')
                      ..currentCount = 0
                      ..isSelected = false,
                    builder: (context, snap) {
                      return ListTile(
                        title: Text('${snap.data?.name ?? 'Inventory $index'}'),
                        subtitle: Text('${snap.data.currentCount} items'),
                        selected: snap.data.isSelected,
                        onTap: () {
                          Navigator.of(context).pop();
                          _bloc.actionSink(Action(Act.ChangeInventory, snap.data));
                        },
                      );
                    },
                  );
                }
              )
            ],
          );
        }
      )
    );
  }
}
