import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_page.dart';

class ResetPasswordForm extends StatefulWidget {
  final Function(AuthView) onSwitchView;
  const ResetPasswordForm({super.key, required this.onSwitchView});

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _showPass = false;
  bool _showConfirmPass = false;
  bool _loading = false;
  String? _errorMsg;
  String? _successMsg;

  Future<void> _handleSubmit() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMsg = "Konfirmasi password tidak cocok.");
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _errorMsg = "Password minimal 6 karakter.");
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      setState(() => _successMsg = "Password berhasil diperbarui! Mengalihkan ke Login...");
      
      Future.delayed(const Duration(seconds: 2), () async {
        await Supabase.instance.client.auth.signOut();
        if (mounted) widget.onSwitchView(AuthView.login);
      });
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = "Gagal memperbarui password.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

        const Text("Password Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: !_showPass,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(hintText: "Masukkan password baru", hintStyle: const TextStyle(color: Colors.black38), prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.grey), suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey), onPressed: () => setState(() => _showPass = !_showPass)), filled: true, fillColor: Colors.white.withOpacity(0.95), contentPadding: const EdgeInsets.symmetric(vertical: 12), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2))),
        ),
        const SizedBox(height: 16),
        const Text("Ulangi Password Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_showConfirmPass,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(hintText: "Ulangi password baru", hintStyle: const TextStyle(color: Colors.black38), prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.grey), suffixIcon: IconButton(icon: Icon(_showConfirmPass ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey), onPressed: () => setState(() => _showConfirmPass = !_showConfirmPass)), filled: true, fillColor: Colors.white.withOpacity(0.95), contentPadding: const EdgeInsets.symmetric(vertical: 12), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2))),
        ),
        const SizedBox(height: 24),
        
        ElevatedButton(
          onPressed: _loading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Konfirmasi Ganti Password", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => widget.onSwitchView(AuthView.login),
            child: const Text("Masuk sekarang", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
        ),
      ],
    );
  }
}
