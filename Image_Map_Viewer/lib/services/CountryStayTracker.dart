import 'package:Image_Map_Viewer/services/ImageMarker.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'Tools.dart';

class CountryInfo {
  String name;
  String iso;

  // Constructeur principal
  CountryInfo(this.name, this.iso);

  // Constructeur factory asynchrone
  static CountryInfo withName(String name) {
    String iso = CountryStayTracker.getISOFromCountryName(name);
    return CountryInfo(name, iso);
  }

  // Override equality to check if names are the same
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CountryInfo && other.name == this.name;
  }

  // Override hashCode to ensure proper comparison in collections like Map
  @override
  int get hashCode => name.hashCode;
}

class CountryStayTracker {
  static GeoJSONFeatureCollection? geoJsonData;
  static CountryInfo? hoveredCountry;

  /// Charge le fichier GeoJSON une seule fois en mémoire
  static Future<void> loadGeoJson() async {
    if (geoJsonData == null) {
      try {
        String geoJsonString = await rootBundle.loadString('assets/countries.geojson');
        geoJsonData = GeoJSONFeatureCollection.fromJSON(geoJsonString);
      } catch (e) {
        print("Erreur de chargement du GeoJSON: $e");
      }
    }
  }

static List<ImageMarker> filterMarkersByCountry(List<ImageMarker> markers, List<CountryInfo> selectedCountries) {
  return markers.where((marker) {
    return selectedCountries.any((country) => country.name == marker.image.country.name);
  }).toList();
}


