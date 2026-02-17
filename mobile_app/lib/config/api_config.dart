class ApiConfig {
  // Change this to your backend URL
  static const String baseUrl = 'http://localhost:3000/api';
  // For production:
  // static const String baseUrl = 'https://your-railway-backend.up.railway.app/api';

  static const Duration timeout = Duration(seconds: 30);
}
