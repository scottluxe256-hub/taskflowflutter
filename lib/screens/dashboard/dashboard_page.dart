import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:task_flow/main.dart'; 

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

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
  
  String _weatherTemp = "--\u00B0C"; 
  String _weatherLocation = "Menunggu lokasi...";
  
  List<dynamic> _todayTasks = [];
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  
  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _initLocation();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _taskChannel = Supabase.instance.client
        .channel('public:tasks')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tasks',
            callback: (payload) {
              _fetchDashboardData();
            })
        .subscribe();
  }

  @override
  void dispose() {
    _timer.cancel();
    if (_taskChannel != null) {
      Supabase.instance.client.removeChannel(_taskChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchWeatherAndLocation([double lat = -6.8580, double lon = 107.9271]) async {
    try {
      final weatherRes = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'));
      if (weatherRes.statusCode == 200) {
        final weatherData = json.decode(weatherRes.body);
        if (weatherData['current_weather'] != null && mounted) {
          setState(() {
             _weatherTemp = "${weatherData['current_weather']['temperature'].round()}\u00B0C";
          });
        }
      }
      
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

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fetchWeatherAndLocation(); 
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _fetchWeatherAndLocation(); 
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
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
          // Update Notifier biar kesinkron!
          profileNotifier.value = {'name': _userName, 'avatar': _avatarUrl};
        }
      }
    } catch (e) {
      debugPrint("Error fetching dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              isDaytime ? Icons.wb_sunny : Icons.dark_mode,
              color: isDaytime ? Colors.amber : Colors.indigo.shade300,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTasksCard(String title, int count, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers, size: 24, color: Colors.purpleAccent), 
                    const SizedBox(width: 6),
                    Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black54))),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(width: 4),
                    Text("Tugas", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black38)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 44, 
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purpleAccent.withOpacity(0.15),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))
            ),
            child: const Icon(Icons.layers, color: Colors.purpleAccent, size: 22), 
          )
        ],
      ),
    );
  }

  Widget _buildDonutCard(String title, int count, IconData icon, Color color, double progress, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 24, color: color), 
                    const SizedBox(width: 6),
                    Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.black54))),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(width: 4),
                    Text("Tugas", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black38)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8, 
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round, 
                ),
                Center(
                  child: Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
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
    
    final currentHour = _currentTime.hour;
    final isDaytime = currentHour >= 6 && currentHour < 18;

    return Scaffold(
      resizeToAvoidBottomInset: false, 
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
                onTap: () {
                  _fetchDashboardData();
                  _initLocation(); 
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.refresh, size: 14, color: Colors.purpleAccent),
                      SizedBox(width: 4),
                      Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.dark_mode : Icons.wb_sunny, 
              color: isDarkMode ? Colors.indigo.shade300 : Colors.amber.shade600
            ),
            onPressed: () {
              themeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: ValueListenableBuilder<Map<String, String>>(
              valueListenable: profileNotifier,
              builder: (context, profile, child) {
                final avatar = profile['avatar'] ?? '';
                final name = profile['name'] ?? 'U';
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty 
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 14)) 
                      : null,
                );
              },
            ),
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDarkMode ? 'assets/images/bg_mobile_dark.webp' : 'assets/images/bg_mobile.webp'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                color: Colors.purpleAccent,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<Map<String, String>>(
                              valueListenable: profileNotifier,
                              builder: (context, profile, child) {
                                return Text(
                                  "Selamat Datang, ${profile['name']}! \u{1F44B}", 
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87),
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Berikut agenda tugasmu hari ini.", 
                              style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500)
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), 
                                    borderRadius: BorderRadius.circular(16), 
                                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                                  ),
                                  child: Row(
                                    children: [
                                      _buildWeatherIcon(isDaytime),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_weatherTemp, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                                          SizedBox(
                                            width: 80,
                                            child: Text(_weatherLocation, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), 
                                    borderRadius: BorderRadius.circular(16), 
                                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                                  ),
                                  child: Text(
                                    timeString, 
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.purpleAccent.shade100 : Colors.purpleAccent, letterSpacing: 1, fontFamily: 'monospace') 
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.1, 
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildAllTasksCard("Semua Tugas", _totalTasks, isDarkMode),
                                _buildDonutCard("Hari Ini", _todayTasksCount, Icons.local_fire_department, Colors.orange, _totalTasks > 0 ? _todayTasksCount / _totalTasks : 0, isDarkMode),
                                _buildDonutCard("Selesai", _completedTasks, Icons.check_circle, Colors.green, _totalTasks > 0 ? _completedTasks / _totalTasks : 0, isDarkMode),
                                _buildDonutCard("Belum Selesai", _pendingTasks, Icons.error_outline, Colors.red, _totalTasks > 0 ? _pendingTasks / _totalTasks : 0, isDarkMode),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SliverFillRemaining(
                      hasScrollBody: true, 
                      fillOverscroll: true,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 24, 20, 24), 
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.blueGrey.shade900.withOpacity(0.85) : Colors.white.withOpacity(0.85), 
                          borderRadius: BorderRadius.circular(20), 
                          border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Fokus Hari Ini", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                                const Text("Lihat Semua", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent)), 
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _todayTasks.isEmpty
                                ? Center(
                                    child: Text("Tidak ada agenda tugas hari ini ☕", textAlign: TextAlign.center, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold))
                                  )
                                : RawScrollbar(
                                    thumbColor: Colors.purpleAccent.withOpacity(0.5), 
                                    radius: const Radius.circular(8),
                                    thickness: 4,
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
