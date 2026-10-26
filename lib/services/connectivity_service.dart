import 'package:connectivity_plus/connectivity_plus.dart';

/// Small wrapper around connectivity_plus so the rest of the app does not have
/// to know about its platform types.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();
      if (results.isEmpty) return false;
      return results
          .any((ConnectivityResult r) => r != ConnectivityResult.none);
    } catch (_) {
      // If the platform call fails, assume online and let the HTTP layer decide.
      return true;
    }
  }
}
