import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_mobile_vision/qr_camera.dart';

class ScanPage extends StatefulWidget {

  static const ROUTE = '/scanBarcode';

  static Future<bool> hasPermissions(BuildContext context) async {
    if (!await Permission.camera.request().isGranted) {
      var okCancel = await showOkCancelAlertDialog(
          context: context,
          title: 'Permission Required',
          message: 'Scanning barcode requires camera access.'
      );

      if (okCancel == OkCancelResult.ok) {
        await openAppSettings();
      }

      return false;
    }

    return true;
  }

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {

  String _detectedCode;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Barcode'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: QrCamera(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Opacity(
                    opacity: .5,
                    child: Container(
                      height: constraints.maxHeight / 6.5,
                      decoration: BoxDecoration(
                        color: Colors.black
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: .5,
                    child: Container(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Center QR / barcode',
                          style: Theme.of(context).textTheme.headline6,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      height: constraints.maxHeight / 3,
                      decoration: BoxDecoration(
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              qrCodeCallback: (code) {
                if (_detectedCode == null) {
                  _detectedCode = code;
                  Navigator.pop(context, code);
                }
              },
              notStartedBuilder: (context) => Center(
                  child: SizedBox(
                      height: 50.0,
                      width: 50.0,
                      child: Image.asset('resources/icons/icon_transparent.png', fit: BoxFit.cover,)
                  )
              ),
            ),
          );
        },
      ),
    );
  }
}
