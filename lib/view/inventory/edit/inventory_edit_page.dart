import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/meta.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';
import 'package:inventorio/view/product/edit/form_validator.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InventoryEditPage extends ConsumerStatefulWidget {
  const InventoryEditPage({Key? key}) : super(key: key);

  @override
  ConsumerState<InventoryEditPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryEditPage> {
  static const MAX_LEN = 60;
  static const TOO_LONG = 'Text is too long';

  final _formKey = GlobalKey<FormState>();

  MetaBuilder metaBuilder = MetaBuilder();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final meta = ModalRoute.of(context)?.settings.arguments as Meta;
    if (metaBuilder.uuid == null) {
      setState(() => metaBuilder = MetaBuilder.fromMeta(meta));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Edit'),),
      floatingActionButton: Visibility(
        visible: _formKey.currentState?.validate() ?? true,
        child: FloatingActionButton(
          child: Icon(Icons.save_alt),
          onPressed: () {
            ref.read(actionSinkProvider).updateMeta(metaBuilder.build());
            Navigator.pop(context);
          },
        ),
      ),
      body: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          Center(
            child: QrImage(
              padding: EdgeInsets.all(24.0),
              data: metaBuilder.uuid!,
              foregroundColor: Theme.of(context).primaryTextTheme.bodyText1?.color,
              size: media.size.height / 3,
            ),
          ),
          Text('${metaBuilder.uuid}'),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: TextFormField(
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: 'Name'),
                initialValue: metaBuilder.name,
                textCapitalization: TextCapitalization.words,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textInputAction: TextInputAction.next,
                validator: FormValidator.buildValidator([
                  FormValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                ]),
                onChanged: (v) {
                  setState(() { metaBuilder.name = v; });
                },
              ),
            ),
          ),
          Visibility(
            visible: ref.watch(userProvider).knownInventories?.contains(metaBuilder.uuid) ?? false,
            child: OutlinedButton(
              child: Text('Unsubscribe'),
              onPressed: () async {
                final result = await showOkCancelAlertDialog(
                  context: context,
                  title: 'Unsubscribe',
                  message: 'This action would remove this inventory and all its items from your list',
                  okLabel: 'Unsubscribe'
                );
                if (result == OkCancelResult.ok) {
                  ref.read(actionSinkProvider).unsubscribeFrom(metaBuilder.uuid!);
                  Navigator.pop(context);
                }
              },
            ),
          )
        ],
      ),
    );
  }
}
