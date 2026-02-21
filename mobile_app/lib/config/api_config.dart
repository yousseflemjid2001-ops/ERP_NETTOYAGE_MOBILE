import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConfig {
  // URL de production Railway
  static const String productionUrl =
      'https://erpnettoyage-production-8df4.up.railway.app/api';

  // Détecte automatiquement l'environnement d'exécution
  static String get baseUrl {
    if (kReleaseMode) {
      // APK Release → toujours Railway production
      return productionUrl;
    }
    if (kIsWeb) {
      // Debug web → localhost
      return 'http://localhost:3000/api';
    } else {
      // Debug Android → IP locale du serveur
      return 'http://192.168.1.31:3000/api';
    }
  }

  static const Duration timeout = Duration(seconds: 30);
}
