import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  ConnectivityService._();
  static ConnectivityService get instance => _instance;

  Future<bool> get isConnected async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
  }

  static const String offlineMessage =
      'No internet connection. Please check your network.';

  /// Wraps a network call — throws a readable error if offline
  Future<T> guard<T>(Future<T> Function() call) async {
    if (!await isConnected) throw Exception(offlineMessage);
    return await call();
  }
}
