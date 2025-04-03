import 'dart:typed_data';
import 'package:Image_Map_Viewer/services/CountryStayTracker.dart';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map

class ImageData {
  final Uint8List data;
  final String path;
  final String name;
  final DateTime timestamp;
  final LatLng location;
  final CountryInfo country;

  ImageData({
    required this.data,
    required this.path,
    required this.name,
    required this.timestamp,
    required this.location,
    required this.country,
  });

  /// Factory constructor to create an ImageData object from a Map
  factory ImageData.fromMap(Map<String, dynamic> map) {
    return ImageData(
      data: map['data'] as Uint8List,
      path: map['path'] as String,
      name: map['name'] as String,
      timestamp: map['timestamp'],
      location: map['location'],
      country: map['country'] ?? "",
    );
  }

  /// Convert ImageData to a Map
  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'path': path,
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'country': country,
    };
  }

  /// Parse timestamp from string
  static DateTime? parseTimestamp(String? timestamp) {
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp.replaceAll(":", "-").replaceAll(" ", "T"));
    } catch (e) {
      print("Error parsing timestamp: $timestamp");
      return null;
    }
  }
}
