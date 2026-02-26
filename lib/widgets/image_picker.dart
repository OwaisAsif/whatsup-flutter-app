import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whatsup/helpers/image_picker_helper.dart';

class ImagePickerWidget extends StatefulWidget {
  const ImagePickerWidget({super.key, required this.onPickImage});

  final void Function(File image) onPickImage;

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  File? _pickedImage;
  void _pickImage() async {
    final selectedImage = await pickImage(context);
    if (selectedImage != null) {
      setState(() {
        _pickedImage = selectedImage;
      });
      widget.onPickImage(_pickedImage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey,
            foregroundImage: _pickedImage != null
                ? FileImage(_pickedImage!)
                : null,
            radius: 40,
          ),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image),
            label: const Text("Add Image"),
          ),
        ],
      ),
    );
  }
}
