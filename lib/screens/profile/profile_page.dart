import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_flow/main.dart'; 
import '../../utils/cloudinary_helper.dart'; 
import '../../utils/sweet_alert.dart';
import '../auth/auth_page.dart'; 

import 'widgets/profile_header_card.dart';
import 'widgets/personal_info_card.dart';
import 'widgets/active_sessions_card.dart';
import 'widgets/system_preferences_card.dart';
import 'widgets/security_danger_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isSavingBio = false;
  
  Map<String, dynamic> _userData = {
    'name': 'Loading...', 'username': '', 'email': '', 'bio': '', 'avatarUrl': '',
    'badge': 'Initiator', 'stats': {'totalXP': '0 XP', 'profession': 'Pelajar', 'joinedDate': '-'}
  };

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profileRes = await Supabase.instance.client.from('profiles').select('*').eq('id', user.id).maybeSingle();
      final meta = user.userMetadata;
      
      final xp = (profileRes != null && profileRes['total_xp'] != null) ? profileRes['total_xp'] as int : 0;
      String badgeName = xp > 1000 ? "Mastermind" : (xp > 200 ? "Executor" : "Initiator");

      final rawDate = profileRes?['created_at'] ?? user.createdAt;
      final d = DateTime.parse(rawDate).toLocal();
      const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Ags", "Sep", "Okt", "Nov", "Des"];
      final joinDate = "${months[d.month - 1]} ${d.year}";
      
      final displayName = profileRes?['full_name'] ?? meta?['full_name'] ?? user.email?.split('@')[0] ?? "User";
      final defaultAvatar = "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=8b5cf6&color=fff&bold=true";
      
      String avatar = profileRes?['avatar_url'] ?? meta?['avatar_url'] ?? meta?['picture'] ?? "";
      if (avatar.trim().isEmpty) avatar = defaultAvatar;

      setState(() {
        _userData = {
          'name': displayName, 
          'username': profileRes?['username'] ?? "", 
          'email': user.email ?? "", 
          'bio': profileRes?['bio'] ?? "", 
          'avatarUrl': avatar,
          'badge': badgeName, 
          'stats': {
            'totalXP': '${xp.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} XP', 
            'profession': profileRes?['profession'] ?? "Pelajar", 
            'joinedDate': joinDate
          }
        };
      });
      profileNotifier.value = {'name': displayName, 'avatar': avatar};
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAutoUploadImage(File file) async {
    setState(() => _isUploadingAvatar = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final rawUrl = await CloudinaryHelper.uploadToCloudinary(file);
      if (rawUrl == null) throw Exception("Gagal upload gambar");
      
      final finalAvatarUrl = CloudinaryHelper.getOptimizedImageUrl(rawUrl);
      CloudinaryHelper.deleteOldImage(_userData['avatarUrl']);
      await Supabase.instance.client.from('profiles').update({'avatar_url': finalAvatarUrl}).eq('id', user!.id);
      
      setState(() => _userData['avatarUrl'] = finalAvatarUrl);
      profileNotifier.value = {'name': _userData['name'], 'avatar': finalAvatarUrl};
      
      if (mounted) SweetAlert.show(context: context, title: "Foto Diperbarui! 🎉", message: "Foto profil Anda berhasil diubah.", isSuccess: true, isDarkMode: Theme.of(context).brightness == Brightness.dark);
    } catch (e) { debugPrint("Gagal ganti foto: $e"); } finally { if (mounted) setState(() => _isUploadingAvatar = false); }
  }

  Future<void> _handleAutoSaveProfession(String newProfession) async {
    try { await Supabase.instance.client.from('profiles').update({'profession': newProfession}).eq('id', Supabase.instance.client.auth.currentUser!.id);
      setState(() => _userData['stats']['profession'] = newProfession);
    } catch (e) {}
  }

  Future<void> _handleSaveBio(String name, String username, String bio) async {
    setState(() => _isSavingBio = true);
    try {
      await Supabase.instance.client.from('profiles').update({'full_name': name, 'username': username, 'bio': bio}).eq('id', Supabase.instance.client.auth.currentUser!.id);
      setState(() { _userData['name'] = name; _userData['username'] = username; _userData['bio'] = bio; });
      profileNotifier.value = {'name': name, 'avatar': _userData['avatarUrl']};
      if (mounted) SweetAlert.show(context: context, title: "Tersimpan!", message: "Biodata berhasil diperbarui.", isSuccess: true, isDarkMode: Theme.of(context).brightness == Brightness.dark);
    } catch (e) {} finally { if (mounted) setState(() => _isSavingBio = false); }
  }

  void _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const AuthPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // BACKGROUND STATIS (Tidak terpengaruh keyboard)
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage(isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp'), fit: BoxFit.cover),
          ),
        ),
        // SCAFFOLD UTAMA
        Scaffold(
          backgroundColor: Colors.transparent, 
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: true, 
          appBar: AppBar(
            backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85), elevation: 0, titleSpacing: 16,
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text('Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                  const Text('Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
                  const SizedBox(width: 8),
                  Text('- v2.4 -', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
            actions: [
              IconButton(icon: Icon(isDarkMode ? Icons.dark_mode : Icons.wb_sunny, color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600), onPressed: () => themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark),
              Padding(
                padding: const EdgeInsets.only(right: 16.0, left: 4.0),
                child: ValueListenableBuilder<Map<String, String>>(
                  valueListenable: profileNotifier,
                  builder: (context, profile, child) {
                    final avatar = profile['avatar'] ?? '';
                    final name = profile['name'] ?? 'U';
                    return CircleAvatar(
                      radius: 16, backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 14)) : null,
                    );
                  },
                ),
              )
            ],
          ),
          body: SafeArea(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) : RefreshIndicator(
              onRefresh: _fetchProfileData, color: Colors.purpleAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pengaturan Profil 👤", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text("Kelola informasi akun dan preferensimu.", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    ProfileHeaderCard(user: _userData, isDarkMode: isDarkMode, onImageSelect: _handleAutoUploadImage, onProfessionChange: _handleAutoSaveProfession, isUploadingAvatar: _isUploadingAvatar),
                    const SizedBox(height: 16),
                    PersonalInfoCard(user: _userData, isDarkMode: isDarkMode, onSave: _handleSaveBio, isSaving: _isSavingBio),
                    const SizedBox(height: 16),
                    ActiveSessionsCard(isDarkMode: isDarkMode),
                    const SizedBox(height: 16),
                    SystemPreferencesCard(isDarkMode: isDarkMode),
                    const SizedBox(height: 16),
                    SecurityDangerCard(isDarkMode: isDarkMode, onLogout: _handleLogout),
                    const SizedBox(height: 40), 
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
