import 'dart:io';
import 'dart:typed_data';

import 'package:Image_Map_Viewer/helpers/marker_helper.dart';

import '../services/exif_service.dart';
import 'package:path/path.dart' as path;
import 'CountryStayTracker.dart';

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
      if (isValidImage(imageData)) {
        final latLng = await ExifService.getCoordinatesFromImage(imageData);
        CountryInfo country = CountryInfo("Unknown", "??");
        if(latLng != null)
          country = CountryStayTracker.getCountryFromCoordinates(latLng);
        final timestamp = await ExifService.getDateFromImage(imageData); // Extract timestamp
        String imageName = file.uri.pathSegments.last; // Extract filename
        Map<String, dynamic> image = 
        {
          'data': imageData,
          'location': latLng,
          'country' : country,
          'timestamp': timestamp,
          'name': imageName,
          'path': file.path,
        };
        
        images.add(image);

        print('Image found: ${file.path}, Timestamp: $timestamp, Country: ${country.name}');
      }
      else
      {
        print('⛔ Skipped invalid image ${file.path}');
      }
    } catch (e) {
      print('Error loading image: ${file.path}, Error: $e');
    }
  }

  // Load a single image as bytes
  static Future<Uint8List> loadImageAsBytes(String filePath) async {
    final File imageFile = File(filePath);
    return await imageFile.readAsBytes(); 
  }

  static bool isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // PNG signature: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;

    // JPEG signature: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;

    return false;
  }
}
