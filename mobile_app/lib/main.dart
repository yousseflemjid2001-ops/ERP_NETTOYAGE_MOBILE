import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'pages/auth/login_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/missions/missions_page.dart';
import 'pages/missions/mission_detail_page.dart';
import 'pages/attendance/attendance_page.dart';
import 'pages/absences/absences_page.dart';
import 'pages/profile/profile_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Nettoyage Plus - Agent',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: auth.isLoading
                ? const _SplashScreen()
                : auth.isAuthenticated
                    ? const MainNavigation()
                    : const LoginPage(),
            onGenerateRoute: (settings) {
              if (settings.name == '/mission-detail') {
                final missionId = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (_) =>
                      MissionDetailPage(missionId: missionId),
                );
              }
              return null;
            },
          );
        },
      ),
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

  final List<Widget> _pages = const [
    DashboardPage(),
    MissionsPage(),
    AttendancePage(),
    AbsencesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
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
          onTap: (index) => setState(() => _currentIndex = index),
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
  }
}
