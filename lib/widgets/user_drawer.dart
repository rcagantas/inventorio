import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/pages/all_items_page.dart';
import 'package:inventorio/widgets/dialog_factory.dart';
import 'package:inventorio/pages/inventory_details_page.dart';
import 'package:inventorio/pages/scan_page.dart';
import 'package:inventorio/pages/logging_page.dart';

class UserDrawer extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  static const int PRESET_ITEMS = 4;

  Widget build(BuildContext context) {
    return StreamBuilder<UserAccount>(
      initialData: _repo.getCachedUser(),
      stream: _repo.userUpdateStream,
      builder: (context, snap) {
        return buildWithUser(context, snap.data);
      },
    );
  }

  Widget buildWithUser(BuildContext context, UserAccount userAccount) {
    var styleItem = TextStyle(fontFamily: 'OpenSans');
    var styleSubTitle = TextStyle(fontFamily: 'Raleway');
    return Drawer(
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: PRESET_ITEMS + userAccount.knownInventories?.length ?? 0,
        itemBuilder: (context, index) {
          switch (index) {
            case 0: return UserAccountsDrawerHeader(
              accountName: Text('${userAccount.displayName}'),
              accountEmail: Text('${userAccount.email}'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                backgroundImage:
                userAccount.imageUrl == null
                  ? AssetImage('resources/icons/icon.png')
                  : CachedNetworkImageProvider(userAccount.imageUrl, scale: 0.3)
              ),
            );
            case 1: return ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text(userAccount.isSignedIn ? 'Log out' : 'Login with Google', style: TextStyle(fontWeight: FontWeight.bold),),
              onTap: () async {
                Navigator.popUntil(context, ModalRoute.withName('/'));
                if (userAccount.isSignedIn) {
                  var confirmed = await DialogFactory.sureDialog(context, 'Are you sure you want to log out', 'Log out', 'Cancel');
                  if (confirmed) {
                    _bloc.actionSink(Action(Act.SignOut, null));
                  }
                } else {
                  _bloc.actionSink(Action(Act.SignIn, null));
                }
              },
            );
            case 2: return ExpansionTile(
              title: Text('Inventory Management', style: styleItem,),
              children: <Widget>[
                ListTile(
                  enabled: userAccount.isSignedIn,
                  dense: true,
                  title: Text('Create New Inventory', style: styleItem,),
                  onTap: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
                  },
                ),
                ListTile(
                  enabled: userAccount.isSignedIn,
                  dense: true,
                  title: Text('Scan Existing Inventory Code', style: styleItem,),
                  onTap: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ScanPage())).then((code) {
                      _bloc.actionSink(Action(Act.AddInventory, code));
                    });
                  },
                ),
                ListTile(
                  enabled: userAccount.isSignedIn,
                  dense: true,
                  title: Text('Edit/share Current Inventory', style: styleItem,),
                  onTap: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    _repo.getInventoryDetailFuture(userAccount.currentInventoryId).then((toEdit) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(toEdit)));
                    });
                  },
                ),
                ListTile(
                  enabled: true,
                  dense: true,
                  title: Text('Logs', style: styleItem,),
                  onTap: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LoggingPage()));
                  }
                )
              ],
            );
            case 3: return ListTile(
              title: Text('All Items', style: styleItem,),
              onTap: () {
                Navigator.popUntil(context, ModalRoute.withName('/'));
                Navigator.push(context, MaterialPageRoute(builder: (context) => AllItemsPage()));
                Future.delayed(Duration(milliseconds: 300), () {
                  _bloc.actionSink(Action(Act.SelectAll, true));
                });
              },
            );
            default: return StreamBuilder<InventoryDetails>(
              stream: _repo.getInventoryDetailObservable(userAccount.knownInventories[index - PRESET_ITEMS]),
              initialData: InventoryDetails(uuid: userAccount.knownInventories[index - PRESET_ITEMS], name: 'Inventory $index')
                ..currentCount = 0
                ..isSelected = false,
              builder: (context, snap) {
                return ListTile(
                  title: Text('${snap.data?.name ?? 'Inventory $index'}', style: styleItem,),
                  subtitle: Text('${snap.data?.currentCount ?? 0} items', style: styleSubTitle,),
                  selected: snap.data?.isSelected ?? false,
                  onTap: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                    Future.delayed(Duration(milliseconds: 300), () {
                      _bloc.actionSink(Action(Act.ChangeInventory, snap.data.uuid));
                    });
                  },
                );
              },
            );
          }
        }
      )
    );
  }

  Widget buildWithUser1(BuildContext context, UserAccount userAccount) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text('${userAccount.displayName}'),
            accountEmail: Text('${userAccount.email}'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              backgroundImage:
              userAccount.imageUrl == null
                ? AssetImage('resources/icons/icon.png')
                : CachedNetworkImageProvider(userAccount.imageUrl, scale: 0.3)
            ),
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text(userAccount.isSignedIn ? 'Log out' : 'Login with Google', style: TextStyle(fontWeight: FontWeight.bold),),
            onTap: () async {
              Navigator.popUntil(context, ModalRoute.withName('/'));
              if (userAccount.isSignedIn) {
                var confirmed = await DialogFactory.sureDialog(context, 'Are you sure you want to log out', 'Log out', 'Cancel');
                if (confirmed) {
                  _bloc.actionSink(Action(Act.SignOut, null));
                  Navigator.popUntil(context, ModalRoute.withName('/'));
                }
              } else {
                _bloc.actionSink(Action(Act.SignIn, null));
              }
            },
          ),
          ExpansionTile(
            title: Text('Inventory Management'),
            children: <Widget>[
              ListTile(
                enabled: userAccount.isSignedIn,
                dense: true,
                title: Text('Create New Inventory'),
                onTap: () {
                  Navigator.popUntil(context, ModalRoute.withName('/'));
                  Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
                },
              ),
              ListTile(
                enabled: userAccount.isSignedIn,
                dense: true,
                title: Text('Scan Existing Inventory Code'),
                onTap: () {
                  Navigator.popUntil(context, ModalRoute.withName('/'));
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ScanPage())).then((code) {
                    _bloc.actionSink(Action(Act.AddInventory, code));
                  });
                },
              ),
              ListTile(
                enabled: userAccount.isSignedIn,
                dense: true,
                title: Text('Edit/share Current Inventory'),
                onTap: () {
                  Navigator.popUntil(context, ModalRoute.withName('/'));
                  _repo.getInventoryDetailFuture(userAccount.currentInventoryId).then((toEdit) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(toEdit)));
                  });
                },
              ),
              ListTile(
                enabled: true,
                dense: true,
                title: Text('Logs'),
                onTap: () {
                  Navigator.popUntil(context, ModalRoute.withName('/'));
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LoggingPage()));
                }
              )
            ],
          ),
          ListTile(
            title: Text('All Items'),
            onTap: () {
              Navigator.popUntil(context, ModalRoute.withName('/'));
              Navigator.push(context, MaterialPageRoute(builder: (context) => AllItemsPage()));
              Future.delayed(Duration(milliseconds: 300), () {
                _bloc.actionSink(Action(Act.SelectAll, true));
              });
            },
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: userAccount.knownInventories?.length ?? 0,
            itemBuilder: (context, index) {
              return StreamBuilder<InventoryDetails>(
                stream: _repo.getInventoryDetailObservable(userAccount.knownInventories[index]),
                initialData: InventoryDetails(uuid: userAccount.knownInventories[index], name: 'Inventory $index')
                  ..currentCount = 0
                  ..isSelected = false,
                builder: (context, snap) {
                  return ListTile(
                    title: Text('${snap.data?.name ?? 'Inventory $index'}'),
                    subtitle: Text('${snap.data?.currentCount ?? 0} items'),
                    selected: snap.data?.isSelected ?? false,
                    onTap: () {
                      Navigator.popUntil(context, ModalRoute.withName('/'));
                      Future.delayed(Duration(milliseconds: 300), () {
                        _bloc.actionSink(Action(Act.ChangeInventory, snap.data.uuid));
                      });
                    },
                  );
                },
              );
            }
          )
        ],
      ),
    );
  }
}
