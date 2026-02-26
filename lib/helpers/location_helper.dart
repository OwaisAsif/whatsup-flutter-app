import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsup/constants/api_keys.dart';

void _openLocation(double lat, double lng) async {
  final googleMapsUrl =
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
  final uri = Uri.parse(googleMapsUrl);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    print("Could not launch Google Maps");
  }
}

Widget buildLocationMessage(double? lat, double? lng) {
  if (lat == null || lng == null) {
    // Return a placeholder if coordinates are missing
    return Container(
      width: 220,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.location_off, color: Colors.red, size: 40),
      ),
    );
  }

  final staticMapUrl =
      "https://maps.googleapis.com/maps/api/staticmap"
      "?center=$lat,$lng"
      "&zoom=15"
      "&size=400x200"
      "&markers=color:red%7C$lat,$lng"
      "&key=${ApiKeys.kGoogleMapsApiKey}";

  return GestureDetector(
    onTap: () => _openLocation(lat, lng),
    child: Container(
      width: 220,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(staticMapUrl),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}
