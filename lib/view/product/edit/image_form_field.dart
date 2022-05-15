
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/view/product/product_image.dart';
import 'package:path_provider/path_provider.dart';

enum CompressionStatus {
  NOT_STARTED,
  IN_PROGRESS,
  DONE
}

class ImageFormField extends StatefulWidget {
  final Item item;
  final Function(CompressionStatus, File?) onChanged;

  const ImageFormField({
    Key? key,
    required this.item,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ImageFormField> createState() => _ImageFormFieldState();
}

class _ImageFormFieldState extends State<ImageFormField> {

  File? imageFile;
  CompressionStatus compressionStatus = CompressionStatus.NOT_STARTED;
  final ImagePicker imagePicker = ImagePicker();

  Future<File?> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${widget.item.inventoryId}_${widget.item.code}.jpg';
    return await FlutterImageCompress.compressAndGetFile(file.path, targetPath, quality: 80);
  }

  Future<void> pickAndCompressImage() async {
    final pickedImage = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        compressionStatus = CompressionStatus.IN_PROGRESS;
        imageFile = null;
        widget.onChanged(compressionStatus, imageFile);
        print('image file is null');
      });

      print('picked image ${pickedImage.path}');
      File? f = await compressImage(File(pickedImage.path));

      setState(() {
        if (f != null) {
          imageFile = f;
          print('image file ${imageFile!.path}');
          compressionStatus = CompressionStatus.DONE;
          widget.onChanged(compressionStatus, imageFile);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SizedBox.square(
      dimension: 350 * media.textScaleFactor,
      child: Stack(
        children: [
          Positioned.fill(child: ProductImage(item: widget.item, imageScale: 1.0,)),
          Positioned.fill(child: InkWell(onTap: pickAndCompressImage,)),
          Positioned(bottom: 8.0, left: 8.0, child: Icon(Icons.camera_alt)),
          Positioned.fill(child: Visibility(
            visible: compressionStatus == CompressionStatus.IN_PROGRESS,
            child: Center(child: CircularProgressIndicator(),),
          ))
        ],
      ),
    );
  }
}
