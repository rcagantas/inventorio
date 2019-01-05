import 'package:flutter/material.dart';
import 'package:qr_mobile_vision/qr_camera.dart';

class ScanPage extends StatefulWidget {
  @override _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String detectedCode;

  void _onDetection(BuildContext context, String code) {
    // prevent multiple detections
    if (detectedCode == null) {
      this.detectedCode = code;
      print('Popping code $code');
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Barcode'),),
      body: ListView(
        children: <Widget>[
          Container(
            height: 300.0,
            padding: EdgeInsets.all(8.0),
            child: QrCamera(qrCodeCallback: (code) { _onDetection(context, code); })
          ),
          ListTile(title: Text('Center Barcode/QR in Window', textAlign: TextAlign.center,)),
        ],
      ),
    );
  }
}
