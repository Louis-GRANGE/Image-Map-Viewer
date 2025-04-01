import 'dart:typed_data';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map

class ImageData {
  final Uint8List data;
  final String path;
  final String name;
  final DateTime? timestamp;
  final LatLng? location;

  ImageData({
    required this.data,
    required this.path,
    required this.name,
    this.timestamp,
    this.location,
  });

  /// Factory constructor to create an ImageData object from a Map
  factory ImageData.fromMap(Map<String, dynamic> map) {
    return ImageData(
      data: map['data'] as Uint8List,
      path: map['path'] as String,
      name: map['name'] as String,
      timestamp: map['timestamp'],
      location: map['location'] != null ? map['location'] as LatLng : null,
    );
  }

  /// Convert ImageData to a Map
  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'path': path,
      'name': name,
      'timestamp': timestamp?.toIso8601String(),
      'location': location,
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
