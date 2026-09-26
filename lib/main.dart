import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import config dan halaman Auth
import 'core/config/supabase_config.dart';
import 'screens/auth/auth_page.dart';

Future<void> main() async {
  // Wajib dipanggil sebelum inisialisasi plugin native kayak Supabase
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase (Persis kayak createClient di React)
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow',
      theme: ThemeData(
        // Biar aksen warna aplikasinya otomatis senada sama warna ungu TaskFlow lu
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      // Langsung arahin ke bosnya halaman login
      home: const AuthPage(), 
    );
  }
}
