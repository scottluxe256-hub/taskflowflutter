import 'package:flutter/material.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';
import 'widgets/forgot_password_form.dart';
import 'widgets/reset_password_form.dart';

enum AuthView { login, register, forgot, reset }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthView _currentView = AuthView.login;

  void _switchView(AuthView view) {
    setState(() {
      _currentView = view;
    });
  }

  // Map untuk judul dan deskripsi dinamis (Nyontek dari React lu)
  final Map<AuthView, Map<String, String>> _headerTitles = {
    AuthView.login: {
      'title': 'Selamat Datang Kembali!',
      'desc': 'Login untuk melanjutkan ke akun Anda'
    },
    AuthView.register: {
      'title': 'Buat Akun Baru',
      'desc': 'Daftar untuk mulai menggunakan TaskFlow'
    },
    AuthView.forgot: {
      'title': 'Lupa Password?',
      'desc': 'Masukkan email Anda untuk menerima instruksi pemulihan'
    },
    AuthView.reset: {
      'title': 'Atur Ulang Password',
      'desc': 'Langkah terakhir untuk mengamankan akun Anda.'
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND UTAMA RESPONSIVE
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_mobile.webp', // Diubah jadi webp
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          
          // 2. KONTEN TENGAH (CARD)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 50,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // BACKGROUND CARD
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/bg_card.webp', // Diubah jadi webp
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      
                      // ISI KONTEN CARD
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // LOGO & HEADER
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/images/logo.webp', width: 32, height: 32), // Sesuaikan nama icon lu
                                const SizedBox(width: 8),
                                const Text(
                                  'Task',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                                ),
                                const Text(
                                  'Flow',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.purple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _headerTitles[_currentView]!['title']!,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _headerTitles[_currentView]!['desc']!,
                              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            
                            // DYNAMIC FORM RENDER
                            if (_currentView == AuthView.login)
                              LoginForm(onSwitchView: _switchView),
                            if (_currentView == AuthView.register)
                              RegisterForm(onSwitchView: _switchView),
                            if (_currentView == AuthView.forgot)
                              ForgotPasswordForm(onSwitchView: _switchView),
                            if (_currentView == AuthView.reset)
                              ResetPasswordForm(onSwitchView: _switchView),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
