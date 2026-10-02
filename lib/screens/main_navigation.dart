import 'package:flutter/material.dart';
import './dashboard/dashboard_page.dart';
import './tasks/tasks_page.dart';
import './calendar/calendar_page.dart';
import './profile/profile_page.dart'; 

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Hapus kata 'const' di array ini karena sekarang ada fungsi anonim yang dinamis
  late final List<Widget> _pages = [
    // PERBAIKAN DI SINI: Masukkan onNavigateToTasks ke DashboardPage
    DashboardPage(
      onNavigateToTasks: () {
        setState(() {
          _selectedIndex = 1; // Pindah ke tab Tugas (index 1)
        });
      },
    ),
    const TasksPage(),
    CalendarPage(
      onNavigateToTasks: () {
        setState(() {
          _selectedIndex = 1; 
        });
      },
    ),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: 65,
        backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        elevation: 10,
        indicatorColor: isDarkMode ? Colors.purple.withOpacity(0.3) : Colors.purple.shade100,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
            selectedIcon: const Icon(Icons.dashboard, color: Colors.purple),
            label: 'Dashboard', 
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined, color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
            selectedIcon: const Icon(Icons.task_alt, color: Colors.purple),
            label: 'Tugas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
            selectedIcon: const Icon(Icons.calendar_month, color: Colors.purple),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: isDarkMode ? Colors.grey.shade500 : Colors.grey),
            selectedIcon: const Icon(Icons.person, color: Colors.purple),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
