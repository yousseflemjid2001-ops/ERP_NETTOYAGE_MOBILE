import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'services/notification_polling_service.dart';
import 'services/offline_service.dart';
import 'services/api_service.dart';
import 'pages/auth/login_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/missions/missions_page.dart';
import 'pages/missions/mission_detail_page.dart';
import 'pages/attendance/attendance_page.dart';
import 'pages/absences/absences_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/messages/conversations_page.dart';
import 'services/mission_polling_service.dart';
import 'pages/notifications/notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch all Flutter framework errors (prevents white screen on error)
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  // Initialisation des notifications locales (sans Firebase)
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('[main] Notification init error (ignored): $e');
  }

  // Démarrage de la surveillance de connectivité
  ConnectivityService().startMonitoring();

  // Sync offline automatique quand la connexion revient
  ConnectivityService().onConnected.listen((_) async {
    final result = await OfflineService().flushQueue(ApiService());
    if (result.hasSync) {
      debugPrint('Offline sync: ${result.synced} action(s) synchronisées');
      await NotificationService().showSyncSuccess(result.synced);
    }
    if (result.hasFailures) {
      debugPrint(
        'Offline sync: ${result.failed} action(s) échouée(s) définitivement',
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: MaterialApp(
        title: 'Nettoyage Plus - Agent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AppRoot(),
        onGenerateRoute: (settings) {
          if (settings.name == '/mission-detail') {
            final missionId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => MissionDetailPage(missionId: missionId),
            );
          }
          if (settings.name == '/notifications') {
            return MaterialPageRoute(builder: (_) => const NotificationsPage());
          }
          return null;
        },
      ),
    );
  }
}

/// Root widget that watches auth state and starts/stops polling services
/// in lifecycle hooks instead of inside build().
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Side effects handled via didUpdateWidget / listener — not here
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (auth.isAuthenticated && !auth.isLoading) {
            MissionPollingService().start();
            NotificationPollingService().start();
          } else if (!auth.isLoading) {
            MissionPollingService().stop();
            NotificationPollingService().stop();
          }
        });

        if (auth.isLoading) return const _SplashScreen();
        if (auth.isAuthenticated) return const MainNavigation();
        return const LoginPage();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cleaning_services_rounded,
                color: AppTheme.primaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nettoyage Plus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final StreamSubscription _notificationSub;

  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey();
  final GlobalKey<MissionsPageState> _missionsKey = GlobalKey();
  final GlobalKey<AttendancePageState> _attendanceKey = GlobalKey();
  final GlobalKey<AbsencesPageState> _absencesKey = GlobalKey();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey();

  late final List<Widget> _pages = [
    DashboardPage(key: _dashboardKey),
    MissionsPage(key: _missionsKey),
    AttendancePage(key: _attendanceKey),
    const ConversationsPage(),
    AbsencesPage(key: _absencesKey),
    ProfilePage(key: _profileKey),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for notification taps to navigate to mission detail
    _notificationSub = NotificationService().onNotificationTap.listen((data) {
      final type = data['type'];
      final missionId = data['missionId'];
      if ((type == 'new_mission' ||
              type == 'mission_updated' ||
              type == 'mission_removed') &&
          missionId != null) {
        // Switch to missions tab
        setState(() => _currentIndex = 1);
        if (type != 'mission_removed') {
          Navigator.pushNamed(context, '/mission-detail', arguments: missionId);
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationSub.cancel();
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    // Refresh the page data when switching tabs
    switch (index) {
      case 0:
        _dashboardKey.currentState?.refresh();
        break;
      case 1:
        _missionsKey.currentState?.refresh();
        break;
      case 2:
        _attendanceKey.currentState?.refresh();
        break;
      // case 3: ConversationsPage already has its own polling
      case 4:
        _absencesKey.currentState?.refresh();
        break;
      case 5:
        _profileKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        return Scaffold(
          body: Column(
            children: [
              // Bandeau "hors ligne"
              if (!connectivity.isOnline)
                Material(
                  color: Colors.orange.shade700,
                  elevation: 2,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.wifi_off, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode hors-ligne — Les actions seront synchronisées dès le retour du réseau.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _pages),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: 'Missions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fingerprint_outlined),
                  activeIcon: Icon(Icons.fingerprint),
                  label: 'Pointage',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_busy_outlined),
                  activeIcon: Icon(Icons.event_busy),
                  label: 'Absences',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
