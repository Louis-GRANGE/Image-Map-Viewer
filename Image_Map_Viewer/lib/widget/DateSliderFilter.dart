import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ImageMarker.dart';

class DateSliderFilter extends StatelessWidget {
  final RangeValues currentRangeValues;
  final double minSliderValue;
  final double maxSliderValue;
  final Function(RangeValues) onChanged;

  const DateSliderFilter({
    Key? key,
    required this.currentRangeValues,
    required this.minSliderValue,
    required this.maxSliderValue,
    required this.onChanged,
  }) : super(key: key);

  static List<ImageMarker> filterMarkersByDate(List<ImageMarker> markers, RangeValues range) {
    return markers.where((marker) {
        DateTime? date = marker.image.timestamp;
        if (date == null) return false;
        double timestamp = date.millisecondsSinceEpoch.toDouble();
        return timestamp >= range.start && timestamp <= range.end;
      })
      .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: RotatedBox(
        quarterTurns: 3,
        child: RangeSlider(
          values: currentRangeValues,
          min: minSliderValue,
          max: maxSliderValue,
          divisions: 100,
          labels: RangeLabels(
            DateFormat('yyyy-MM-dd').format(
              DateTime.fromMillisecondsSinceEpoch(currentRangeValues.start.round().toInt())
            ),
            DateFormat('yyyy-MM-dd').format(
              DateTime.fromMillisecondsSinceEpoch(currentRangeValues.end.round().toInt())
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
