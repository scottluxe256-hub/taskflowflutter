import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_page.dart';

class ForgotPasswordForm extends StatefulWidget {
  final Function(AuthView) onSwitchView;
  const ForgotPasswordForm({super.key, required this.onSwitchView});

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isOtpStep = false;
  bool _loading = false;
  String? _errorMsg;

  Future<void> _handleSendEmail() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      setState(() => _isOtpStep = true);
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = "Gagal mengirim kode reset.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length < 6) {
      setState(() => _errorMsg = "Masukkan 6 digit kode OTP lengkap.");
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
        type: OtpType.recovery,
      );
      widget.onSwitchView(AuthView.reset);
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = "Kode OTP salah atau kadaluarsa.");
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

        if (!_isOtpStep) ...[
          const Text("Email", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(hintText: "Masukkan email Anda", hintStyle: const TextStyle(color: Colors.black38), prefixIcon: const Icon(Icons.mail_outline, size: 20, color: Colors.grey), filled: true, fillColor: Colors.white.withOpacity(0.95), contentPadding: const EdgeInsets.symmetric(vertical: 12), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2))),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _handleSendEmail,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Kirim Kode OTP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => widget.onSwitchView(AuthView.login),
              child: const Text("Kembali ke Login", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
          )
        ] else ...[
          Text("Kode verifikasi 6-digit telah dikirim ke\n${_emailController.text}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          const Text("Kode OTP", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(color: Colors.black87, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(hintText: "000000", counterText: "", hintStyle: const TextStyle(color: Colors.black38, letterSpacing: 8), prefixIcon: const Icon(Icons.key, size: 20, color: Colors.grey), filled: true, fillColor: Colors.white.withOpacity(0.95), contentPadding: const EdgeInsets.symmetric(vertical: 12), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple, width: 2))),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Verifikasi & Ganti Password", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: () => setState(() => _isOtpStep = false), child: const Text("Ganti Email", style: TextStyle(fontSize: 12, color: Colors.grey))),
              TextButton(onPressed: _loading ? null : _handleSendEmail, child: const Text("Kirim Ulang Kode", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple))),
            ],
          )
        ],
      ],
    );
  }
}
