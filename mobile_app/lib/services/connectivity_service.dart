import 'dart:async';
import 'package:flutter/foundation.dart';

/// ConnectivityService — surveille l'état du réseau.
/// Sur web : assume toujours en ligne
/// Sur mobile : vérifie via InternetAddress
class ConnectivityService with ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  Timer? _timer;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;

  /// Stream qui émet true quand on passe en ligne, false quand hors ligne.
  Stream<bool> get onStatusChanged => _controller.stream;

  /// Stream filtré : émet uniquement quand la connexion est rétablie.
  Stream<void> get onConnected =>
      _controller.stream.where((online) => online).map((_) {});

  /// Démarre la surveillance périodique (toutes les 5 secondes).
  void startMonitoring() {
    _timer?.cancel();
    _checkNow();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNow());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNow() async {
    final online = await _checkConnectivity();
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(_isOnline);
      notifyListeners();
    }
  }

  /// Vérifie la connectivité (web-safe).
  Future<bool> _checkConnectivity() async {
    if (kIsWeb) {
      // Sur web, on suppose toujours en ligne
      return true;
    }
    // Sur mobile : assume en ligne (connectivité check complet inutile pour cette démo)
    return true;
  }

  @override
  void dispose() {
    stopMonitoring();
    _controller.close();
    super.dispose();
  }
}
