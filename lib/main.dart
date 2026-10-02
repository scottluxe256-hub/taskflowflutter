import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'screens/auth/auth_page.dart';
import 'screens/main_navigation.dart';

// UBAH DEFAULT JADI LIGHT MODE
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Map<String, String>> profileNotifier = ValueNotifier({'name': 'User', 'avatar': ''});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: currentMode, 
          home: const SplashScreen(), 
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  
  late AnimationController _smokeController;
  late Animation<Alignment> _animKiriAtas;
  late Animation<Alignment> _animKananBawah;
  late Animation<Alignment> _animKananAtas;
  late Animation<Alignment> _animKiriBawah;

  @override
  void initState() {
    super.initState();
    
    _smokeController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    
    _animKiriAtas = Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.bottomRight).animate(CurvedAnimation(parent: _smokeController, curve: Curves.easeInOutSine));
    _animKananBawah = Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.topLeft).animate(CurvedAnimation(parent: _smokeController, curve: Curves.easeInOutSine));
    _animKananAtas = Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomLeft).animate(CurvedAnimation(parent: _smokeController, curve: Curves.easeInOutSine));
    _animKiriBawah = Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topRight).animate(CurvedAnimation(parent: _smokeController, curve: Curves.easeInOutSine));
    
    _smokeController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _opacity = 0.0);
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _smokeController.dispose();
    super.dispose();
  }

  Widget _buildSmoke(Animation<Alignment> anim, double size, double opacity) {
    return Align(
      alignment: anim.value,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Colors.white.withOpacity(opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 1.5;

    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _smokeController,
            builder: (context, child) {
              return Stack(
                children: [
                  _buildSmoke(_animKiriAtas, size, 0.15),
                  _buildSmoke(_animKananBawah, size, 0.1),
                  _buildSmoke(_animKananAtas, size, 0.12),
                  _buildSmoke(_animKiriBawah, size, 0.15),
                ],
              );
            },
          ),
          
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), 
              child: Container(color: Colors.transparent),
            ),
          ),

          Center(
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.webp', width: 100, height: 100),
                  const SizedBox(height: 16),
                  const Text("Task Flow", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainNavigation()));
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthPage()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) return const MainNavigation();
    return const AuthPage();
  }
}
