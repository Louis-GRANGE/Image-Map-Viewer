import 'package:connectivity_plus/connectivity_plus.dart';


class ConnectivityPlus {
  static Future<bool> hasInternetConnection() async {
    final ConnectivityResult result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}