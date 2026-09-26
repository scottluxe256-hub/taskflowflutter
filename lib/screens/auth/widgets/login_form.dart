import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../auth_page.dart'; // Buat ngambil enum AuthView

class LoginForm extends StatefulWidget {
  final Function(AuthView) onSwitchView;

  const LoginForm({super.key, required this.onSwitchView});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _showPass = false;
  bool _loading = false;
  String? _errorMsg;

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // Kalau sukses, listener di main.dart otomatis bakal ngebawa user ke Dashboard (logic App.tsx lu)
    } on AuthException catch (e) {
      setState(() {
        _errorMsg = e.message == "Invalid login credentials" 
            ? "Email atau password salah." 
            : e.message;
      });
    } catch (e) {
      setState(() {
        _errorMsg = "Terjadi kesalahan tak terduga.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error Message
        if (_errorMsg != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _errorMsg!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          
        // Input Email
        const Text("Email", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Masukkan email Anda",
            hintStyle: const TextStyle(color: Colors.black38),
            prefixIcon: const Icon(Icons.person_outline, size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white.withOpacity(0.95),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2)),
          ),
        ),
        const SizedBox(height: 16),

        // Input Password
        const Text("Password", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: !_showPass,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Masukkan password",
            hintStyle: const TextStyle(color: Colors.black38),
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.95),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2)),
          ),
        ),
        
        // Tombol Lupa Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => widget.onSwitchView(AuthView.forgot),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
            child: const Text("Lupa password?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
        ),
        const SizedBox(height: 8),

        // Tombol Login
        ElevatedButton(
          onPressed: _loading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            disabledBackgroundColor: Colors.purple.shade300,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Login", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        
        const SizedBox(height: 16),
        
        // Link Pindah ke Register
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Belum punya akun? ", style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () => widget.onSwitchView(AuthView.register),
              child: const Text("Daftar sekarang", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
          ],
        ),
      ],
    );
  }
}
