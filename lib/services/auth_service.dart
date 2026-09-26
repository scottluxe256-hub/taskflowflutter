import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // 1. Meminta pengiriman OTP ke Email (Dari auth.ts lu)
  Future<void> requestPasswordOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // 2. Verifikasi OTP yang diketikkan pengguna (Dari auth.ts lu)
  Future<void> verifyPasswordOtp(String email, String otp) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.recovery, // type: 'recovery' di TypeScript
    );
  }

  // 3. Mengubah kata sandi (Dari auth.ts lu)
  Future<void> setNewPassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // --- TAMBAHAN BUAT LOGIN & REGISTER NANTI ---

  // Register
  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Login
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
