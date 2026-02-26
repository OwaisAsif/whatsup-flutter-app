import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:whatsup/constants/api_keys.dart';

/// Upload image to ImgBB
Future<String?> uploadImage(Uint8List imageBytes, String uid) async {
  const apiKey = ApiKeys.kImgBBApiKey; // Replace with your key
  final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');

  try {
    String base64Image = base64Encode(imageBytes);

    final response = await http.post(
      url,
      body: {'image': base64Image, 'name': uid},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final imageUrl = data['data']['url'] as String;

      return imageUrl;
    } else {
      print(response.body);
      return null;
    }
  } catch (e) {
    print('⚠️ Error uploading image: $e');
    return null;
  }
}
