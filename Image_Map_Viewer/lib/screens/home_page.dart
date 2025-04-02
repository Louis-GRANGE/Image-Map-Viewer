import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // flutter_map package
import '../services/ImageMarker.dart';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map
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
  List<ImageMarker> markers = []; // List of Folder objects
  List<Polyline> polylines = [];
  int totalImages = 0;
  LatLng mapCenter = LatLng(0, 0); // Default map center
  bool isLoading = false; // Track loading state
  
  // Liste pour stocker les chemins des images et informations pour le débogage
  List<String> debugInfo = [];
  
  // Slider values for range
  RangeValues _currentRangeValues = RangeValues(20, 80);
  
  // To store the minimum and maximum slider values based on dates
  double minSliderValue = 0.0;
  double maxSliderValue = 100.0;
  
  // Function to find the minimum and maximum timestamps for the images
  void _updateSliderRange() {
    if (markers.isEmpty) return;

    // Find the earliest and latest timestamps in markers
    DateTime earliestDate = markers.first.image.timestamp!;
    DateTime latestDate = markers.first.image.timestamp!;

    for (var marker in markers) {
      if (marker.image.timestamp!.isBefore(earliestDate)) {
        earliestDate = marker.image.timestamp!;
      }
      if (marker.image.timestamp!.isAfter(latestDate)) {
        latestDate = marker.image.timestamp!;
      }
    }

    // Convert DateTime to Unix timestamp (milliseconds)
    minSliderValue = earliestDate.millisecondsSinceEpoch.toDouble();
    maxSliderValue = latestDate.millisecondsSinceEpoch.toDouble();

    // Set initial slider values based on the dates
    _currentRangeValues = RangeValues(
      minSliderValue,
      minSliderValue + (maxSliderValue - minSliderValue) * 0.5, // Example: set default end to mid-range
    );
  }

void _filterMarkersByDate() {
  markers = folderList
      .where((folder) => folder.isSelected) // Garder seulement les dossiers sélectionnés
      .expand((folder) => folder.markers) // Extraire les marqueurs
      .where((marker) {
        DateTime? date = marker.image.timestamp;
        if (date == null) return false;

        double timestamp = date.millisecondsSinceEpoch.toDouble();
        return timestamp >= _currentRangeValues.start && timestamp <= _currentRangeValues.end;
      })
      .toList();

    sortMarkersByDate();

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
      folderList.last.loadImages(context,
      (marker) {
        setState(() {
          markers.add(marker);
          totalImages = markers.length;
          debugInfo.add('Image found: ${marker.image.name}');
        });
      }, () {
        setState(() {
          isLoading = true;
        });
      },  () {
        setState(() {
          isLoading = false;
          sortMarkersByDate();
          _updateSliderRange();
          drawLinesBetweenMarkers(); // Redraw lines after sorting
        });
      });
    }
  }

  void sortMarkersByDate() {
    markers.sort((a, b) {
      DateTime? dateA = a.image.timestamp;
      DateTime? dateB = b.image.timestamp;

      // Handle null timestamps
      if (dateA == null && dateB == null) return 0; // Both are null, so they are equal
      if (dateA == null) return 1; // Null should be treated as the latest/earliest
      if (dateB == null) return -1;

      // Compare valid timestamps
      return dateA.compareTo(dateB);
    });
  }

  void drawLinesBetweenMarkers() {
    // Clear existing polylines before redrawing
    polylines.clear(); 
      
    for (var i = 0; i < markers.length - 1; i++) {
      addPolyline(markers[i].marker.point, markers[i + 1].marker.point);
    }
  }

  void addPolyline(LatLng start, LatLng end) {
    setState(() {
      polylines.add(Polyline(points: [start, end], strokeWidth: 4.0, color: Colors.red));
    });
  }

  void _removeFolder(Folder folder) {
    setState(() {
      folderList.remove(folder); // Remove folder from list
      // Retirer les marqueurs associés au dossier de la liste principale des marqueurs
      markers = markers.where((marker) => !folder.markers.contains(marker)).toList();
      totalImages = markers.length;
      drawLinesBetweenMarkers();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      folderList[index].isSelected = !folderList[index].isSelected;

      // Met à jour la liste des marqueurs affichés en fonction des dossiers sélectionnés
      markers = folderList
          .where((folder) => folder.isSelected)
          .expand((folder) => folder.markers)
          .toList();

      // Appeler la fonction pour trier les marqueurs après avoir mis à jour la liste
      sortMarkersByDate();
      _updateSliderRange();
      drawLinesBetweenMarkers(); // Redraw lines after sorting

      // Met à jour le nombre total d'images affichées
      totalImages = markers.length;
    });
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
                      Text('Total Images: $totalImages', style: const TextStyle(fontSize: 16, color: Colors.black)),
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
                      MarkerLayer(
                        markers: markers.map((imageMarker) => imageMarker.marker).toList(),
                      ),
                      PolylineLayer(polylines: polylines),
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