  /// Récupère le code ISO en fonction du nom du pays
  static String getISOFromCountryName(String countryName) {
    if (geoJsonData == null) return "??";

    for (var feature in geoJsonData!.features) {
      String name = feature?.properties?["ADMIN"] ?? "Unknown";
      String iso = feature?.properties?["ISO_A2"] ?? "??";

      if (name.toLowerCase() == countryName.toLowerCase()) {
        return iso;
      }
    }

    print("⚠️ Pays non trouvé : $countryName");
    return "??"; // Retourne "??" si aucun pays trouvé
  }
static CountryInfo getCountryFromCoordinates(LatLng coordinates) {
    if (geoJsonData == null) return CountryInfo("Unknown", "??");

    CountryInfo nearestCountry = CountryInfo("Unknown", "??");
    double minDistance = double.infinity;
    final Distance distance = Distance();

    for (var feature in geoJsonData!.features) {
      GeoJSONGeometry? geometry = feature?.geometry;
      if (geometry == null) continue;

      String countryName = feature?.properties?["ADMIN"] ?? "Unknown";
      String countryISO = feature?.properties?["ISO_A3"] ?? "??";

      CountryInfo country = CountryInfo(countryName, countryISO);

      if (geometry is GeoJSONPolygon) {
        if (_isPointInPolygon(coordinates, geometry)) {
          return country; // Found inside, return immediately
        } else {
          double d = _getMinDistanceToPolygon(coordinates, geometry, distance);
          if (d < minDistance) {
            minDistance = d;
            nearestCountry = country;
          }
        }
      } else if (geometry is GeoJSONMultiPolygon) {
        for (var polygonCoordinates in geometry.coordinates) {
          GeoJSONPolygon polygon = GeoJSONPolygon(polygonCoordinates);
          if (_isPointInPolygon(coordinates, polygon)) {
            return country; // Found inside, return immediately
          } else {
            double d = _getMinDistanceToPolygon(coordinates, polygon, distance);
            if (d < minDistance) {
              minDistance = d;
              nearestCountry = country;
            }
          }
        }
      }
    }

    print("🌍 Nearest country: $nearestCountry (Distance: ${minDistance.toStringAsFixed(2)} km)");
    return nearestCountry;
  }
static List<Polygon> getPolygonsForOfflineMap() {
  List<Polygon> countryPolygons = [];

  if (CountryStayTracker.geoJsonData == null) return countryPolygons;

  List<CountryInfo> allCountries = CountryStayTracker.geoJsonData!.features.map((feature) {
    final name = feature?.properties?["ADMIN"] ?? "Unknown";
    return CountryInfo.withName(name);
  }).toList();

  for (var country in allCountries) {
    final List<List<LatLng>>? polygons = CountryStayTracker.getPolygonsForCountry(country);

    if (polygons != null) {
      for (var poly in polygons) {
        if (poly.length > 2) {
          countryPolygons.add(
            Polygon(
              points: poly,
              borderColor: const Color.fromARGB(255, 0, 0, 0).withAlpha(50),
              borderStrokeWidth: 0.5,
              color: const Color.fromARGB(255, 255, 252, 252), // Use transparent or null for no fill
              label: country.name,
              labelStyle: const TextStyle(
                color: Color.fromARGB(255, 170, 158, 158),
                fontSize: 10,
              ),
            ),
          );
        }
      }
    }
  }
  return countryPolygons;
}

static List<Polygon> getPolygonsFromSelectedCountries(List<CountryInfo> selectedCountries) {
  List<Polygon> countryPolygons = [];

  for (var country in selectedCountries) {
    final List<List<LatLng>>? polygons = CountryStayTracker.getPolygonsForCountry(country);

    if (polygons != null) {
      for (var poly in polygons) {
        if (poly.length > 2) {
          countryPolygons.add(
            Polygon(
              points: poly,
              borderColor: const Color.fromARGB(255, 152, 54, 244),
              borderStrokeWidth: 1.0,
              color: CountryStayTracker.hoveredCountry != null && CountryStayTracker.hoveredCountry!.name == country.name
                  ? const Color.fromARGB(255, 122, 6, 117).withOpacity(0.5) // Plus foncé
                  : const Color.fromARGB(255, 122, 6, 117).withOpacity(0.2),
              label: country.name,
              labelStyle: const TextStyle(
                shadows: [
                  Shadow(
                    offset: Offset(1.5, 1.5),
                    blurRadius: 2.0,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
  }

  return countryPolygons;
}

static CountryInfo? getCountryAtPosition(LatLng position, List<CountryInfo> selectedCountries) {
  for (var country in selectedCountries) {
    final polygons = CountryStayTracker.getPolygonsForCountry(country);
    if (polygons != null) {
      for (var poly in polygons) {
        if (CountryStayTracker._isPointInPolygon(position, GeoJSONPolygon([
          poly.map((p) => [p.longitude, p.latitude]).toList()
        ]))) {
          return country;
        }
      }
    }
  }
  return null;
}


static List<List<LatLng>>? getPolygonsForCountry(CountryInfo country) {
  if (geoJsonData == null) return null;

  for (final feature in geoJsonData!.features) {
    final name = feature?.properties?["ADMIN"] ?? "Unknown";

    if (name.toLowerCase() == country.name.toLowerCase()) {
      final geometry = feature?.geometry;

      // Helper to convert and clamp coordinates
      List<LatLng> toLatLngList(List<List<double>> coords) {
        return coords.map((coord) {
          final lat = coord[1].clamp(-90.0, 90.0);
          final lng = coord[0].clamp(-180.0, 180.0);
          return LatLng(lat, lng);
        }).toList();
      }

      if (geometry is GeoJSONPolygon) {
        final outerRing = geometry.coordinates.first;
        List<LatLng> polygon = toLatLngList(outerRing);

        // Ensure closed ring
        if (polygon.isNotEmpty && polygon.first != polygon.last) {
          polygon.add(polygon.first);
        }

        return [polygon]; // Single polygon inside a list
      }

      if (geometry is GeoJSONMultiPolygon) {
        List<List<LatLng>> polygons = [];

        for (final polygonCoords in geometry.coordinates) {
          final outerRing = polygonCoords.first;
          List<LatLng> polygon = toLatLngList(outerRing);

          if (polygon.isNotEmpty && polygon.first != polygon.last) {
            polygon.add(polygon.first);
          }

          polygons.add(polygon);
        }

        return polygons;
      }
    }
  }

  return null;
}



  /// Vérifie si un point est à l'intérieur d'un polygone (Ray-casting algorithm)
  static bool _isPointInPolygon(LatLng point, GeoJSONPolygon polygon) {
    var points = polygon.coordinates[0];
    bool inside = false;
    int n = points.length;
    double xinters;
    var p1x = points[0][0], p1y = points[0][1];

    for (int i = 1; i <= n; i++) {
      var p2x = points[i % n][0], p2y = points[i % n][1];
      if (point.latitude > p1y && point.latitude <= p2y || point.latitude > p2y && point.latitude <= p1y) {
        xinters = (point.latitude - p1y) * (p2x - p1x) / (p2y - p1y) + p1x;
        if (p1x == p2x || point.longitude <= xinters) {
          inside = !inside;
        }
      }
      p1x = p2x;
      p1y = p2y;
    }
    return inside;
  }

    /// Calcule la distance minimale d'un point à un polygone
  static double _getMinDistanceToPolygon(LatLng point, GeoJSONPolygon polygon, Distance distance) {
    double minDist = double.infinity;

    for (var ring in polygon.coordinates) {
      for (var vertex in ring) {
        double lat = vertex[1], lon = vertex[0];

        // Vérification des valeurs (évite NaN et erreurs)
        if (lat.isNaN || lon.isNaN) continue;
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        try {
          double d = distance.as(
            LengthUnit.Kilometer,
            point,
            LatLng(lat, lon),
          );
          if (d < minDist) {
            minDist = d;
          }
        } catch (e) {
          print("⚠️ Erreur de calcul de distance: $e");
        }
      }
    }

    return minDist == double.infinity ? 0 : minDist;
  }
}
