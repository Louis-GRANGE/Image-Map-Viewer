import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // flutter_map package
import '../services/ImageMarker.dart';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:file_picker/file_picker.dart';
import '../services/folder.dart';
import 'package:intl/intl.dart'; // Make sure this import is at the top

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Folder> folderList = []; // List of Folder objects
  List<ImageMarker> allMarkers = []; // Contient TOUS les marqueurs
  List<ImageMarker> filteredMarkers = []; // Contient les marqueurs affichés après filtrage

  List<Polyline> polylines = [];
  int totalImages = 0;
  int totalImagesFound = 0;
  LatLng mapCenter = LatLng(0, 0); // Default map center
  bool isLoading = false; // Track loading state

    
  // To store the currently selected image
  ImageMarker? selectedImageMarker;
  
  // Liste pour stocker les chemins des images et informations pour le débogage
  List<String> debugInfo = [];
  
  // Slider values for range
  RangeValues _currentRangeValues = RangeValues(20, 80);
  
  // To store the minimum and maximum slider values based on dates
  double minSliderValue = 0.0;
  double maxSliderValue = 100.0;
  
  // Function to find the minimum and maximum timestamps for the images
void _updateSliderRange() {
  if (allMarkers.isEmpty) return; // Utilisation des marqueurs filtrés

  // Filtrer les marqueurs ayant un timestamp non null
  List<DateTime> timestamps = allMarkers
      .map((marker) => marker.image.timestamp)
      .whereType<DateTime>() // Supprime les valeurs nulles
      .toList();

  if (timestamps.isEmpty) return; // Aucun timestamp valide

  // Trouver la date la plus ancienne et la plus récente
  DateTime earliestDate = timestamps.reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime latestDate = timestamps.reduce((a, b) => a.isAfter(b) ? a : b);

  // Convertir en timestamp Unix (ms)
  minSliderValue = earliestDate.millisecondsSinceEpoch.toDouble();
  maxSliderValue = latestDate.millisecondsSinceEpoch.toDouble();

  // Définir une valeur par défaut pour le slider
  _currentRangeValues = RangeValues(minSliderValue,maxSliderValue);
}

void _filterMarkersByDate() {
  filteredMarkers = allMarkers
    .where((marker) {
      DateTime? date = marker.image.timestamp;
      if (date == null) return false;
      double timestamp = date.millisecondsSinceEpoch.toDouble();
      return timestamp >= _currentRangeValues.start && timestamp <= _currentRangeValues.end;
    })
    .toList();

    sortMarkersByDate(filteredMarkers);

    drawLinesBetweenMarkers(); // Redessiner les lignes dans le bon ordre
  }

  Future<void> _pickFolder() async {
    String? selectedFolder = await FilePicker.platform.getDirectoryPath();
    if (selectedFolder != null && !folderList.any((folder) => folder.path == selectedFolder)) {
      setState(() {
        folderList.add(Folder(
          path: selectedFolder,
          isSelected: true,
          onMarkersUpdated: () {
            setState(() {});
          },
        ));
      });

      // Charger les images après l'ajout du dossier
      folderList.last.loadImages(context, (marker) {
        setState(() {
          allMarkers.add(marker);  // Ajouter aux marqueurs globaux
          filteredMarkers.add(marker);  // Ajouter aux marqueurs affichés (au début identique)
          totalImages = allMarkers.length;
          _updateSliderRange();
          
          debugInfo.add("Image Found : " + marker.image.name);
        });
      }, () {
        setState(() {
          isLoading = true;
        });
      }, (imagesFound) {
        setState(() {
          totalImagesFound = totalImagesFound + imagesFound.length;
        });
      }, (NbImageAdd) {
        setState(() {
          isLoading = false;
          sortMarkersByDate(filteredMarkers);
          _updateSliderRange();
          drawLinesBetweenMarkers(); 
          
          debugInfo.add("$NbImageAdd images processed");
        });
      });
    }
  }

 void sortMarkersByDate(List<ImageMarker> listImageMarker) {
  listImageMarker.sort((a, b) {
    DateTime? dateA = a.image.timestamp;
    DateTime? dateB = b.image.timestamp;

    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1; 
    if (dateB == null) return -1; 

    return dateA.compareTo(dateB);
  });

  // Mettre à jour les marqueurs affichés après le tri
  //_filterMarkersByDate();
}

void drawLinesBetweenMarkers() {
  setState(() {
    polylines.clear(); 
    for (var i = 0; i < filteredMarkers.length - 1; i++) {
      addPolyline(filteredMarkers[i].marker.point, filteredMarkers[i + 1].marker.point);
    }
  });
}

