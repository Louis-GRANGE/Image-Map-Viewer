import 'dart:typed_data';
import 'package:flutter/material.dart';
// flutter_map package
import '../services/ImageData.dart';
import '../services/ImageMarker.dart';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map

import '../helpers/marker_helper.dart';
import '../services/exif_service.dart';
import '../services/image_picker_service.dart';

class Folder {
  String path;
  List<ImageMarker> markers = [];
  bool isSelected;
  final Function() onMarkersUpdated;

  Folder({
    required this.path,
    this.isSelected = false,
    required this.onMarkersUpdated,
  });

  void _showPopup(BuildContext context, ImageData imageData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.memory(
                imageData!.data,
                fit: BoxFit.scaleDown,
              ),
            ),
            SizedBox(height: 8),
            Text(
              imageData!.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadImages(BuildContext context, Function(ImageMarker) onMarkerAdded, Function() onStartLoading, Function(List<Map<String, dynamic>>) onAllImagesFound, Function(List<ImageMarker>) onEndLoading) async {
    onStartLoading();
    List<ImageMarker> NewsMarkerAdded = [];
    List<Map<String, dynamic>> images = await ImagePickerService.getAllImagesFromFolder(path);
    LatLng? firstLatLng;

    onAllImagesFound(images);

    for (var image in images) {
      final imageData = image['data'] as Uint8List;
      final latLng = await ExifService.getCoordinatesFromImage(imageData);

      if (latLng != null && latLng != LatLng(0, 0) && image['timestamp'] != null && image['timestamp'] != DateTime(0)) {
        ImageData imgdt = ImageData.fromMap(image);
        final marker = await MarkerHelper.createMarker(
          context,
          LatLng(latLng.latitude, latLng.longitude),
          imgdt,
          (ctx, imgdt) => _showPopup(ctx, imgdt),
        );

        ImageMarker imgMarker = ImageMarker(marker: marker, image: imgdt);

        markers.add(imgMarker);
        NewsMarkerAdded.add(imgMarker);

        onMarkerAdded(imgMarker);  // Appel du callback pour ajouter le marqueur

        firstLatLng ??= latLng;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    onEndLoading(NewsMarkerAdded);
  }
}