import 'package:flutter/material.dart';

class ImageViewer extends StatelessWidget {
  final String imageUrl;

  const ImageViewer({super.key, required this.imageUrl});

  String cleanUrl(String url) {
    return url
        .replaceAll('NetworkImage("', '')
        .replaceAll('")', '')
        .replaceAll(', scale: 1.0', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background like WhatsApp
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: imageUrl, // Optional: for smooth transition
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.network(cleanUrl(imageUrl), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
