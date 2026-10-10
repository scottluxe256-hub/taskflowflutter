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

  // Fungsi dinamis untuk berpindah tab tanpa menumpuk layar baru
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Daftarkan semua halaman beserta jalur navigasinya
  late final List<Widget> _pages = [
    DashboardPage(
      onNavigateToTasks: () => _onItemTapped(1),    // Arahkan ke Tab Tugas
      onNavigateToProfile: () => _onItemTapped(3),  // Arahkan ke Tab Profil
    ),
    TasksPage(
      onNavigateToProfile: () => _onItemTapped(3),  // Arahkan ke Tab Profil
    ),
    CalendarPage(
      onNavigateToTasks: () => _onItemTapped(1),    // Arahkan ke Tab Tugas
      onNavigateToProfile: () => _onItemTapped(3),  // Arahkan ke Tab Profil
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
        onDestinationSelected: _onItemTapped,
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
