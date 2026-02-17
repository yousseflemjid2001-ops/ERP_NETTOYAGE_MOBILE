import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  User? _user;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final storedUser = await _api.getStoredUser();
      final token = await _api.getToken();

      if (storedUser != null && token != null) {
        _user = storedUser;
        // Verify token is still valid
        try {
          _user = await _api.getMe();
        } catch (e) {
          // Token expired, clear auth
          await _api.clearAuth();
          _user = null;
        }
      }
    } catch (e) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.login(email, password);
      _user = result['user'] as User;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Impossible de se connecter. Vérifiez votre connexion.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearAuth();
    _user = null;
    notifyListeners();
  }

  Future<bool> forgotPassword(String email) async {
    try {
      await _api.forgotPassword(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
