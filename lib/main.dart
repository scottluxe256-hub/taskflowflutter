import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
// import 'screens/auth/auth_page.dart'; // Nanti di-uncomment kalau UI udah jadi

Future<void> main() async {
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
      theme: ThemeData.dark(), // Pakai tema gelap ala TaskFlow
      home: const Scaffold(body: Center(child: Text("Supabase Ready!"))), // Nanti diganti jadi AuthPage
    );
  }
}
