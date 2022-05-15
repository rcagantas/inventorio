import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_mobile_vision/qr_camera.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();

  static Future<bool> checkCameraPermission(BuildContext context) async {
    if (!await Permission.camera.request().isGranted) {
      final okCancel = await showOkCancelAlertDialog(
          context: context,
          title: 'Permission Required',
          message: 'Scanning barcode requires camera access'
      );
      if (okCancel == OkCancelResult.ok) await openAppSettings();
      return false;
    }
    return true;
  }
}

class _ScanPageState extends State<ScanPage> {
  String? detectedCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Barcode'),),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return QrCamera(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Opacity(
                  opacity: .5,
                  child: Container(
                    height: constraints.maxHeight / 6.0,
                    decoration: BoxDecoration(color: Colors.black),
                  ),
                ),
                Opacity(
                  opacity: .5,
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Scan QR / barcode',
                        style: Theme.of(context).textTheme.headline6,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    height: constraints.maxHeight / 3,
                    decoration: BoxDecoration(color: Colors.black,),
                  ),
                ),
              ],
            ),
            qrCodeCallback: (code) {
              /**
               * IMPORTANT! this callback gets called *multiple times* for a single bar code.
               * This is why this needs to be a stateful widget.
               */
              if (detectedCode == null && code != null) {
                setState(() {
                  detectedCode = code;
                  Navigator.pop(context, code);
                });
              }
            },
            notStartedBuilder: (context) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8.0,),
                  Text('Loading camera', textAlign: TextAlign.center,),
                ],
              )
            ),
          );
        },
      ),
    );
  }
}
