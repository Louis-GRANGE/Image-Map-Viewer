import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // flutter_map package
import 'package:latlong2/latlong.dart';

import '../services/ImageMarker.dart'; // For LatLng in flutter_map

class MarkerHelper {
  // Method to create a custom marker as a Widget for flutter_map
  static Future<Widget> createCustomMarkerIcon(Uint8List imageBytes) async {
    const int size = 50;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..isAntiAlias = true;

    // Draw a white circle as the marker background
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // Decode the image bytes and draw the image on top of the circle
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: size,
      targetHeight: size,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    paint.blendMode = BlendMode.srcATop;
    canvas.drawImage(image, const Offset(0, 0), paint);

    // Generate the final image
    final ui.Image finalImage = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List finalMarkerBytes = byteData!.buffer.asUint8List();

    // Return a widget that displays the custom marker image
    return Image.memory(finalMarkerBytes);
  }

  // Method to create a marker for flutter_map
  static Future<Marker> createMarker(BuildContext context, LatLng position, Uint8List imageBytes, Function(BuildContext, Uint8List) showPopup) async {
    final customIconWidget = await createCustomMarkerIcon(imageBytes);

    return Marker(
      width: 50, // Largeur du marker
      height: 50, // Hauteur du marker
      point: position,
      child: GestureDetector(
        onTap: () {
          // Afficher une popup lorsque le marker est cliqué
          showPopup(context, imageBytes);
        },
        child: customIconWidget, // Affichage de l'icône personnalisée du marker
      ),
    );
  }

  static void sortMarkersByDate(List<ImageMarker> listImageMarker) {
  listImageMarker.sort((a, b) {
    DateTime? dateA = a.image.timestamp;
    DateTime? dateB = b.image.timestamp;

    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1; 
    if (dateB == null) return -1; 

    return dateA.compareTo(dateB);
  });
}
}
