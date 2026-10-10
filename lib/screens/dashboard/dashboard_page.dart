import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:task_flow/main.dart'; 
import '../tasks/widgets/task_item.dart'; 
import '../../utils/sweet_alert.dart'; 
import 'package:task_flow/widgets/notification_bell.dart';
import '../profile/profile_page.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback onNavigateToTasks;
  final VoidCallback onNavigateToProfile;

  const DashboardPage({super.key, required this.onNavigateToTasks, required this.onNavigateToProfile});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = "User";
  String _avatarUrl = "";
  bool _isLoading = true;
  
  int _totalTasks = 0;
  int _todayTasksCount = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;
  
  String _weatherTemp = "--°C"; 
  String _weatherLocation = "memuat..."; // Teks loading sesuai instruksi
  
  List<dynamic> _allTasks = [];
  List<dynamic> _todayTasks = [];
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  
  RealtimeChannel? _taskChannel;
  RealtimeChannel? _profileChannel; 

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _initLocation();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _taskChannel = Supabase.instance.client
        .channel('dashboard_tasks_sync')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'tasks', callback: (payload) => _fetchDashboardData())
        .subscribe();
        
    _profileChannel = Supabase.instance.client
        .channel('dashboard_profiles_sync')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'profiles', callback: (payload) => _fetchDashboardData())
        .subscribe();
  }

  @override
  void dispose() {
    _timer.cancel();
    if (_taskChannel != null) Supabase.instance.client.removeChannel(_taskChannel!);
    if (_profileChannel != null) Supabase.instance.client.removeChannel(_profileChannel!);
    super.dispose();
  }

  // MENGAMBIL LOKASI PRESISI (VILLAGE/TOWN) VIA NOMINATIM OPENSTREETMAP
  Future<void> _fetchWeatherAndLocation([double lat = -6.8580, double lon = 107.9271]) async {
    try {
      final weatherRes = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'));
      if (weatherRes.statusCode == 200 && mounted) {
        setState(() => _weatherTemp = "${json.decode(weatherRes.body)['current_weather']['temperature'].round()}°C");
      }
      
      final geoRes = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=14&addressdetails=1'),
        headers: {'User-Agent': 'TaskFlowApp/1.0'} // Wajib pakai User-Agent di Nominatim
      );
      if (geoRes.statusCode == 200 && mounted) {
        final address = json.decode(geoRes.body)['address'];
        // Mengutamakan desa/kecamatan (seperti Ganeas), lalu kota, kabupaten, provinsi
        final preciseLocation = address['village'] ?? address['suburb'] ?? address['town'] ?? address['city_district'] ?? address['city'] ?? address['county'] ?? "Lokasi Anda";
        setState(() => _weatherLocation = preciseLocation);
      }
    } catch (e) { 
      debugPrint("Error cuaca: $e"); 
      if (mounted) setState(() => _weatherLocation = "Gagal memuat");
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { _fetchWeatherAndLocation(); return; }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) { 
          _fetchWeatherAndLocation(); 
          return; 
        }
      }
      
      // Pakai akurasi tinggi
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _fetchWeatherAndLocation(position.latitude, position.longitude);
    } catch (e) { 
      _fetchWeatherAndLocation(); 
    }
  }

  Future<void> _fetchDashboardData() async {
    if (_todayTasks.isEmpty) setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profileRes = await Supabase.instance.client.from('profiles').select('*').eq('id', user.id).maybeSingle();
        final meta = user.userMetadata;
        final name = profileRes?['full_name'] ?? meta?['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        _avatarUrl = profileRes?['avatar_url'] ?? meta?['avatar_url'] ?? meta?['picture'] ?? "";
        
        final response = await Supabase.instance.client
            .from('tasks')
            .select('*, categories(name, color)')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
            
        final tasks = response as List<dynamic>;
        final todayStr = "${_currentTime.year}-${_currentTime.month.toString().padLeft(2, '0')}-${_currentTime.day.toString().padLeft(2, '0')}";
        
        final visibleTasks = tasks.where((t) => t['is_hidden'] != true).toList();
        final completed = visibleTasks.where((t) => t['is_completed'] == true).toList();
        final pending = visibleTasks.where((t) => t['is_completed'] != true).toList();
        final today = visibleTasks.where((t) => t['due_date'] != null && DateTime.parse(t['due_date'].toString()).toLocal().toIso8601String().startsWith(todayStr)).toList();

        if (mounted) {
          setState(() {
            _userName = name; 
            _allTasks = visibleTasks;
            _totalTasks = visibleTasks.length; 
            _completedTasks = completed.length;
            _pendingTasks = pending.length; 
            _todayTasksCount = today.length; 
            _todayTasks = today;
          });
          profileNotifier.value = {'name': _userName, 'avatar': _avatarUrl};
        }
      }
    } catch (e) { 
      debugPrint("Error dashboard: $e"); 
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  List<Map<String, dynamic>> get _weeklyActivity {
    const labels = ["S", "S", "R", "K", "J", "S", "M"];
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final countCompleted = _allTasks.where((t) {
        if (t['is_completed'] != true || t['due_date'] == null) return false;
        final taskDate = DateTime.tryParse(t['due_date'].toString())?.toLocal();
        if (taskDate == null) return false;
        final taskLocalStr = "${taskDate.year}-${taskDate.month.toString().padLeft(2, '0')}-${taskDate.day.toString().padLeft(2, '0')}";
        return taskLocalStr == dStr;
      }).length;

      final val = countCompleted > 0 ? (countCompleted * 25).clamp(10, 100) : 10;
      return {'day': labels[i], 'val': val, 'count': countCompleted};
    });
  }

  Color _getCategoryColor(String? colorStr, String? name) {
    final s = (colorStr ?? "").toLowerCase();
    final n = (name ?? "").toLowerCase();

    if (s.startsWith('#')) {
      try {
        String hex = s.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }

    if (s.contains("amber") || s.contains("orange") || n == "kerja") return const Color(0xFFF59E0B);
    if (s.contains("blue") || n == "sekolah") return const Color(0xFF3B82F6);
    if (s.contains("emerald") || s.contains("green") || n == "pribadi") return const Color(0xFF10B981);
    if (s.contains("rose") || s.contains("pink") || s.contains("red")) return const Color(0xFFF43F5E);

    return Colors.purpleAccent;
  }

  Future<void> _toggleTaskDone(String id, bool currentStatus) async {
    final newStatus = !currentStatus;
    
    setState(() { 
      final idx = _todayTasks.indexWhere((t) => t['id'] == id); 
      if (idx != -1) _todayTasks[idx]['is_completed'] = newStatus; 
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client.from('profiles').select('total_xp, auto_delete_tasks').eq('id', user.id).maybeSingle();
      bool isAutoDelete = profile?['auto_delete_tasks'] == true;

      final updatePayload = {'is_completed': newStatus};
      if (isAutoDelete && newStatus == true) {
        updatePayload['is_hidden'] = true;
        setState(() => _todayTasks.removeWhere((t) => t['id'] == id)); 
      }

      await Supabase.instance.client.from('tasks').update(updatePayload).eq('id', id);
      
      if (profile != null) {
        int currentXp = profile['total_xp'] != null ? int.parse(profile['total_xp'].toString()) : 0;
        int newXp = newStatus ? currentXp + 10 : currentXp - 10;
        if (newXp < 0) newXp = 0; 
        await Supabase.instance.client.from('profiles').update({'total_xp': newXp}).eq('id', user.id);
      }
      
      if (newStatus && mounted) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        SweetAlert.show(
          context: context, 
          title: isAutoDelete ? "Selesai & Dihapus! 🎉" : "Tugas Selesai! 🎉", 
          message: "Mantap! Lanjutkan semangatmu. (+10 XP)", 
          isSuccess: true, 
          isDarkMode: isDarkMode
        );
      }
    } catch (e) {
      debugPrint("Error update task/xp: $e");
    }
  }

  Widget _buildWeatherIcon(bool isDaytime) {
    return SizedBox(
      width: 26, height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.cloud, color: isDaytime ? Colors.grey.shade400 : Colors.grey.shade600, size: 24),
          Positioned(top: 0, right: 0, child: Icon(isDaytime ? Icons.wb_sunny : Icons.dark_mode, color: isDaytime ? Colors.amber : Colors.indigo.shade300, size: 14)),
        ],
      ),
    );
  }

  Widget _buildAllTasksCard(String title, int count, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.layers, size: 24, color: Colors.purpleAccent), const SizedBox(width: 6), Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black54)))]), const Spacer(), Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)), const SizedBox(width: 4), Text("Tugas", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black38))])])),
          Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withOpacity(0.15), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))), child: const Icon(Icons.layers, color: Colors.purpleAccent, size: 22))
        ],
      ),
    );
  }

  Widget _buildDonutCard(String title, int count, IconData icon, Color color, double progress, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 24, color: color), const SizedBox(width: 6), Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black54)))]), const Spacer(), Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)), const SizedBox(width: 4), Text("Tugas", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black38))])])),
          SizedBox(width: 44, height: 44, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: progress, strokeWidth: 8, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color), strokeCap: StrokeCap.round), Center(child: Text("${(progress * 100).toInt()}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)))]))
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityCard(bool isDarkMode) {
    final activity = _weeklyActivity;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Aktivitas Minggu Ini", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
              Text("Senin - Minggu", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black45)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: activity.map((item) {
                final double barPercent = (item['val'] as num).toDouble();
                final double barHeight = (barPercent / 100) * 80;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic, width: 14, height: barHeight, decoration: BoxDecoration(color: barPercent > 10 ? Colors.purpleAccent : (isDarkMode ? Colors.white12 : Colors.grey.shade300), borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))),
                    const SizedBox(height: 8),
                    Text(item['day'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black45)),
                  ],
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeString = "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isDaytime = _currentTime.hour >= 6 && _currentTime.hour < 18;

    return Container(
      decoration: BoxDecoration(image: DecorationImage(image: AssetImage(isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp'), fit: BoxFit.cover, alignment: Alignment.topCenter)),
      child: Scaffold(
        resizeToAvoidBottomInset: false, backgroundColor: Colors.transparent, extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85), elevation: 0, titleSpacing: 16,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text('Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)), const Text('Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purpleAccent)), const SizedBox(width: 8), Text('- v2.4 -', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)), const SizedBox(width: 8),
                GestureDetector(onTap: () { setState(() => _weatherLocation = "memuat..."); _fetchDashboardData(); _initLocation(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))), child: Row(children: const [Icon(Icons.refresh, size: 14, color: Colors.purpleAccent), SizedBox(width: 4), Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent))]))),
              ],
            ),
          ),
          actions: [
            IconButton(icon: Icon(isDarkMode ? Icons.dark_mode : Icons.wb_sunny, color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600), onPressed: () => themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark),
            NotificationBell(isDarkMode: isDarkMode),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 4.0),
              child: GestureDetector(
                onTap: widget.onNavigateToProfile,
                child: ValueListenableBuilder<Map<String, String>>(
                  valueListenable: profileNotifier,
                  builder: (context, profile, child) {
                    final avatar = profile['avatar'] ?? '';
                    final name = profile['name'] ?? 'U';
                    return CircleAvatar(radius: 16, backgroundColor: Colors.purpleAccent.withOpacity(0.2), backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 14)) : null);
                  },
                ),
              ),
            )
          ],
        ),
        body: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : RefreshIndicator(
                onRefresh: () async { setState(() => _weatherLocation = "memuat..."); await _fetchDashboardData(); await _initLocation(); }, color: Colors.purpleAccent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<Map<String, String>>(valueListenable: profileNotifier, builder: (context, profile, child) => Text("Selamat Datang, ${profile['name']}! 👋", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 4),
                      Text("Berikut ringkasan progres dan agenda tugasmu.", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
                            child: Row(children: [_buildWeatherIcon(isDaytime), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_weatherTemp, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)), SizedBox(width: 85, child: Text(_weatherLocation, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)))])]),
                          ),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]), child: Text(timeString, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.purpleAccent.shade100 : Colors.purpleAccent, letterSpacing: 1, fontFamily: 'monospace'))),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      GridView.count(
                        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildAllTasksCard("Semua Tugas", _totalTasks, isDarkMode),
                          _buildDonutCard("Hari Ini", _todayTasksCount, Icons.local_fire_department, Colors.orange, _totalTasks > 0 ? _todayTasksCount / _totalTasks : 0, isDarkMode),
                          _buildDonutCard("Selesai", _completedTasks, Icons.check_circle, Colors.green, _totalTasks > 0 ? _completedTasks / _totalTasks : 0, isDarkMode),
                          _buildDonutCard("Belum Selesai", _pendingTasks, Icons.error_outline, Colors.red, _totalTasks > 0 ? _pendingTasks / _totalTasks : 0, isDarkMode),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Fokus Hari Ini", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                                GestureDetector(onTap: widget.onNavigateToTasks, child: const Text("Lihat Semua", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _todayTasks.isEmpty
                              ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text("Tidak ada agenda tugas hari ini ☕", textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 12))))
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 250),
                                  child: RawScrollbar(
                                    thumbColor: Colors.purpleAccent.withOpacity(0.5), radius: const Radius.circular(8), thickness: 4,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero, shrinkWrap: true, physics: const BouncingScrollPhysics(), itemCount: _todayTasks.length,
                                      itemBuilder: (context, index) {
                                        final task = _todayTasks[index];
                                        final catData = task['categories'];
                                        String catName = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['name'] : (catData is Map ? catData['name'] : "Umum")) ?? "Umum" : "Umum";
                                        String catColorStr = catData != null ? (catData is List && catData.isNotEmpty ? catData[0]['color'] : (catData is Map ? catData['color'] : "")) ?? "" : "";
                                        return TaskItemCard(task: task, isDarkMode: isDarkMode, catName: catName, catColor: _getCategoryColor(catColorStr, catName), onToggle: _toggleTaskDone, showActions: false);
                                      },
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildWeeklyActivityCard(isDarkMode),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
