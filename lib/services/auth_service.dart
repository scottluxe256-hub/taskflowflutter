import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<void> requestPasswordOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> verifyPasswordOtp(String email, String otp) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.recovery, 
    );
  }

  Future<void> setNewPassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<AuthResponse> signUp(String email, String password, Map<String, dynamic> data) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // --- OAUTH BROWSER (GOOGLE, GITHUB, DLL) ---
  Future<void> signInWithOAuth(OAuthProvider provider) async {
    // Semua provider (termasuk Google) otomatis diarahkan via Browser Supabase
    await _supabase.auth.signInWithOAuth(
      provider,
      redirectTo: 'io.supabase.flutter://callback', 
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
