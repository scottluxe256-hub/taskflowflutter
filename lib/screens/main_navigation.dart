import 'package:flutter/material.dart';
import 'dashboard/dashboard_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Placeholder untuk 4 halaman lu (Nanti kita ganti sama file UI aslinya)
  final List<Widget> _pages = [
    const DashboardPage(),
    const Center(child: Text("Tampilan Tugas Saya", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    const Center(child: Text("Tampilan Kalender", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
    const Center(child: Text("Tampilan Profil", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ganti warna dasar aplikasi lu
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
        backgroundColor: Colors.white,
        elevation: 10,
        indicatorColor: Colors.purple.shade100, // Warna kapsul animasinya
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.dashboard, color: Colors.purple),
            label: 'Dashboard', // Label wajib ada di kode, tapi gak bakal ditampilin
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.task_alt, color: Colors.purple),
            label: 'Tugas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.purple),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.grey),
            selectedIcon: Icon(Icons.person, color: Colors.purple),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
