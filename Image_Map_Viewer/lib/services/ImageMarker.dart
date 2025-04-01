import 'package:flutter_map/flutter_map.dart';
import '../services/ImageData.dart'; // flutter_map package

class ImageMarker {
  final Marker marker;      // The actual marker on the map
  final ImageData image; // Timestamp of the image (non-nullable)

  // Constructor: if timestamp is null, use the current time as a default
  ImageMarker({required this.marker, required this.image});
}