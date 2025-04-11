import 'package:Image_Map_Viewer/services/ConnectivityPlus.dart';
import 'package:Image_Map_Viewer/widget/CountryStayWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // flutter_map package
import '../helpers/marker_helper.dart';
import '../services/ImageMarker.dart';
import 'package:latlong2/latlong.dart'; // For LatLng in flutter_map
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:file_picker/file_picker.dart';
import '../services/CountryStayTracker.dart';
import '../services/folder.dart';

import '../widget/DateSliderFilter.dart'; // Make sure this import is at the top

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

  bool isOnline = true;

    
  // To store the currently selected image
  ImageMarker? selectedImageMarker;
  
  // Liste pour stocker les chemins des images et informations pour le débogage
  List<String> debugInfo = [];
  
  // Slider values for range
  RangeValues _currentRangeValues = RangeValues(20, 80);
  
  // To store the minimum and maximum slider values based on dates
  double minSliderValue = 0.0;
  double maxSliderValue = 100.0;

  List<CountryInfo> selectedCountries = [];

  // New variable to store the country stay durations
  Map<CountryInfo, int> countryStayDurations = {CountryInfo("France", "FR") : 1};

  @override
  void initState() {
    super.initState();
    
    // Charger les informations nécessaires au démarrage
    _initializeApp();
  }

  void _initializeApp() async {
    setState(() {
      isLoading = true;
    });

    // Charger les marqueurs, les fichiers GeoJSON, ou toute autre donnée requise
    await CountryStayTracker.loadGeoJson(); // Exemple de chargement
    isOnline = await ConnectivityPlus.hasInternetConnection();

    if (!isOnline)
    {
      print("🛑 No internet. Drawing all countries...");
    }
    else
    {
      print("✅ Internet available.");
    }
    _updateSliderRange();
    _updateFilters();

    setState(() {
      isLoading = false;
    });
  }

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

Map<CountryInfo, int> calculateStayDurations(List<ImageMarker> _markers)
{
  MarkerHelper.sortMarkersByDate(_markers);
  Map<CountryInfo, int> _countryStayDurations = {};

  for (var i = 0; i < _markers.length - 1; i++) {
    String country = _markers[i].image.country.name;
    String countryNext = _markers[i + 1].image.country.name;
    DateTime timestamp = _markers[i].image.timestamp;
    DateTime timestampNext = _markers[i + 1].image.timestamp;

    // Convertir les timestamps en date sans l'heure pour comparer uniquement les jours
    DateTime dateOnly = DateTime(timestamp.year, timestamp.month, timestamp.day);
    DateTime nextDateOnly = DateTime(timestampNext.year, timestampNext.month, timestampNext.day);

    int stayDuration = nextDateOnly.difference(dateOnly).inDays; 
    CountryInfo countryinfo = CountryInfo.withName(country);
    CountryInfo countryinfonext = CountryInfo.withName(countryNext);

    // Si le pays est different, on répartit la durée entre les deux pays
    if (countryNext != country) {
      int halfDuration = (stayDuration / 2).round();
      // Répartition pour le pays actuel
      if (_countryStayDurations.containsKey(countryinfo)) {
        _countryStayDurations[countryinfo] = _countryStayDurations[countryinfo]! + halfDuration;
      } else {
        _countryStayDurations[countryinfo] = halfDuration;
      }

      // Répartition pour le pays suivant
      if (_countryStayDurations.containsKey(countryinfonext)) {
        _countryStayDurations[countryinfonext] = _countryStayDurations[countryinfonext]! + halfDuration;
      } else {
        _countryStayDurations[countryinfonext] = halfDuration;
      }
    } else {
      // Si le pays n'a pas changé, on ajoute la durée complète
      if (_countryStayDurations.containsKey(countryinfo)) {
        _countryStayDurations[countryinfo] = _countryStayDurations[countryinfo]! + stayDuration;
      } else {
        _countryStayDurations[countryinfo] = stayDuration;
      }
    }
  }

  // Traiter la dernière photo, qui n'a pas de photo suivante pour calculer la durée
  if (_markers.isNotEmpty) {
    String lastCountry = _markers.last.image.country.name;
    CountryInfo lastcountryinfo = CountryInfo.withName(lastCountry);

    if (_countryStayDurations.containsKey(lastcountryinfo)) {
      _countryStayDurations[lastcountryinfo] = _countryStayDurations[lastcountryinfo]! + 1;
    } else {
      _countryStayDurations[lastcountryinfo] = 1;
    }
  }

  return _countryStayDurations;
}

  void _updateFilters()
  {
    filteredMarkers = allMarkers;
    filteredMarkers = _filterMarkersByDate(filteredMarkers);
    countryStayDurations = calculateStayDurations(filteredMarkers);
    filteredMarkers = _filterSelectedCountries(filteredMarkers);
    drawLinesBetweenMarkers();
  }

  List<ImageMarker> _filterSelectedCountries(List<ImageMarker> markers)
  {
    return CountryStayTracker.filterMarkersByCountry(markers, selectedCountries);
  }

  List<ImageMarker> _filterMarkersByDate(List<ImageMarker> markers) {
    return DateSliderFilter.filterMarkersByDate(markers, _currentRangeValues);
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
          countryStayDurations = calculateStayDurations(filteredMarkers);
          debugInfo.add("Image Found : " + marker.image.name);
        });
      }, () {
        setState(() {
          isLoading = true;
          totalImagesFound = allMarkers.length;
        });
      }, (imagesFound) {
        setState(() {
          totalImagesFound = totalImagesFound + imagesFound.length;
        });
      }, (NewsMarkerAdded) {
        setState(() {
          isLoading = false;
          final newCountries = NewsMarkerAdded.map((marker) => marker.image.country).toSet();
          final currentCountries = selectedCountries.toSet();
          selectedCountries = (currentCountries.union(newCountries)).toList();  
          _updateSliderRange();
          _updateFilters();
          debugInfo.add("${NewsMarkerAdded.length} images processed");
        });
      });
    }
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
    totalImagesFound -= folder.markers.length;
    if(folderList.length == 1) totalImagesFound = 0;
    folderList.remove(folder); 
    allMarkers = allMarkers.where((marker) => !folder.markers.contains(marker)).toList();
    totalImages = allMarkers.length;
    
    // Mettre à jour les pays sélectionnés
    selectedCountries = selectedCountries.where((country) {
      // Vérifie s’il reste au moins une image pour ce pays
      return allMarkers.any((marker) => marker.image.country == country);
    }).toList();

    _updateSliderRange();

    // Mettre à jour les marqueurs affichés après suppression
    _updateFilters();
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
    _updateFilters();

    totalImages = allMarkers.length;
  });
}

