import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/sweet_alert.dart';

class SecurityDangerCard extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onLogout;
  const SecurityDangerCard({super.key, required this.isDarkMode, required this.onLogout});

  @override
  State<SecurityDangerCard> createState() => _SecurityDangerCardState();
}

class _SecurityDangerCardState extends State<SecurityDangerCard> {
  bool _showChangePass = false;
  String _step = "sending_otp"; 
  String _email = "";
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = "";
  bool _showPass = false;

  void _initPasswordReset() async {
    setState(() { _showChangePass = true; _step = "sending_otp"; _errorMsg = ""; });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) throw Exception("Gagal mendapatkan email user.");
      _email = user!.email!;
      await Supabase.instance.client.auth.resetPasswordForEmail(_email);
      setState(() => _step = "otp");
    } catch (e) {
      setState(() { _errorMsg = "Gagal kirim OTP: $e"; _step = "error"; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 8) { setState(() => _errorMsg = "OTP harus 8 digit"); return; }
    setState(() { _isLoading = true; _errorMsg = ""; });
    try {
      await Supabase.instance.client.auth.verifyOTP(email: _email, token: _otpCtrl.text, type: OtpType.recovery);
      setState(() => _step = "new_password");
    } catch (e) {
      setState(() => _errorMsg = "Kode OTP salah/kadaluarsa.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_passCtrl.text.length < 6) { setState(() => _errorMsg = "Minimal 6 karakter"); return; }
    setState(() { _isLoading = true; _errorMsg = ""; });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _passCtrl.text));
      setState(() => _showChangePass = false);
      if (mounted) SweetAlert.show(context: context, title: "Berhasil!", message: "Password Anda berhasil diperbarui. 🚀", isSuccess: true, isDarkMode: widget.isDarkMode);
    } catch (e) {
      setState(() => _errorMsg = "Gagal menyimpan password baru.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleDeleteAccount() {
    SweetAlert.show(
      context: context, title: "Hapus Akun?", message: "Yakin ingin menghapus akun permanen? Data tidak bisa kembali.", isSuccess: false, isDarkMode: widget.isDarkMode, showCancel: true,
      onConfirm: () async {
        try {
          await Supabase.instance.client.rpc("delete_user_account");
          widget.onLogout();
        } catch (e) {
          debugPrint("Gagal hapus akun: $e");
        }
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Keamanan Akun", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
          
          _buildActionRow("Ganti Password", "Perbarui dengan OTP email", Icons.key, _showChangePass ? "Tutup Form" : "Ganti Password", Colors.purpleAccent, isDark, () {
            if (_showChangePass) setState(() => _showChangePass = false); else _initPasswordReset();
          }),
          
          if (_showChangePass) _buildOtpForm(isDark),
          const SizedBox(height: 16),
          _buildActionRow("Hapus Akun", "Hapus akun secara permanen", Icons.delete_forever, "Hapus Akun", Colors.redAccent, isDark, _handleDeleteAccount),
          
          const SizedBox(height: 16),
          // TOMBOL LOG OUT BARU
          _buildActionRow("Log Out", "Keluar dari sesi saat ini", Icons.logout, "Log Out", Colors.orange, isDark, widget.onLogout),
        ],
      ),
    );
  }

  Widget _buildOtpForm(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? Colors.blueGrey.shade800.withOpacity(0.5) : Colors.purple.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.purpleAccent.withOpacity(0.3) : Colors.purple.shade200)),
      child: Column(
        children: [
          if (_errorMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
          if (_step == "sending_otp") const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
          if (_step == "otp") ...[
            Text("Masukkan 8-digit OTP yang dikirim ke\n$_email", textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            TextField(controller: _otpCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 8, style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold), decoration: InputDecoration(counterText: "", filled: true, fillColor: isDark ? Colors.black26 : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => setState(() => _showChangePass = false), child: Text("Batal", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)))),
                Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Verifikasi", style: TextStyle(color: Colors.white)))),
              ],
            )
          ],
          if (_step == "new_password") ...[
            TextField(controller: _passCtrl, obscureText: !_showPass, decoration: InputDecoration(hintText: "Password Baru", filled: true, fillColor: isDark ? Colors.black26 : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 16), onPressed: () => setState(() => _showPass = !_showPass)))),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _isLoading ? null : _updatePassword, style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Simpan Password", style: TextStyle(color: Colors.white))),
          ]
        ],
      ),
    );
  }

  Widget _buildActionRow(String title, String subtitle, IconData icon, String btnText, Color color, bool isDark, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))]),
                Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          ),
          // UKURAN DIBIKIN FIX 140 BIAR SIMETRIS
          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1), 
                elevation: 0, 
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: color.withOpacity(0.3))
                )
              ),
              child: Text(btnText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            ),
          )
        ],
      ),
    );
  }
}
