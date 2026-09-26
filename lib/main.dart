import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'screens/auth/auth_page.dart';
import 'screens/main_navigation.dart';

// 1. INI PANEL LISTRIK PUSAT KITA (Global State) untuk Tema
// Default kita set ikutin tema HP (system)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase tetep aman di sini
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. ValueListenableBuilder memantau perubahan pada themeNotifier
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TaskFlow',
          // Pengaturan tema terang (tetap pakai aksen warna ungu lu)
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          // Pengaturan tema gelap
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: currentMode, // Terapkan tema sesuai saklar
          home: const AuthGate(), // Gerbang pengecek sesi tetep jalan
        );
      },
    );
  }
}

// Komponen ini nggantiin logika App.tsx lu buat deteksi login/logout
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Dengerin perubahan sesi dari Supabase
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // Otomatis arahin ke Dashboard kalau berhasil Login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        // Balikin ke halaman Login kalau Logout
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pengecekan sesi awal pas aplikasi baru dibuka
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const MainNavigation();
    }
    return const AuthPage();
  }
}
