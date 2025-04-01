import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // flutter_map package
import '../services/ImageMarker.dart';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map
import 'package:file_picker/file_picker.dart';
import '../services/folder.dart';

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
        });
      });
    }
  }

void sortMarkersByDate() {
  setState(() {
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

    drawLinesBetweenMarkers(); // Redraw lines after sorting
  });
}


  void drawLinesBetweenMarkers() {
    setState(() {
      // Clear existing polylines before redrawing
      polylines.clear(); 
      
      for (var i = 0; i < markers.length - 1; i++) {
        addPolyline(markers[i].marker.point, markers[i + 1].marker.point);
      }
    });
  }

  void addPolyline(LatLng start, LatLng end)
  {
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
    });
    drawLinesBetweenMarkers();
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
                // Vertical panel for folder management on the left
                Container(
                  width: 300, // Adjust the width for the panel
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.grey[200], // Light background color for the panel
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed:  isLoading ? null : _pickFolder, // Disable the button when loading is true,
                        child: const Text('Add Folder'),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: folderList.length,
                          itemBuilder: (context, index) {
                            final folder = folderList[index];
                            return GestureDetector(
                              onTap:  isLoading ? null : () => _toggleSelection(index), // Disable folder selection while loading
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: folder.isSelected
                                      ? Colors.green.withOpacity(0.2) // Green background when selected
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: folder.isSelected ? Colors.green : Colors.transparent,
                                    width: 2, // Border width
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(folder.path),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: isLoading ? Colors.grey : Colors.red, // Change color based on loading state
                                      ),
                                      onPressed: isLoading
                                          ? null  // Disable the button if loading is true
                                          : () {
                                              _removeFolder(folder); // Remove folder when delete icon is pressed
                                            },
                                      splashColor: Colors.transparent, // Remove splash effect when disabled
                                      highlightColor: Colors.transparent, // Remove highlight effect when disabled
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
                          child: LinearProgressIndicator(), // Show loading bar when processing
                        ),
                      Text('Total Images: $totalImages', style: const TextStyle(fontSize: 16, color: Colors.black)),
                    ],
                  ),
                ),
                // Expanded widget for the map on the right
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      center: mapCenter, // Update map center dynamically
                      zoom: 2.0,
                      minZoom: 2.0, // Minimum zoom level
                      maxZoom: 18.0, // Maximum zoom level (adjust according to your need)
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c'],
                      ),MarkerLayer(
                        markers: markers.map((imageMarker) => imageMarker.marker).toList(),
                      ),
                      PolylineLayer(polylines: polylines)
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Small debug info display at the bottom
          Container(
            padding: const EdgeInsets.all(0),
            color: Colors.white,
            child: Text(
              debugInfo.isNotEmpty ? debugInfo.last : "", // Affiche les informations de débogage
              style: const TextStyle(color: Colors.black, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
