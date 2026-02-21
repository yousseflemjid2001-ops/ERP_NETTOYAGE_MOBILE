# Guide de Déploiement du Mobile (Flutter)

## 📱 ARCHITECTURE MOBILE

Votre app Flutter peut:
1. **Pointer vers le backend Railway** (option la plus simple)
2. **Fonctionner hors ligne** et syncer les données après
3. **Être compilée en APK** pour Android
4. **Être compilée en IPA** pour iOS (macOS requis)

---

## 1️⃣ CONFIGURER L'APP MOBILE POUR PRODUCITON

### Étape 1: Mettre à jour la Base URL

1. Trouvez le fichier de configuration API (probablement `lib/services/api_service.dart` ou `lib/config/api_config.dart`):

```dart
class ApiConfig {
  // Development
  static const String devBaseUrl = 'http://localhost:3000/api';
  
  // Production
  static const String prodBaseUrl = 'https://your-service-name-production.railway.app/api';
  
  // Le vrai choix
  static String get baseUrl {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return prodBaseUrl; // Release/Production
    }
    return devBaseUrl;    // Debug/Development
  }
  
  // Ou plus simplement avec une variable d'env
  // static const String baseUrl = String.fromEnvironment(
  //   'API_URL',
  //   defaultValue: 'http://localhost:3000/api',
  // );
}
```

2. Cherchez les fichiers qui contiennent `localhost:3000` et remplacez-les:

```bash
cd C:\erp-nettoyage-mobile\mobile_app
grep -r "localhost:3000" lib/
```

3. Mettez à jour où vous trouvez cela.

### Étape 2: Vérifier `pubspec.yaml`

Assurez-vous que les dépendances sont correctes:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  # ... autres dépendances
```

### Étape 3: Commiter les changements

```bash
cd C:\erp-nettoyage-mobile
git add .
git commit -m "feat: update API base URL for production Railway backend"
git push origin main
```

---

## 2️⃣ CONSTRUIRE L'APK POUR ANDROID

### Prérequis
- Android SDK installé
- Java Development Kit (JDK) 11+
- Clé de signature Android générée

### Étape 1: Générer une Clé de Signature (si pas encore fait)

```bash
cd C:\erp-nettoyage-mobile\mobile_app

# Créer une clée de déverrouilasse
keytool -genkey -v -keystore ../upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10950 `
  -alias upload

# Commandes sur Mac/Linux:
# keytool -genkey -v -keystore ~/upload-keystore.jks \
#   -keyalg RSA -keysize 2048 -validity 10950 \
#   -alias upload
```

**Notes lors du prompt**:
- Password: Créez un mot de passe fort (ex: `MySecureKeyPassword123!`)
- Common Name: `localhost`
- Notez le mot de passe!

### Étape 2: Configurer la Clé dans le Projet

1. Créez/mettez à jour `android/key.properties`:

```properties
storePassword=YourPasswordHere
keyPassword=YourPasswordHere
keyAlias=upload
storeFile=../upload-keystore.jks
```

2. Assurez-vous que `android/app/build.gradle.kts` a:

```kotlin
signingConfigs {
    release {
        keyAlias = keystoreProperties["keyAlias"]
        keyPassword = keystoreProperties["keyPassword"]
        storeFile = file(keystoreProperties["storeFile"])
        storePassword = keystoreProperties["storePassword"]
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.release
    }
}
```

### Étape 3: Compiler l'APK de Release

```bash
cd C:\erp-nettoyage-mobile\mobile_app

# Build APK
flutter build apk --release

# Output:
# ✅ Built build/app/outputs/flutter-app.apk (XX MB)
```

### Étape 4: Compiler l'AAB (Android App Bundle) - Pour Google Play

```bash
flutter build appbundle --release

# Output:
# ✅ Built build/app/outputs/bundle/release/app-release.aab
```

---

## 3️⃣ PUBLIER SUR GOOGLE PLAY STORE

### Étape 1: Créer un Compte Google Play

1. Allez sur https://play.google.com/console
2. Payez les frais d'enregistrement (€25 une fois)
3. Complétez votre profil

### Étape 2: Créer une Nouvelle App

1. Cliquez sur "Create App"
2. Nom: `Nettoyage Plus Mobile` (ou votre nom)
3. Sélectionnez la catégorie: `Business`
4. Type: `Free`

