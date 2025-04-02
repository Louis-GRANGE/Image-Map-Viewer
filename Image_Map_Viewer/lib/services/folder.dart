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

  void _showPopup(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Image.memory(imageBytes),
      ),
    );
  }

  Future<void> loadImages(BuildContext context, Function(ImageMarker) onMarkerAdded, Function() onStartLoading, Function(List<Map<String, dynamic>>) onImagesFound, Function(int) onEndLoading) async {
    onStartLoading();
    List<Map<String, dynamic>> images = await ImagePickerService.getAllImagesFromFolder(path);
    LatLng? firstLatLng;
    int NbImageAdd = 0;

    onImagesFound(images);

    for (var image in images) {
      final imageData = image['data'] as Uint8List;
      final latLng = await ExifService.getCoordinatesFromImage(imageData);

      if (latLng != null && latLng != LatLng(0, 0) && image['timestamp'] != null && image['timestamp'] != DateTime(0)) {
        final marker = await MarkerHelper.createMarker(
          context,
          LatLng(latLng.latitude, latLng.longitude),
          imageData,
          _showPopup,
        );

        NbImageAdd++;

        ImageMarker imgMarker = ImageMarker(marker: marker, image: ImageData.fromMap(image));

        markers.add(imgMarker);

        onMarkerAdded(imgMarker);  // Appel du callback pour ajouter le marqueur

        firstLatLng ??= latLng;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    onEndLoading(NbImageAdd);
  }
}