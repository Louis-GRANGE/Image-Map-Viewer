import 'package:Image_Map_Viewer/services/CountryStayTracker.dart';
import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart'; // Importation de la bibliothèque

class CountryStayWidget extends StatelessWidget {
  final Map<CountryInfo, int> countryStayDurations;

  const CountryStayWidget({
    Key? key,
    required this.countryStayDurations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: countryStayDurations.length,
        itemBuilder: (context, index) {
          // Récupérer les pays et durées sous forme de liste
          var countryList = countryStayDurations.entries.toList();
          CountryInfo country = countryList[index].key;
          int stayDuration = countryList[index].value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 1.0),
            child: ListTile(
              leading: CountryFlag.fromCountryCode(country.iso, height: 30, width: 30),  // Affichage du drapeau
              title: Text(country.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('Stay : $stayDuration days', style: TextStyle(fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}
