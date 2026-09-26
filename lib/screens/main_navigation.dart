import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Sesuaikan path jika beda folder

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Placeholder untuk 4 halaman lu
  final List<Widget> _pages = [
    const DashboardPage(),
    const Center(child: Text("Tampilan Tugas Saya", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    const Center(child: Text("Tampilan Kalender", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    const Center(child: Text("Tampilan Profil", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
  ];

  @override
  Widget build(BuildContext context) {
    // Deteksi mode gelap/terang dari sistem HP
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
        // MURNI CUMA IKON (Tanpa teks sama sekali)
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
