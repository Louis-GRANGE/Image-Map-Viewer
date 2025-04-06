import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:Image_Map_Viewer/services/CountryStayTracker.dart';

class CountryStayWidget extends StatefulWidget {
  final Map<CountryInfo, int> countryStayDurations;
  final List<CountryInfo> selectedCountries;
  final void Function(List<CountryInfo>)? onCountrySelectedChange; // callback

  const CountryStayWidget({
    Key? key,
    required this.countryStayDurations,
    required this.selectedCountries,
    this.onCountrySelectedChange,
  }) : super(key: key);

  @override
  State<CountryStayWidget> createState() => _CountryStayWidgetState();
}

class _CountryStayWidgetState extends State<CountryStayWidget> {

  @override
  Widget build(BuildContext context) {
    var countryList = widget.countryStayDurations.entries.toList();

    return Container(
      width: 250,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: countryList.length,
        itemBuilder: (context, index) {
          CountryInfo country = countryList[index].key;
          int stayDuration = countryList[index].value;
          bool isSelected = widget.selectedCountries.contains(country);

          return GestureDetector(
            onTap: () {
              setState(() {
                if(isSelected)
                  widget.selectedCountries.remove(country);
                else
                  widget.selectedCountries.add(country);

                widget.onCountrySelectedChange!(widget.selectedCountries);
              });
            },
            child: Card(
              color: isSelected ? Colors.blue[100] : null,
              margin: const EdgeInsets.symmetric(vertical: 2.0),
              child: ListTile(
                leading: CountryFlag.fromCountryCode(country.iso, height: 30, width: 30),
                title: Text(country.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? Colors.blue[900] : null,
                    )),
                subtitle: Text('Stay: $stayDuration days',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          );
        },
      ),
    );
  }
}
