import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    // Auto-refresh every 60 seconds
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  /// Called externally when user switches to this tab.
  void refresh() {
    _loadProfile();
  }

  /// Silent refresh without showing loading spinner.
  Future<void> _silentRefresh() async {
    try {
      final profile = await _api.getProfile();
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      _profile = await _api.getProfile();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(user),
                    const SizedBox(height: 24),

                    // Info Cards
                    _buildInfoSection(
                      'Informations personnelles',
                      Icons.person,
                      [
                        _buildInfoTile('Nom', user?.displayName ?? '-'),
                        _buildInfoTile('Email', user?.email ?? '-'),
                        _buildInfoTile('Téléphone', user?.phone ?? '-'),
                        _buildInfoTile('Rôle', user?.role ?? '-'),
                        _buildInfoTile('Statut', user?.status ?? '-'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_profile != null) ...[
                      _buildInfoSection('Contact d\'urgence', Icons.emergency, [
                        _buildInfoTile(
                          'Nom',
                          _profile!['emergencyContact']?['name'] ??
                              'Non renseigné',
                        ),
                        _buildInfoTile(
                          'Téléphone',
                          _profile!['emergencyContact']?['phone'] ??
                              'Non renseigné',
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // Actions
                    _buildActionCard(
                      'Modifier mon profil',
                      Icons.edit,
                      AppTheme.primaryColor,
                      _showEditProfileDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildActionCard(
                      'Changer le mot de passe',
                      Icons.lock_outline,
                      AppTheme.warningColor,
                      () {},
                    ),
                    const SizedBox(height: 8),
                    _buildActionCard(
                      'Se déconnecter',
                      Icons.logout,
                      AppTheme.errorColor,
                      _showLogoutDialog,
                    ),
                    const SizedBox(height: 32),

                    // App Version
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            user?.initials ?? 'A',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.displayName ?? 'Agent',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user?.role ?? 'Agent',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
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

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: color),
        ),
        trailing: Icon(Icons.chevron_right, color: color),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = context.read<AuthProvider>().user;
    final firstNameController = TextEditingController(
      text: user?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: user?.lastName ?? '',
    );
    final phoneController = TextEditingController(text: user?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Modifier mon profil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _api.updateProfile({
                        'firstName': firstNameController.text,
                        'lastName': lastNameController.text,
                        'phone': phoneController.text,
                      });
                      // Refresh user data
                      await _api.getMe();
                      if (mounted) {
                        Navigator.pop(context);
                        _loadProfile();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profil mis à jour !'),
                            backgroundColor: AppTheme.secondaryColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: ${e.toString()}'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
