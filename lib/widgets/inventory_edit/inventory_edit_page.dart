import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InventoryEditPage extends StatefulWidget {
  static const ROUTE = '/editInventory';

  @override
  _InventoryEditPageState createState() => _InventoryEditPageState();
}

class _InventoryEditPageState extends State<InventoryEditPage> {
  InvMetaBuilder invMetaBuilder;
  String _inventoryName;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    invMetaBuilder = ModalRoute.of(context).settings.arguments;

    var media = MediaQuery.of(context);
    var smaller = media.size.width > media.size.height
        ? media.size.height
        : media.size.width;
    smaller /= 2.2;

    return Consumer<InvState>(
      builder: (context, invState, child) => Scaffold(
        appBar: AppBar(title: Text('Edit Inventory'),),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.cloud_upload),
          onPressed: () async {

            if (_formKey.currentState.validate()) {
                invMetaBuilder.name = _inventoryName;
                await invState.updateInvMeta(invMetaBuilder);
                Navigator.pop(context);
            }

          },
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(

            children: <Widget>[
              Form(
                key: _formKey,
                child: TextFormField(
                  initialValue: invMetaBuilder.name ?? 'Inventory',
                  textCapitalization: TextCapitalization.words,
                  style: Theme.of(context).textTheme.headline6,
                  textAlign: TextAlign.center,
                  onChanged: (value) => setState(() {
                      _inventoryName = value;
                  }),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: QrImage(
                    foregroundColor: Theme.of(context).primaryTextTheme.bodyText1.color,
                    data: invMetaBuilder.uuid,
                    size: smaller,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('${invMetaBuilder.uuid}',
                  style: Theme.of(context).textTheme.caption,
                  textAlign: TextAlign.center,
                ),
              ),
              Visibility(
                visible: invState.invUser.knownInventories.contains(invMetaBuilder.uuid),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    OutlinedButton(
                      child: Text('Unsubscribe'),
                      onPressed: () async {
                        var result = await showOkCancelAlertDialog(
                          context: context,
                          title: 'Unsubscribe',
                          message: 'This action would remove this inventory and all its items from your list',
                          okLabel: 'Unsubscribe'
                        );

                        if (result == OkCancelResult.ok) {
                          invState.unsubscribeFromInventory(invState.selectedInvMeta().uuid);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
