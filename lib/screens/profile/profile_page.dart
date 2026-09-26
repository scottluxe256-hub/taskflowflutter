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
    'name': 'Loading...', 
    'username': '', 
    'email': '', 
    'bio': '', 
    'avatarUrl': 'https://ui-avatars.com/api/?name=User&background=8b5cf6&color=fff',
    'badge': 'Initiator', 
    'stats': {'totalXP': '0 XP', 'profession': 'Pelajar', 'joinedDate': '-'}
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
      
      final xp = (profileRes != null && profileRes['total_xp'] != null) ? profileRes['total_xp'] as int : 0;
      String badgeName = xp > 1000 ? "Mastermind" : (xp > 200 ? "Executor" : "Initiator");

      final rawDate = profileRes?['created_at'] ?? user.createdAt;
      final d = DateTime.parse(rawDate).toLocal();
      const months = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Ags", "Sep", "Okt", "Nov", "Des"];
      final joinDate = "${months[d.month - 1]} ${d.year}";
      
      final displayName = profileRes?['full_name'] ?? user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? "User";
      final defaultAvatar = "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=8b5cf6&color=fff&bold=true";

      setState(() {
        _userData = {
          'name': displayName, 
          'username': profileRes?['username'] ?? "", 
          'email': user.email ?? "", 
          'bio': profileRes?['bio'] ?? "", 
          'avatarUrl': profileRes?['avatar_url'] ?? defaultAvatar,
          'badge': badgeName, 
          'stats': {
            'totalXP': '${xp.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} XP', 
            'profession': profileRes?['profession'] ?? "Pelajar", 
            'joinedDate': joinDate
          }
        };
      });
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
      if (user == null) return;

      final rawUrl = await CloudinaryHelper.uploadToCloudinary(file);
      if (rawUrl == null) throw Exception("Gagal upload gambar");
      
      final finalAvatarUrl = CloudinaryHelper.getOptimizedImageUrl(rawUrl);
      CloudinaryHelper.deleteOldImage(_userData['avatarUrl']);
      
      await Supabase.instance.client.from('profiles').update({'avatar_url': finalAvatarUrl}).eq('id', user.id);
      
      setState(() => _userData['avatarUrl'] = finalAvatarUrl);
      profileNotifier.value = {'name': _userData['name'], 'avatar': finalAvatarUrl};
      
      if (mounted) {
        SweetAlert.show(context: context, title: "Foto Diperbarui! 🎉", message: "Foto profil Anda berhasil diubah.", isSuccess: true, isDarkMode: Theme.of(context).brightness == Brightness.dark);
      }
    } catch (e) {
      debugPrint("Gagal ganti foto: $e");
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleAutoSaveProfession(String newProfession) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('profiles').update({'profession': newProfession}).eq('id', user.id);
      setState(() => _userData['stats']['profession'] = newProfession);
    } catch (e) {
      debugPrint("Gagal nyimpen profesi: $e");
    }
  }

  Future<void> _handleSaveBio(String name, String username, String bio) async {
    setState(() => _isSavingBio = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      await Supabase.instance.client.from('profiles').update({'full_name': name, 'username': username, 'bio': bio}).eq('id', user.id);
      
      setState(() {
        _userData['name'] = name;
        _userData['username'] = username;
        _userData['bio'] = bio;
      });
      profileNotifier.value = {'name': name, 'avatar': _userData['avatarUrl']};
      
      if (mounted) {
        SweetAlert.show(context: context, title: "Tersimpan!", message: "Biodata berhasil diperbarui.", isSuccess: true, isDarkMode: Theme.of(context).brightness == Brightness.dark);
      }
    } catch (e) {
      debugPrint("Gagal simpan bio: $e");
    } finally {
      if (mounted) setState(() => _isSavingBio = false);
    }
  }

  void _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()), 
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true, 
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
        elevation: 0, 
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              Text('Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
              const Text('Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
              const SizedBox(width: 8),
              Text('- v2.4 -', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _fetchProfileData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                  decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))), 
                  child: Row(children: const [Icon(Icons.refresh, size: 14, color: Colors.purpleAccent), SizedBox(width: 4), Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent))])
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: Icon(isDarkMode ? Icons.dark_mode : Icons.wb_sunny, color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600), onPressed: () => themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: CircleAvatar(
              radius: 16, 
              backgroundColor: Colors.purpleAccent.withOpacity(0.2), 
              backgroundImage: _userData['avatarUrl'].isNotEmpty ? NetworkImage(_userData['avatarUrl']) : null, 
              child: _userData['avatarUrl'].isEmpty ? Text(_userData['name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 14)) : null
            ),
          )
        ],
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage(isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp'), fit: BoxFit.cover)),
        child: SafeArea(
          child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) : RefreshIndicator(
            onRefresh: _fetchProfileData, color: Colors.purpleAccent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
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
    );
  }
}