void addPolyline(LatLng start, LatLng end) {
  setState(() {
    polylines.add(Polyline(points: [start, end], strokeWidth: 4.0, color: Colors.red));
  });
}

void _removeFolder(Folder folder) {
  setState(() {
    folderList.remove(folder); 
    allMarkers = allMarkers.where((marker) => !folder.markers.contains(marker)).toList();
    totalImages = allMarkers.length;

    // Mettre à jour les marqueurs affichés après suppression
    _filterMarkersByDate();
    drawLinesBetweenMarkers();
  });
}

void _toggleSelection(int index) {
  setState(() {
    folderList[index].isSelected = !folderList[index].isSelected;

    // Recalcule allMarkers avec seulement les dossiers sélectionnés
    allMarkers = folderList
        .where((folder) => folder.isSelected)
        .expand((folder) => folder.markers)
        .toList();

    _updateSliderRange();
    _filterMarkersByDate();

    totalImages = allMarkers.length;
  });
}

  // Show image gallery in a popup
  void _showImageGallery(List<ImageMarker> imageMarkers) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Container(
            width: 600,
            height: 400,
            child: Row(
              children: [
                // List of images on the left side
                Container(
                  width: 150,
                  child: ListView.builder(
                    itemCount: imageMarkers.length,
                    itemBuilder: (context, index) {
                      final imageMarker = imageMarkers[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedImageMarker = imageMarker;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Image.memory(
                            imageMarker.image.data,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Large preview of selected image on the right side
                Expanded(
                  child: selectedImageMarker == null
                      ? Center(child: Text('Select an image'))
                      : Image.memory(
                          selectedImageMarker!.image.data,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Folder management panel
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.grey[200],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: isLoading ? null : _pickFolder,
                        child: const Text('Add Folder'),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: folderList.length,
                          itemBuilder: (context, index) {
                            final folder = folderList[index];
                            return GestureDetector(
                              onTap: isLoading ? null : () => _toggleSelection(index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: folder.isSelected
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: folder.isSelected ? Colors.green : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(folder.path),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: isLoading ? Colors.grey : Colors.red,
                                      ),
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              _removeFolder(folder);
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: LinearProgressIndicator(),
                        ),
Tooltip(
  message: "The total images found and displayed in the app depend on\nwhether they have the necessary metadata to be processed.",
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.image, color: Colors.blueAccent, size: 15),
          SizedBox(width: 8),
          Text(
            "Images Visibles: ${filteredMarkers.length}",
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.7)),
          ),
        ],
      ),
      SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.filter_list, color: Colors.blueAccent, size: 15),
          SizedBox(width: 8),
          Text(
            "Images Processed: ${allMarkers.length}",
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.7)),
          ),
        ],
      ),
      SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.visibility_off, color: Colors.blueAccent, size: 15),
          SizedBox(width: 8),
          Text(
            "Images Unprocessed: ${(totalImagesFound - allMarkers.length)}",
            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.7)),
          ),
        ],
      ),
    ],
  ),
)

                    ],
                  ),
                ),
                // Map view
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      center: mapCenter,
                      zoom: 2.0,
                      minZoom: 2.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c'],
                      ),
                      PolylineLayer(polylines: polylines),
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 50,
                          size: const Size(40, 40),
                          fitBoundsOptions: FitBoundsOptions(padding: EdgeInsets.all(50)),
                          markers: filteredMarkers.map((imageMarker) => imageMarker.marker).toList(), // Utilise filteredMarkers
                          builder: (context, markers) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.blue.withOpacity(0.8),
                              ),
                              child: Center(
                                child: Text(
                                  markers.length.toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Vertical range slider
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: RangeSlider(
                      values: _currentRangeValues,
                      min: minSliderValue,
                      max: maxSliderValue,
                      divisions: 100,
                      labels: RangeLabels(
                        DateFormat('yyyy-MM-dd').format(
                          DateTime.fromMillisecondsSinceEpoch(_currentRangeValues.start.round().toInt())
                        ),
                        DateFormat('yyyy-MM-dd').format(
                          DateTime.fromMillisecondsSinceEpoch(_currentRangeValues.end.round().toInt())
                        ),
                      ),

                      onChanged: (RangeValues values) {
                        setState(() {
                          _currentRangeValues = values;
                          _filterMarkersByDate();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Debug info
          Container(
            padding: const EdgeInsets.all(0),
            color: Colors.white,
            child: Text(
              debugInfo.isNotEmpty ? debugInfo.last : "",
              style: const TextStyle(color: Colors.black, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