String shortenPathMiddle(String path, int maxLength) {
  if (path.length <= maxLength) return path;

  final regex = RegExp(r'^.*?[\\/]'); // capture drive/root like C:\ or /
  final match = regex.firstMatch(path);
  final root = match?.group(0) ?? '';
  final end = path.substring(root.length);

  // Reserve space for root + ellipsis
  const ellipsis = '...';
  final reserved = root.length + ellipsis.length;
  final endMaxLength = maxLength - reserved;

  if (endMaxLength <= 0) {
    // If even the root + ellipsis exceeds limit, just truncate path
    return path.substring(path.length - maxLength);
  }

  final endPart = end.length > endMaxLength
      ? end.substring(end.length - endMaxLength)
      : end;

  return '$root$ellipsis$endPart';
}


  // Show image gallery in a popup
void _showImageGallery(List<ImageMarker> imageMarkers) {
  ImageMarker? localSelectedMarker = selectedImageMarker; // Copie locale

  showDialog(
    context: context,
    builder: (context) {
      final screenSize = MediaQuery.of(context).size;
      final dialogWidth = screenSize.width * 0.8;
      final dialogHeight = screenSize.height * 0.7;

      return AlertDialog(
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              width: dialogWidth,
              height: dialogHeight,
              child: Row(
                children: [
                  // Liste d'images à gauche
                  Container(
                    width: 150,
                    child: ListView.builder(
                      itemCount: imageMarkers.length,
                      itemBuilder: (context, index) {
                        final imageMarker = imageMarkers[index];
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              localSelectedMarker = imageMarker;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: imageMarker == localSelectedMarker ? Colors.green : Colors.blue,
                                width: imageMarker == localSelectedMarker ? 3 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(4, 4),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(-4, -4),
                                ),
                              ],
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
                  // Affichage de l'image sélectionnée à droite
                  Expanded(
                    child: localSelectedMarker == null
                        ? Center(child: Text('Select an image'))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Image.memory(
                                  localSelectedMarker!.image.data,
                                  fit: BoxFit.scaleDown,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                localSelectedMarker!.image.name,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
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
                // Panel de gestion des dossiers
                Container(
                  width: 200,
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
                                    Expanded(
                                      child: Tooltip(
                                        message: folder.path,
                                        child: Text(
                                          shortenPathMiddle(folder.path, 35),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          textAlign: TextAlign.left,
                                          textDirection: TextDirection.rtl,
                                          softWrap: true,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
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
                      ),
                    ],
                  ),
                ),
                
                // Carte avec marqueurs
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      minZoom: 2.0,
                      maxZoom: 18.0,
                      initialCenter: mapCenter,
                      initialZoom: 2.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      ),
                      if(!isOnline)
                        PolygonLayer(
                          polygons: CountryStayTracker.getPolygonsForOfflineMap(),
                        ),
                      PolygonLayer(
                        polygons: CountryStayTracker.getPolygonsFromSelectedCountries(selectedCountries),
                      ),
                      PolylineLayer(polylines: polylines),
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 50,
                          size: const Size(30, 30),
                          markers: filteredMarkers.map((imageMarker) => imageMarker.marker).toList(),
                          builder: (context, markers) {
                            return GestureDetector(
                              onTap: () {
                                // Lorsque le cluster est tapé, on extrait les marqueurs
                                // Utilise `markers` pour obtenir la liste des marqueurs dans ce cluster
                                
                                // Filtrer les images en fonction des marqueurs dans ce cluster
                                List<ImageMarker> clusterImages = filteredMarkers.where((imageMarker) {
                                  return markers.any((marker) => marker == imageMarker.marker);
                                }).toList();
                                
                                // Afficher la galerie d'images pour ce cluster
                                _showImageGallery(clusterImages);
                              },
                              child: Container(
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
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Range Slider
                DateSliderFilter(
                  currentRangeValues: _currentRangeValues,
                  minSliderValue: minSliderValue,
                  maxSliderValue: maxSliderValue,
                  onChanged: (RangeValues values) {
                    setState(() {
                      _currentRangeValues = values;
                      _updateFilters();
                    });
                  },
                ),
                CountryStayWidget(
                    countryStayDurations: countryStayDurations,
                    selectedCountries : selectedCountries,
                    onCountrySelectedChange: (_selectedCountries) => 
                    {
                        setState(() {
                          selectedCountries = _selectedCountries;
                          _updateFilters();
                        })
                    },),
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
