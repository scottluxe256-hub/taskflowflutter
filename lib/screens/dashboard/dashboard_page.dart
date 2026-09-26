import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _userName = "User";
  String _avatarUrl = "";
  bool _isLoading = true;
  
  // Stats
  int _totalTasks = 0;
  int _todayTasksCount = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;
  
  // Weather & Location
  String _weatherTemp = "--°C";
  String _weatherLocation = "Menunggu lokasi...";
  
  List<dynamic> _todayTasks = [];
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _initLocation();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Fungsi Tarik Cuaca (Mirip Web)
  Future<void> _fetchWeatherAndLocation([double lat = -6.8580, double lon = 107.9271]) async {
    try {
      // API Cuaca Open-Meteo
      final weatherRes = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'));
      if (weatherRes.statusCode == 200) {
        final weatherData = json.decode(weatherRes.body);
        if (weatherData['current_weather'] != null && mounted) {
          setState(() {
             _weatherTemp = "${weatherData['current_weather']['temperature'].round()}°C";
          });
        }
      }
      
      // API Lokasi BigDataCloud
      final geoRes = await http.get(Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=id'));
      if (geoRes.statusCode == 200) {
        final geoData = json.decode(geoRes.body);
        if (mounted) {
          setState(() {
             _weatherLocation = geoData['locality'] ?? geoData['city'] ?? geoData['principalSubdivision'] ?? "Sumedang";
          });
        }
      }
    } catch (e) {
      debugPrint("Error cuaca: $e");
    }
  }

  // Cek GPS HP
  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fetchWeatherAndLocation(); // Fallback Sumedang
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _fetchWeatherAndLocation(); // Fallback Sumedang
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      _fetchWeatherAndLocation(position.latitude, position.longitude);
    } catch (e) {
      _fetchWeatherAndLocation(); // Fallback Error
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Coba narik Profile buat dapet Avatar
        try {
          final profileRes = await Supabase.instance.client.from('profiles').select('*').eq('id', user.id).maybeSingle();
          if (profileRes != null && mounted) {
             _avatarUrl = profileRes['avatar_url'] ?? "";
          }
        } catch (_) {}

        final metadata = user.userMetadata;
        final name = metadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        
        final response = await Supabase.instance.client
            .from('tasks')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
            
        final tasks = response as List<dynamic>;
        
        final todayStr = "${_currentTime.year}-${_currentTime.month.toString().padLeft(2, '0')}-${_currentTime.day.toString().padLeft(2, '0')}";
        
        final visibleTasks = tasks.where((t) => t['is_hidden'] != true).toList();
        final completed = visibleTasks.where((t) => t['is_completed'] == true).toList();
        final pending = visibleTasks.where((t) => t['is_completed'] != true).toList();
        final today = visibleTasks.where((t) => t['due_date'] != null && t['due_date'].toString().startsWith(todayStr)).toList();

        if (mounted) {
          setState(() {
            _userName = name;
            _totalTasks = visibleTasks.length;
            _completedTasks = completed.length;
            _pendingTasks = pending.length;
            _todayTasksCount = today.length;
            _todayTasks = today;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color, double progress, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                  const SizedBox(width: 4),
                  Text("Tugas", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black38)),
                ],
              ),
            ],
          ),
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Center(
                  child: Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Widget Spesial: Ikon Awan+Matahari atau Awan+Bulan
  Widget _buildWeatherIcon(bool isDaytime) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.cloud, color: isDaytime ? Colors.grey.shade400 : Colors.grey.shade600, size: 24),
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              isDaytime ? Icons.wb_sunny : Icons.nights_stay,
              color: isDaytime ? Colors.amber : Colors.indigo.shade300,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format Jam MURNI tanpa tulisan WIB
    final timeString = "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Logika Siang/Malam (06:00 - 18:00 = Siang)
    final currentHour = _currentTime.hour;
    final isDaytime = currentHour >= 6 && currentHour < 18;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85),
        elevation: 0,
        title: Row(
          children: [
            Text('Mobile Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white24 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6)
              ),
              child: Text('2.4', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.refresh, size: 20, color: isDarkMode ? Colors.white70 : Colors.black54),
              onPressed: () {
                _fetchDashboardData();
                _initLocation(); // Refresh cuaca juga
              },
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            )
          ],
        ),
        actions: [
          // Tombol Ikon Mode Terang/Gelap (Matahari / Bulan)
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.nights_stay : Icons.wb_sunny, 
              color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pasang trigger state management ganti tema di sini!')));
            },
          ),
          // Foto Profil Tanpa Username
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple.shade100,
              backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
              child: _avatarUrl.isEmpty ? Text(_userName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 14)) : null,
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.purple))
              : RefreshIndicator(
                  onRefresh: _fetchDashboardData,
                  color: Colors.purple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // WIDGET GREETING & CUACA/JAM
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Selamat Datang,\n$_userName! ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text("Berikut agenda tugasmu hari ini.", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            // Glassmorphism Widget Cuaca & Waktu
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.8) : Colors.white.withOpacity(0.85), 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Seksi Cuaca & Lokasi Dinamis
                                  Row(
                                    children: [
                                      _buildWeatherIcon(isDaytime),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_weatherTemp, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                                          SizedBox(
                                            width: 60,
                                            child: Text(_weatherLocation, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Garis Pemisah
                                  Container(
                                    height: 24,
                                    width: 1,
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                                  ),
                                  // Seksi Waktu
                                  Text(
                                    timeString, 
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.purple.shade300 : Colors.purple, letterSpacing: 1, fontFamily: 'monospace')
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // GRID STATISTIK
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildStatCard("Semua Tugas", _totalTasks, Icons.layers, Colors.purple, 1.0, isDarkMode),
                            _buildStatCard("Hari Ini", _todayTasksCount, Icons.local_fire_department, Colors.orange, _totalTasks > 0 ? _todayTasksCount / _totalTasks : 0, isDarkMode),
                            _buildStatCard("Selesai", _completedTasks, Icons.check_circle, Colors.green, _totalTasks > 0 ? _completedTasks / _totalTasks : 0, isDarkMode),
                            _buildStatCard("Tertunda", _pendingTasks, Icons.error_outline, Colors.red, _totalTasks > 0 ? _pendingTasks / _totalTasks : 0, isDarkMode),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // FOKUS HARI INI
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Fokus Hari Ini", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                            const Text("Lihat Semua", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Kontainer dengan Fixed Height & Internal Scroll
                        Container(
                          height: 350, // Height dikunci agar tidak molor
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black54 : Colors.white, 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200)
                          ),
                          child: _todayTasks.isEmpty
                            ? Center(
                                child: Text("Tidak ada agenda tugas hari ini ", textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold))
                              )
                            : RawScrollbar(
                                thumbColor: Colors.purple.withOpacity(0.5),
                                radius: const Radius.circular(8),
                                thickness: 4,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(), // Scroll Internal Aktif
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _todayTasks.length,
                                  itemBuilder: (context, index) {
                                    final task = _todayTasks[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.blueGrey.shade800 : Colors.white, 
                                        borderRadius: BorderRadius.circular(16), 
                                        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200)
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(task['is_completed'] ? Icons.check_circle : Icons.circle_outlined, color: task['is_completed'] ? Colors.green : Colors.grey, size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              task['title'] ?? 'Tanpa Judul',
                                              style: TextStyle(
                                                fontSize: 14, 
                                                fontWeight: FontWeight.bold, 
                                                decoration: task['is_completed'] ? TextDecoration.lineThrough : null, 
                                                color: task['is_completed'] ? (isDarkMode ? Colors.white38 : Colors.black38) : (isDarkMode ? Colors.white : Colors.black87)
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                        ),
                        // Margin tambahan bawah biar gak mentok navigasi
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
