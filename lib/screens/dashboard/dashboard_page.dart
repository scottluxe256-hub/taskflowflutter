import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  
  List<dynamic> _todayTasks = [];
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    // Bikin jam digital jalan terus
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Ambil nama user dari raw_user_meta_data (karena kita set pas Register)
        final metadata = user.userMetadata;
        final name = metadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User';
        
        // Ambil data Tasks
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

  Widget _buildStatCard(String title, int count, IconData icon, Color color, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(count.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const SizedBox(width: 4),
                  const Text("Tugas", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
                ],
              ),
            ],
          ),
          // Pengganti LiquidWaveCircle lu
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

  @override
  Widget build(BuildContext context) {
    // Format jam HH:MM:SS
    final timeString = "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo.webp', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
            const Text('Flow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.purple)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Text(_userName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
            ),
          )
        ],
      ),
      body: _isLoading 
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
                  // HEADER SALAM & WAKTU
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Selamat Datang,\n$_userName! 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                            const SizedBox(height: 4),
                            const Text("Berikut agenda tugasmu hari ini.", style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            Text(timeString, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.purple, letterSpacing: 1)),
                            const Text("WIB", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
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
                      _buildStatCard("Semua Tugas", _totalTasks, Icons.layers, Colors.purple, 1.0),
                      _buildStatCard("Hari Ini", _todayTasksCount, Icons.local_fire_department, Colors.orange, _totalTasks > 0 ? _todayTasksCount / _totalTasks : 0),
                      _buildStatCard("Selesai", _completedTasks, Icons.check_circle, Colors.green, _totalTasks > 0 ? _completedTasks / _totalTasks : 0),
                      _buildStatCard("Tertunda", _pendingTasks, Icons.error_outline, Colors.red, _totalTasks > 0 ? _pendingTasks / _totalTasks : 0),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // FOKUS HARI INI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Fokus Hari Ini", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                      Text("Lihat Semua", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_todayTasks.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: const Text("Tidak ada agenda tugas hari ini ☕", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _todayTasks.length,
                      itemBuilder: (context, index) {
                        final task = _todayTasks[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                          child: Row(
                            children: [
                              Icon(task['is_completed'] ? Icons.check_circle : Icons.circle_outlined, color: task['is_completed'] ? Colors.green : Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task['title'] ?? 'Tanpa Judul',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, decoration: task['is_completed'] ? TextDecoration.lineThrough : null, color: task['is_completed'] ? Colors.black38 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
