import 'package:Image_Map_Viewer/services/ImageMarker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  /// Vérifie dans quel pays se trouvent les coordonnées GPS, sinon trouve le pays le plus proche
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