### Étape 3: Remplir les Informations

1. **Titre court**: `Nettoyage Plus`
2. **Description longue**: Décrivez votre app
3. **Images de capture d'écran**: Téléchargez 2-8 images
4. **Icône**: 512x512 PNG

### Étape 4: Tester avec Internal Testing

1. Allez dans **Testing → Internal Testing**
2. Créez un groupe de testeurs
3. Téléchargez l'AAB (bundle):
   - Cliquez sur "App Releases → Internal Testing"
   - Téléchargez `app-release.aab`
4. Invitez des testeurs avec leurs emails Google

### Étape 5: Publier en Production

1. Allez dans **App Releases → Production**
2. Téléchargez l'AAB final testé
3. Remplissez les infos de contenu (17+, etc)
4. Cliquez sur **Review and Publish**

---

## 4️⃣ DISTRIBUER L'APK DIRECTEMENT

Si vous NE voulez pas passer par Google Play:

### Option 1: Distribution par Email/Cloud

```bash
# L'APK se trouve ici:
C:\erp-nettoyage-mobile\mobile_app\build\app\outputs\flutter-app.apk

# Envoyez par:
# - Email
# - Google Drive
# - Dropbox
# - Un serveur web
```

### Option 2: Auto-Hébergement

Créez un simple site web pour télécharger l'APK:

```html
<!DOCTYPE html>
<html>
<body>
  <h1>Télécharger Nettoyage Plus Mobile</h1>
  
  <a href="app-release.apk" download>
    <button>Télécharger APK</button>
  </a>
  
  <p>Version: 1.0.0</p>
  <p>Scannez ou cliquez pour installer</p>
</body>
</html>
```

---

## 5️⃣ iOS (Pour macOS)

**ℹ️ Remarque**: L'iOS require un Mac et un compte Apple Developer ($99/an)

### Prérequis
- Mac avec macOS Monterey+
- Xcode 13+
- Apple ID

### Compilation

```bash
cd C:\erp-nettoyage-mobile\mobile_app

flutter build ios --release

# Ouvrez Xcode pour signer et publier
open ios/Runner.xcworkspace
```

---

## 6️⃣ WEB FLUTTER

Ces fichiers Flutter peuvent aussi être compilés en web:

```bash
flutter build web --release

# Output: build/web/
```

Vous pouvez deploy sur Vercel comme du contenu statique.

---

## 7️⃣ MISE À JOUR AUTOMATISÉE (Optionnel)

Pour vérifier les mises à jour:

```dart
// lib/services/version_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

class VersionService {
  static const String apiUrl = 'https://api.railway.app/api/app/version';
  
  Future<bool> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'];
        
        // Comparer avec la version actuelle (dans pubspec.yaml)
        // Afficher un popup pour demander la mise à jour
        return true;
      }
    } catch (e) {
      print('Error checking updates: $e');
    }
    return false;
  }
}
```

---

## 8️⃣ RÉSUMÉ - CHECKLIST DE DÉPLOIEMENT MOBILE

- [ ] Mettre à jour `baseUrl` de l'API vers Railway
- [ ] Tester localement avec l'API de production
- [ ] Augmenter le numéro de version dans `pubspec.yaml`
- [ ] `flutter build apk --release` compile avec succès
- [ ] Générer la clé de signature Android
- [ ] Configurer `key.properties`
- [ ] `flutter build appbundle --release` crée l'AAB
- [ ] Créer un compte Google Play Console
- [ ] Tester l'app avec Internal Testing
- [ ] Publier en production ou distribuer l'APK directement

---

## 9️⃣ ERREURS COURANTES

### "Unable to find SDK"
```bash
flutter config --android-sdk /path/to/android-sdk
```

### "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### "Certificate not trusted"
Assurez-vous que Railway configure HTTPS correctement ou mettez à jour l'API URL.

---

## 🔟 COMMANDES UTILES

```bash
# Vérifier la version Flutter
flutter --version

# Lister les devices disponibles
flutter devices

# Construire et installer sur device
flutter install

# Release mode local (pour tester)
flutter run --release

# Nettoyer le build
flutter clean
flutter pub get

# Voir les logs
flutter logs

# Analyser le code
flutter analyze
```

