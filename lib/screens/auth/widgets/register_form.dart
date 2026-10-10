import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart'; // <-- IMPORT BARU
import '../../../services/auth_service.dart';
import '../auth_page.dart';

const String googleSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" /><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" /><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" /><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" /></svg>''';
const String githubSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#24292F" fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" /></svg>''';

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
  final _authService = AuthService();
  
  bool _showPass = false, _showConfirmPass = false, _agree = false, _loading = false;
  String? _errorMsg, _successMsg;

  Future<void> _handleRegister() async {
    setState(() { _errorMsg = null; _successMsg = null; });
    if (!_agree) { setState(() => _errorMsg = "Anda harus menyetujui Syarat & Ketentuan."); return; }
    if (_passwordController.text != _confirmPasswordController.text) { setState(() => _errorMsg = "Konfirmasi password tidak cocok."); return; }
    setState(() => _loading = true);

    try {
      final res = await _authService.signUp(_emailController.text.trim(), _passwordController.text, {'full_name': _nameController.text.trim(), 'username': _usernameController.text.trim()});
      if (res.session == null) {
        setState(() => _successMsg = "Pendaftaran berhasil! Silakan cek email Anda.");
        Future.delayed(const Duration(seconds: 3), () { if (mounted) widget.onSwitchView(AuthView.login); });
      }
    } on AuthException catch (e) { setState(() => _errorMsg = e.message); } 
    catch (e) { setState(() => _errorMsg = "Terjadi kesalahan sistem."); } 
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _handleOAuthLogin(OAuthProvider provider) async {
    setState(() { _loading = true; _errorMsg = null; });
    try { await _authService.signInWithOAuth(provider); } 
    catch (e) { setState(() => _errorMsg = "Gagal login dengan ${provider.name}."); } 
    finally { if (mounted) setState(() => _loading = false); }
  }

  Widget _buildInput(String label, IconData icon, TextEditingController controller, {bool isPassword = false, bool? isVisible, VoidCallback? toggleVisibility}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(controller: controller, obscureText: isPassword && !(isVisible ?? false), style: const TextStyle(color: Colors.black87, fontSize: 14), decoration: InputDecoration(hintText: "Masukkan $label", hintStyle: const TextStyle(color: Colors.black38), prefixIcon: Icon(icon, size: 20, color: Colors.grey), suffixIcon: isPassword ? IconButton(icon: Icon((isVisible ?? false) ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey), onPressed: toggleVisibility) : null, filled: true, fillColor: Colors.white.withOpacity(0.95), contentPadding: const EdgeInsets.symmetric(vertical: 12), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMsg != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)), child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        if (_successMsg != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)), child: Text(_successMsg!, style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),

        _buildInput("Nama Lengkap", Icons.person_outline, _nameController),
        _buildInput("Email", Icons.mail_outline, _emailController),
        _buildInput("Username", Icons.alternate_email, _usernameController),
        _buildInput("Password", Icons.lock_outline, _passwordController, isPassword: true, isVisible: _showPass, toggleVisibility: () => setState(() => _showPass = !_showPass)),
        _buildInput("Konfirmasi Password", Icons.lock_outline, _confirmPasswordController, isPassword: true, isVisible: _showConfirmPass, toggleVisibility: () => setState(() => _showConfirmPass = !_showConfirmPass)),

        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [SizedBox(width: 24, height: 24, child: Checkbox(value: _agree, activeColor: Colors.purple, onChanged: (val) => setState(() => _agree = val ?? false))), const SizedBox(width: 8), const Expanded(child: Text("Saya setuju dengan Syarat & Ketentuan dan Kebijakan Privasi", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87)))]),
        const SizedBox(height: 16),

        ElevatedButton(onPressed: _loading ? null : _handleRegister, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, disabledBackgroundColor: Colors.purple.shade300, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Daftar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
        
        const SizedBox(height: 16),
        Row(children: [Expanded(child: Divider(color: Colors.grey.shade300)), const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0), child: Text("atau daftar dengan", style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold))), Expanded(child: Divider(color: Colors.grey.shade300))]),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _handleOAuthLogin(OAuthProvider.google),
                icon: SvgPicture.string(googleSvg, width: 18, height: 18), // <-- LOGO GOOGLE ORIGINAL
                label: const Text("Google", style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _handleOAuthLogin(OAuthProvider.github),
                icon: SvgPicture.string(githubSvg, width: 18, height: 18), // <-- LOGO GITHUB ORIGINAL
                label: const Text("GitHub", style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Sudah punya akun? ", style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)), GestureDetector(onTap: () => widget.onSwitchView(AuthView.login), child: const Text("Login sekarang", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)))]),
      ],
    );
  }
}
