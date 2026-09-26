import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_page.dart';

class RegisterForm extends StatefulWidget {
  final Function(AuthView) onSwitchView;
  const RegisterForm({super.key, required this.onSwitchView});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _showPass = false;
  bool _showConfirmPass = false;
  bool _agree = false;
  bool _loading = false;
  String? _errorMsg;
  String? _successMsg;

  Future<void> _handleRegister() async {
    setState(() {
      _errorMsg = null;
      _successMsg = null;
    });

    if (!_agree) {
      setState(() => _errorMsg = "Anda harus menyetujui Syarat & Ketentuan.");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMsg = "Konfirmasi password tidak cocok.");
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
        },
      );

      if (res.session == null) {
        setState(() => _successMsg = "Pendaftaran berhasil! Silakan cek email Anda.");
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) widget.onSwitchView(AuthView.login);
        });
      }
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = "Terjadi kesalahan sistem.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildInput(String label, IconData icon, TextEditingController controller, {bool isPassword = false, bool? isVisible, VoidCallback? toggleVisibility}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: isPassword && !(isVisible ?? false),
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Masukkan $label",
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: Icon(icon, size: 20, color: Colors.grey),
              suffixIcon: isPassword 
                ? IconButton(icon: Icon((isVisible ?? false) ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey), onPressed: toggleVisibility) 
                : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.95),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMsg != null)
          Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)), child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        if (_successMsg != null)
          Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)), child: Text(_successMsg!, style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),

        _buildInput("Nama Lengkap", Icons.person_outline, _nameController),
        _buildInput("Email", Icons.mail_outline, _emailController),
        _buildInput("Username", Icons.alternate_email, _usernameController),
        _buildInput("Password", Icons.lock_outline, _passwordController, isPassword: true, isVisible: _showPass, toggleVisibility: () => setState(() => _showPass = !_showPass)),
        _buildInput("Konfirmasi Password", Icons.lock_outline, _confirmPasswordController, isPassword: true, isVisible: _showConfirmPass, toggleVisibility: () => setState(() => _showConfirmPass = !_showConfirmPass)),

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agree,
                activeColor: Colors.purple,
                onChanged: (val) => setState(() => _agree = val ?? false),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("Saya setuju dengan Syarat & Ketentuan dan Kebijakan Privasi", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _loading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, disabledBackgroundColor: Colors.purple.shade300, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Daftar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Sudah punya akun? ", style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () => widget.onSwitchView(AuthView.login),
              child: const Text("Login sekarang", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
          ],
        ),
      ],
    );
  }
}
