import 'dart:io';
import 'dart:typed_data';
import '../services/exif_service.dart';
import 'package:path/path.dart' as path;

class ImagePickerService {
  // Retrieves all images from a folder (including subfolders) and extracts metadata
  static Future<List<Map<String, dynamic>>> getAllImagesFromFolder(String folderPath) async {
    List<Map<String, dynamic>> images = [];
    List<Future> imageFutures = []; // To hold all futures

    // Recursively process directories
    Future<void> processDirectory(Directory dir) async {
      await for (var file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          String extension = path.extension(file.path).toLowerCase();
          if (extension == '.jpg' || extension == '.jpeg' || extension == '.png') {
            imageFutures.add(_loadImage(file, images));  // Load image and metadata
          }
        }
      }
    }

    // Check if the directory exists
    Directory folder = Directory(folderPath);
    if (await folder.exists()) {
      print('Folder exists: $folderPath');
      await processDirectory(folder);
    } else {
      print('Folder does not exist: $folderPath');
    }

    // Wait for all image processing to complete
    await Future.wait(imageFutures);

    print('Total images found: ${images.length}');
    return images;
  }

  // Load a single image, extract metadata, and add it to the list
  static Future<void> _loadImage(File file, List<Map<String, dynamic>> images) async {
    try {
      Uint8List imageData = await file.readAsBytes();  // Read image as bytes
      final latLng = await ExifService.getCoordinatesFromImage(imageData);
      final timestamp = await ExifService.getDateFromImage(imageData); // Extract timestamp
      String imageName = file.uri.pathSegments.last; // Extract filename

      images.add({
        'data': imageData,
        'location': latLng,
        'timestamp': timestamp,
        'name': imageName,
        'path': file.path,
      });

      print('Image found: ${file.path}, Timestamp: $timestamp');
    } catch (e) {
      print('Error loading image: ${file.path}, Error: $e');
    }
  }

  // Load a single image as bytes
  static Future<Uint8List> loadImageAsBytes(String filePath) async {
    final File imageFile = File(filePath);
    return await imageFile.readAsBytes(); 
  }
}
