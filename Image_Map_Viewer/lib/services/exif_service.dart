import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'package:latlong2/latlong.dart'; // Pour gérer les coordonnées

class ExifService {
  // Get GPS coordinates from image EXIF data
  static Future<LatLng?> getCoordinatesFromImage(Uint8List imageBytes) async {
    try {
      final Map<String?, IfdTag>? tags = await _readExif(imageBytes);
      if (tags != null) {
        final latitude = _convertExifGpsToDouble(tags['GPSLatitude'] ?? tags['GPS GPSLatitude']);
        final longitude = _convertExifGpsToDouble(tags['GPSLongitude'] ?? tags['GPS GPSLongitude']);
        final latRef = tags['GPSLatitudeRef']?.printable ?? tags['GPS GPSLatitudeRef']?.printable;
        final lonRef = tags['GPSLongitudeRef']?.printable ?? tags['GPS GPSLongitudeRef']?.printable;

        if (latitude != null && longitude != null) {
          double finalLatitude = latRef == 'S' ? -latitude : latitude;
          double finalLongitude = lonRef == 'W' ? -longitude : longitude;
          return LatLng(finalLatitude, finalLongitude);
        }
      }
    } catch (e) {
      print('Erreur lors de la lecture EXIF: $e');
    }
    return null;
  }

  // Extract timestamp (DateTime) from image EXIF data
  static Future<DateTime?> getDateFromImage(Uint8List imageBytes) async {
    final data = await readExifFromBytes(imageBytes);

    if (data == null) return null;

    // Extract timestamp string
    String? timestamp = data['EXIF DateTimeOriginal']?.toString();
    timestamp ??= data['EXIF DateTimeDigitized']?.toString();
    timestamp ??= data['Image DateTime']?.toString();

    if (timestamp == null) return null;

    try {
      // Convert "YYYY:MM:DD HH:MM:SS" → "YYYY-MM-DD HH:MM:SS"
      timestamp = timestamp.replaceRange(4, 5, "-").replaceRange(7, 8, "-");
      
      return DateTime.parse(timestamp);
    } catch (e) {
      print("Error parsing timestamp: $e");
      return null;
    }
  }

  // Read EXIF metadata from an image
  static Future<Map<String?, IfdTag>?> _readExif(Uint8List imageBytes) async {
    try {
      return await readExifFromBytes(imageBytes);
    } catch (e) {
      print('Erreur lors de la lecture des EXIF: $e');
      return null;
    }
  }

  // Convert EXIF GPS coordinate format to double
  static double? _convertExifGpsToDouble(IfdTag? gpsTag) {
    if (gpsTag == null || gpsTag.values == null || gpsTag.values!.isEmpty) {
      return null;
    }

    final values = gpsTag.values!;
    if (values.length >= 3) {
      double degrees = _ratioToDouble(values[0]);
      double minutes = _ratioToDouble(values[1]);
      double seconds = _ratioToDouble(values[2]);
      return degrees + (minutes / 60) + (seconds / 3600);
    }
    return null;
  }

  // Convert Ratio to double
  static double _ratioToDouble(dynamic value) {
    if (value is Ratio) {
      return value.numerator / value.denominator;
    } else if (value is int || value is double) {
      return value.toDouble();
    }
    throw Exception("Unsupported GPS format: ${value.runtimeType}");
  }
}
