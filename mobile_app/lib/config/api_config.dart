import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Détecte automatiquement l'environnement d'exécution
  static String get baseUrl {
    if (kIsWeb) {
      // Sur navigateur web → localhost
      return 'http://localhost:3000/api';
    } else {
      // Sur Android/iOS (APK) → IP locale du serveur
      return 'http://192.168.1.31:3000/api';
    }
  }

  // Pour production:
  // static const String productionUrl = 'https://your-railway-backend.up.railway.app/api';

  static const Duration timeout = Duration(seconds: 30);
}
