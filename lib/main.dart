import 'dart:async';
import 'dart:ui'; // Wajib diimport buat efek Blur
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'screens/auth/auth_page.dart';
import 'screens/main_navigation.dart';

// 1. INI PANEL LISTRIK PUSAT KITA (Global State) untuk Tema
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TaskFlow',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: currentMode, 
          // GERBANG PERTAMA SEKARANG ADALAH SPLASH SCREEN
          home: const SplashScreen(), 
        );
      },
    );
  }
}

// ==========================================
// 2. WIDGET SPLASH SCREEN (Animasi Aurora 3 Detik)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  
  // Controller buat Aurora
  late AnimationController _auroraController;
  late Animation<Alignment> _animAwan1;
  late Animation<Alignment> _animAwan2;

  @override
  void initState() {
    super.initState();
    
    // Setup Animasi Aurora (Berjalan cepat selama 3 detik)
    _auroraController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 3)
    );
    
    // Awan 1 gerak dari kiri atas ke kanan bawah
    _animAwan1 = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.bottomRight)
        .animate(CurvedAnimation(parent: _auroraController, curve: Curves.easeInOutSine));
        
    // Awan 2 gerak dari kanan bawah ke kiri atas
    _animAwan2 = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.topLeft)
        .animate(CurvedAnimation(parent: _auroraController, curve: Curves.easeInOutSine));
    
    // Gas mulai animasi awan!
    _auroraController.forward();

    // Mulai animasi Fade In Logo setelah sedikit delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    // Mulai animasi Fade Out Logo di detik ke-2.5
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _opacity = 0.0);
    });

    // Pindah ke AuthGate di detik ke-3 dengan transisi fade halus
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background fix hitam pekat
      body: Stack(
        children: [
          // EFEK AURORA AWAN
          AnimatedBuilder(
            animation: _auroraController,
            builder: (context, child) {
              return Stack(
                children: [
                  Align(
                    alignment: _animAwan1.value,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Colors.white.withOpacity(0.15), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: _animAwan2.value,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // EFEK BLUR (BIAR AWANNYA JADI SOFT KAYAK AURORA BENERAN)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),

          // KONTEN LOGO FADE IN / FADE OUT
          Center(
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Aplikasi
                  Image.asset('assets/images/logo.webp', width: 100, height: 100),
                  const SizedBox(height: 16),
                  // Teks Task Flow
                  const Text(
                    "Task Flow", 
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.white, // Teks fix putih menyesuaikan bg hitam
                      letterSpacing: 1.2,
                    )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. AUTH GATE (Pengecek Sesi)
// ==========================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const MainNavigation();
    }
    return const AuthPage();
  }
}
