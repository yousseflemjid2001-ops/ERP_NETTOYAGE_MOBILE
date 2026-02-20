import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../models/intervention.dart';
import '../../config/theme.dart';

class MissionDetailPage extends StatefulWidget {
  final String missionId;
  const MissionDetailPage({super.key, required this.missionId});

  @override
  State<MissionDetailPage> createState() => _MissionDetailPageState();
}

class _MissionDetailPageState extends State<MissionDetailPage> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  Intervention? _mission;
  String? _error;
  bool _actionLoading = false;
  String? _gpsError;
  final List<Uint8List> _capturedPhotos = [];
  bool _photoUploading = false;

  // Derived state from mission data
  bool get _hasCheckedIn =>
      _mission?.checkInLatitude != null && _mission?.checkInLongitude != null;
  bool get _hasCheckedOut =>
      _mission?.checkOutLatitude != null && _mission?.checkOutLongitude != null;

  // GPS state based ONLY on actual GPS coordinates, not status
  bool get _isCheckInDone => _hasCheckedIn;
  bool get _isCheckOutDone => _hasCheckedOut;

  @override
  void initState() {
    super.initState();
    _loadMission();
  }

  Future<void> _loadMission() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _mission = await _api.getMissionById(widget.missionId);
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ============================================
  // GPS Location Helper
  // ============================================
  Future<Position?> _getCurrentPosition() async {
    setState(() => _gpsError = null);

    try {
      // 1. Vérifier si le service GPS est activé
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(
          () => _gpsError =
              'Le GPS est désactivé. Activez-le dans les paramètres.',
        );
        return null;
      }

      // 2. Vérifier / demander la permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(
          () => _gpsError = permission == LocationPermission.deniedForever
              ? 'Permission GPS refusée définitivement. Activez-la dans les paramètres.'
              : 'Permission de localisation refusée.',
        );
        return null;
      }

      // 3. Obtenir la position (API geolocator 13+ avec LocationSettings)
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on PermissionDeniedException {
      setState(() => _gpsError = 'Permission de localisation refusée.');
      return null;
    } on LocationServiceDisabledException {
      setState(
        () =>
            _gpsError = 'Le GPS est désactivé. Activez-le dans les paramètres.',
      );
      return null;
    } catch (e) {
      setState(() => _gpsError = 'Erreur GPS: ${e.toString()}');
      return null;
    }
  }

  // ============================================
  // Mission Actions
  // ============================================

  Future<void> _performGPSCheckIn() async {
    setState(() => _actionLoading = true);
    try {
      final position = await _getCurrentPosition();
      if (position == null) {
        // Show the GPS error as a SnackBar as well (for scheduled missions
        // where the GPS card is not yet visible)
        if (mounted && _gpsError != null) {
          _showError(_gpsError!);
        }
        setState(() => _actionLoading = false);
        return;
      }

      _mission = await _api.checkIn(
        widget.missionId,
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
      );
      _showSuccess('GPS Check-in enregistré !');
    } catch (e) {
      _showError('Erreur check-in: ${e.toString()}');
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _performGPSCheckOut() async {
    setState(() => _actionLoading = true);
    try {
      final position = await _getCurrentPosition();
      if (position == null) {
        setState(() => _actionLoading = false);
        return;
      }

      _mission = await _api.checkOut(
        widget.missionId,
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
      );
      _showSuccess('GPS Check-out enregistré !');
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (image == null) return;

      setState(() => _photoUploading = true);

      final bytes = await image.readAsBytes();

      // Check file size (limit to ~500KB)
      if (bytes.length > 500000) {
        _showError('Photo trop grande. Veuillez réessayer.');
        setState(() => _photoUploading = false);
        return;
      }

      // Send only base64 without data URI prefix (simple-array doesn't support special chars)
      final base64Image = base64Encode(bytes);

      // Upload to API
      _mission = await _api.addPhoto(widget.missionId, base64Image);

      // Add to local preview
      setState(() => _capturedPhotos.add(bytes));
      _showSuccess('Photo ajoutée !');
    } catch (e) {
      _showError('Erreur photo: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (image == null) return;

      setState(() => _photoUploading = true);

      final bytes = await image.readAsBytes();

      // Check file size (limit to ~500KB)
      if (bytes.length > 500000) {
        _showError(
          'Photo trop grande (max 500KB). Veuillez choisir une autre photo.',
        );
        setState(() => _photoUploading = false);
        return;
      }

      // Send only base64 without data URI prefix (simple-array doesn't support special chars)
      final base64Image = base64Encode(bytes);

      _mission = await _api.addPhoto(widget.missionId, base64Image);

      setState(() => _capturedPhotos.add(bytes));
      _showSuccess('Photo ajoutée !');
    } catch (e) {
      _showError('Erreur photo: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _completeMission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la mission'),
        content: const Text(
          'Êtes-vous sûr de vouloir terminer cette mission ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      _mission = await _api.completeMission(widget.missionId);
      _showSuccess('Mission terminée !');
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  // ============================================
  // Helper UI Methods
  // ============================================

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.secondaryColor),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  // ============================================
  // Build UI
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail Mission')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMission,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : _mission == null
          ? const Center(child: Text('Mission non trouvée'))
          : RefreshIndicator(
              onRefresh: _loadMission,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBadge(),
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      title: 'Site',
                      icon: Icons.business,
                      children: [
                        if (_mission!.siteName != null)
                          _buildInfoRow('Nom', _mission!.siteName!),
                        if (_mission!.siteAddress != null)
                          _buildInfoRow('Adresse', _mission!.siteAddress!),
                        if (_mission!.clientName != null)
                          _buildInfoRow('Client', _mission!.clientName!),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Horaires',
                      icon: Icons.schedule,
                      children: [
                        _buildInfoRow(
                          'Date',
                          _formatDisplayDate(_mission!.scheduledDate),
                        ),
                        _buildInfoRow(
                          'Horaire prévu',
                          '${_formatTimeShort(_mission!.scheduledStartTime)} - ${_formatTimeShort(_mission!.scheduledEndTime)}',
                        ),
                        if (_mission!.actualStartTime != null)
                          _buildInfoRow(
                            'Début réel',
                            _formatTimeShort(_mission!.actualStartTime),
                          ),
                        if (_mission!.actualEndTime != null)
                          _buildInfoRow(
                            'Fin réelle',
                            _formatTimeShort(_mission!.actualEndTime),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // GPS Status Card (when in progress)
                    if (_mission!.status == InterventionStatus.inProgress)
                      _buildGPSStatusCard(),

                    // Photos Section (when in progress)
                    if (_mission!.status == InterventionStatus.inProgress)
                      _buildPhotosSection(),

                    // Notes
                    if (_mission!.notes != null &&
                        _mission!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        title: 'Notes',
                        icon: Icons.note,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(_mission!.notes!),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================
  // GPS Status Card
  // ============================================
  Widget _buildGPSStatusCard() {
    return Column(
      children: [
        _buildInfoCard(
          title: 'GPS & Localisation',
          icon: Icons.location_on,
          children: [
            // Step 1: Check-in
            _buildGPSStep(
              step: 1,
              title: 'Check-in (Arrivée)',
              isDone: _isCheckInDone,
              icon: Icons.login,
            ),
            const SizedBox(height: 8),
            // Step 2: Check-out
            _buildGPSStep(
              step: 2,
              title: 'Check-out (Sortie)',
              isDone: _isCheckOutDone,
              icon: Icons.logout,
            ),

            // GPS Error
            if (_gpsError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _gpsError!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGPSStep({
    required int step,
    required String title,
    required bool isDone,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.secondaryColor.withOpacity(0.08)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone ? AppTheme.secondaryColor : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '$step',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDone ? AppTheme.secondaryColor : Colors.grey.shade600,
              ),
            ),
          ),
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? AppTheme.secondaryColor : Colors.grey.shade400,
            size: 22,
          ),
        ],
      ),
    );
  }

  // ============================================
  // Photos Section
  // ============================================

  Widget _buildPhotoImage(String photoData) {
    // Validate photoData is not empty
    if (photoData.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.grey);
    }

    try {
      // Check if it's a data URI with prefix
      if (photoData.startsWith('data:')) {
        // Extract base64 part after comma
        final commaIndex = photoData.indexOf(',');
        if (commaIndex != -1 && commaIndex < photoData.length - 1) {
          final base64String = photoData.substring(commaIndex + 1);
          if (base64String.isEmpty) {
            return const Icon(Icons.broken_image, color: Colors.orange);
          }
          return Image.memory(
            base64Decode(base64String),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image, color: Colors.grey),
          );
        } else {
          // No comma found or nothing after comma - corrupted data
          return const Icon(Icons.broken_image, color: Colors.red);
        }
      }

      // Check if it's a URL (http/https)
      if (photoData.startsWith('http://') || photoData.startsWith('https://')) {
        return Image.network(
          photoData,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image, color: Colors.grey),
        );
      }

      // Otherwise, assume it's raw base64
      if (photoData.length < 10) {
        // Too short to be valid base64
        return const Icon(Icons.broken_image, color: Colors.amber);
      }

      return Image.memory(
        base64Decode(photoData),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image, color: Colors.grey),
      );
    } catch (e) {
      print(
        'Error decoding photo: $e, photoData length: ${photoData.length}, first 50 chars: ${photoData.substring(0, photoData.length > 50 ? 50 : photoData.length)}',
      );
      return const Icon(Icons.broken_image, color: Colors.red);
    }
  }

  Widget _buildPhotosSection() {
    final existingPhotos = _mission?.photoUrls ?? [];
    final totalPhotos = existingPhotos.length + _capturedPhotos.length;

    return Column(
      children: [
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Photos ($totalPhotos)',
          icon: Icons.camera_alt,
          children: [
            // Photo grid
            if (totalPhotos > 0) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Existing photos from server
                  ...existingPhotos.map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: _buildPhotoImage(url),
                      ),
                    ),
                  ),
                  // Locally captured photos
                  ..._capturedPhotos.map(
                    (bytes) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Photo action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _photoUploading ? null : _takePhoto,
                    icon: _photoUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Prendre photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _photoUploading ? null : _pickPhotoFromGallery,
                    icon: const Icon(Icons.photo_library, size: 20),
                    label: const Text('Galerie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // Action Buttons
  // ============================================
  Widget _buildActionButtons() {
    // Scheduled → GPS Check-in (which also starts the mission)
    if (_mission!.status == InterventionStatus.scheduled) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _actionLoading ? null : _performGPSCheckIn,
          icon: _actionLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.login),
          label: const Text('GPS Check-in (Démarrer la mission)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryColor,
          ),
        ),
      );
    }

    // In Progress → Check-in (if not done), Complete
    if (_mission!.status == InterventionStatus.inProgress) {
      return Column(
        children: [
          // Step 1: GPS Check-in (if mission started without GPS)
          if (!_hasCheckedIn)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _performGPSCheckIn,
                icon: _actionLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.login),
                label: const Text('GPS Check-in (Arrivée)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ),

          // Step 2: GPS Check-out button (optionnel)
          if (_hasCheckedIn && !_hasCheckedOut) ...[
            if (_hasCheckedIn) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _performGPSCheckOut,
                icon: _actionLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: const Text('GPS Check-out (Sortie)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          ],

          // Step 3: Complete mission button (always show after check-in)
          if (_hasCheckedIn) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _completeMission,
                icon: _actionLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('Terminer la mission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Completed → Show completed badge
    if (_mission!.status == InterventionStatus.completed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.secondaryColor),
            SizedBox(width: 8),
            Text(
              'Mission terminée avec succès',
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================
  // Common Widgets
  // ============================================
  Widget _buildStatusBadge() {
    final color = _getStatusColor(_mission!.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getStatusIcon(_mission!.status), color: color),
          const SizedBox(width: 8),
          Text(
            _mission!.status.label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Helpers
  // ============================================
  Color _getStatusColor(InterventionStatus status) {
    switch (status) {
      case InterventionStatus.scheduled:
        return Colors.blue;
      case InterventionStatus.inProgress:
        return Colors.amber.shade700;
      case InterventionStatus.completed:
        return AppTheme.secondaryColor;
      case InterventionStatus.cancelled:
        return AppTheme.errorColor;
      case InterventionStatus.rescheduled:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(InterventionStatus status) {
    switch (status) {
      case InterventionStatus.scheduled:
        return Icons.schedule;
      case InterventionStatus.inProgress:
        return Icons.play_circle;
      case InterventionStatus.completed:
        return Icons.check_circle;
      case InterventionStatus.cancelled:
        return Icons.cancel;
      case InterventionStatus.rescheduled:
        return Icons.refresh;
    }
  }

  String _formatTimeShort(String? time) {
    if (time == null) return '--:--';
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }

  String _formatDisplayDate(String date) {
    try {
      final dt = DateTime.parse(date);
      final months = [
        '',
        'Janvier',
        'Février',
        'Mars',
        'Avril',
        'Mai',
        'Juin',
        'Juillet',
        'Août',
        'Septembre',
        'Octobre',
        'Novembre',
        'Décembre',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return date;
    }
  }
}
